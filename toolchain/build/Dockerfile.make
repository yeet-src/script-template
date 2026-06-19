# syntax=docker/dockerfile:1
#
# Build a fully-static GNU make. It's the build driver, so it must run before
# anything else is fetched — `yeet build` bootstraps it into the toolchain
# cache at the shell level, then invokes it. Tiny and quick to build (seconds),
# so unlike clang this is cheap on any arch, even emulated.
#
#   docker buildx build --platform linux/amd64 \
#     -f Dockerfile.make --build-arg MAKE_VERSION=4.4.1 \
#     --target export --output type=local,dest=./out .
#
# Extracts /make into ./out/make.

ARG ALPINE_TAG=alpine:3.21

FROM ${ALPINE_TAG} AS build
ARG MAKE_VERSION=4.4.1

RUN apk add --no-cache gcc musl-dev make curl tar gzip binutils

WORKDIR /src
RUN curl -fSL -o make.tar.gz \
        "https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz" \
 && tar xf make.tar.gz \
 && rm make.tar.gz

WORKDIR /src/make-${MAKE_VERSION}
# -static links musl statically; --disable-nls drops the libintl dependency
# musl doesn't provide. GNU make has no other external deps, so the result is
# a self-contained binary.
RUN ./configure CFLAGS="-Os" LDFLAGS="-static" --disable-nls --disable-dependency-tracking \
 && make -j"$(nproc)" \
 && strip make \
 && ./make --version \
 && if readelf -l make | grep -q INTERP; then echo "ERROR: make is not static"; exit 1; fi \
 && echo "confirmed: no PT_INTERP -> fully static" \
 && cp make /make

FROM scratch AS export
COPY --from=build /make /make
