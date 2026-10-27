// Second BPF program, linked into the same object as cpusched.bpf.c by
// `bpftool gen object` (that's the modular multi-.bpf.c the build supports).
// It measures run-queue latency — how long a task waits between being woken
// and actually getting on a CPU — and buckets it into a log2 histogram.
//
// It also shows the *other* egress pattern: where cpusched streams events
// over a ring buffer, this aggregates into an ARRAY map that userspace
// POLLS. No LICENSE here — cpusched.bpf.c provides the single one for the
// linked object. Program names must be unique across the linked units.
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>

#define MAX_SLOTS 27 // log2 buckets, up to ~2^27 ns ≈ 134 ms

// pid -> timestamp it became runnable. Internal; userspace never reads it.
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 16384);
	__type(key, __u32);
	__type(value, __u64);
} runq_start SEC(".maps");

// log2(latency_ns) -> count. A plain array (atomic adds) that the JS side
// polls — the map-as-aggregate egress pattern.
struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, MAX_SLOTS);
	__type(key, __u32);
	__type(value, __u64);
} runq_hist SEC(".maps");

// floor(log2(v)) without a loop: a 6-step binary search on the bit width.
// Branch-free and a fixed instruction count, so the verifier has nothing to
// bound — the obvious `while (v >>= 1) slot++` needs `#pragma unroll`, and
// clang (22+) refuses to unroll a loop with an early exit. log2(0) == 0.
static __always_inline __u32 log2u(__u32 v)
{
	__u32 shift, r;

	r = (v > 0xFFFF) << 4; v >>= r;
	shift = (v > 0xFF) << 3; v >>= shift; r |= shift;
	shift = (v > 0xF) << 2; v >>= shift; r |= shift;
	shift = (v > 0x3) << 1; v >>= shift; r |= shift;
	r |= (v >> 1);
	return r;
}

static __always_inline __u32 log2l(__u64 v)
{
	__u32 hi = v >> 32;

	return hi ? log2u(hi) + 32 : log2u((__u32)v);
}

static __always_inline void mark_runnable(__u32 pid)
{
	__u64 ts = bpf_ktime_get_ns();
	bpf_map_update_elem(&runq_start, &pid, &ts, BPF_ANY);
}

SEC("tracepoint/sched/sched_wakeup")
int on_wakeup(struct trace_event_raw_sched_wakeup_template *ctx)
{
	mark_runnable(ctx->pid);
	return 0;
}

SEC("tracepoint/sched/sched_wakeup_new")
int on_wakeup_new(struct trace_event_raw_sched_wakeup_template *ctx)
{
	mark_runnable(ctx->pid);
	return 0;
}

SEC("tracepoint/sched/sched_switch")
int on_switch_lat(struct trace_event_raw_sched_switch *ctx)
{
	__u32 pid = ctx->next_pid;
	__u64 *tsp = bpf_map_lookup_elem(&runq_start, &pid);
	if (!tsp) {
		return 0; // got on CPU without a recorded wakeup — skip
	}
	__u64 delta = bpf_ktime_get_ns() - *tsp;
	bpf_map_delete_elem(&runq_start, &pid);

	// slot = floor(log2(delta_ns)), clamped to the last bucket
	__u32 slot = log2l(delta);
	if (slot >= MAX_SLOTS) {
		slot = MAX_SLOTS - 1;
	}

	__u64 *cnt = bpf_map_lookup_elem(&runq_hist, &slot);
	if (cnt) {
		__sync_fetch_and_add(cnt, 1);
	}
	return 0;
}
