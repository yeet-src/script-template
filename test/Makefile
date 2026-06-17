.PHONY: all clean rolecall install

ARCH := $(shell uname -m | sed 's/aarch64/arm64/; s/x86_64/x86/')

# Pull CLANG / BPFTOOL from the active installer's env file. macOS
# routes through the build container (docker run wrappers); Linux
# uses native binaries on PATH. Each env file is written by the
# matching scripts/installers/<os>.sh; before `make install` neither
# exists and we fall back to system clang/bpftool.
OS := $(shell uname -s)
ifeq ($(OS),Darwin)
    ENV_FILE := scripts/installers/macos/env.sh
endif
ifeq ($(OS),Linux)
    ENV_FILE := scripts/installers/linux/env.sh
endif
CLANG   := clang
BPFTOOL := bpftool
ifneq ($(wildcard $(ENV_FILE)),)
    CLANG   := $(shell . $(ENV_FILE) && echo $$CLANG)
    BPFTOOL := $(shell . $(ENV_FILE) && echo $$BPFTOOL)
endif

# Strip -t (pseudo-TTY) for invocations from make recipes. Make
# redirects stdin from /dev/null, which docker rejects when -t is in
# play ("the input device is not a TTY"). Same when stdout is
# redirected to a file. Leaves -i alone so stdin still pipes through.
CLANG_BATCH   := $(subst -it,-i,$(CLANG))
BPFTOOL_BATCH := $(subst -it,-i,$(BPFTOOL))

all: build/test.bpf.o

# vmlinux.h is the CO-RE kernel header — dumped from the running
# kernel's BTF (the docker container shares the host VM's BTF on
# macOS, so `bpftool btf dump` works inside the image). Generated
# once and reused; delete include/ to force a refresh.
include/vmlinux.h:
	mkdir -p include
	$(BPFTOOL_BATCH) btf dump file /sys/kernel/btf/vmlinux format c > $@

build/test.bpf.o: src/bpf/test.bpf.c include/vmlinux.h
	mkdir -p build
	$(CLANG_BATCH) -O2 -g -target bpf \
		-D__TARGET_ARCH_$(ARCH) \
		-I include \
		-c $< -o $@

rolecall:
	./scripts/rolecall.sh

install:
	./scripts/install.sh

clean:
	rm -rf build include
