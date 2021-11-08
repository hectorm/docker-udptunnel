m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/alpine:3]], [[FROM docker.io/alpine:3]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN apk add --no-cache \
		build-base \
		git \
		pkgconf

# Switch to unprivileged user
ENV USER=builder GROUP=builder
RUN addgroup -S "${GROUP:?}"
RUN adduser -S -G "${GROUP:?}" "${USER:?}"
USER "${USER}:${GROUP}"

# Environment
ENV CFLAGS='-O2 -fstack-protector-strong -frandom-seed=42 -Wformat -Werror=format-security'
m4_ifelse(CROSS_ARCH, amd64, [[ENV CFLAGS="${CFLAGS} -fstack-clash-protection -fcf-protection=full"]])
ENV CPPFLAGS='-Wdate-time -D_FORTIFY_SOURCE=2 -DHAVE_GETOPT_LONG=1'
ENV LDFLAGS='-static -Wl,-z,defs -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack'
ENV LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=1

# Build udptunnel
ARG UDPTUNNEL_TREEISH=v2
ARG UDPTUNNEL_REMOTE=https://github.com/hectorm/udptunnel.git
RUN mkdir /tmp/udptunnel/
WORKDIR /tmp/udptunnel/
RUN git clone "${UDPTUNNEL_REMOTE:?}" ./
RUN git checkout "${UDPTUNNEL_TREEISH:?}"
RUN git submodule update --init --recursive
RUN make -j"$(nproc)"
RUN strip -s ./udptunnel

##################################################
## "base" stage
##################################################

FROM scratch AS base

COPY --from=build /tmp/udptunnel/udptunnel /

ENTRYPOINT ["/udptunnel"]
CMD ["--help"]

##################################################
## "test" stage
##################################################

FROM base AS test
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

COPY --from=docker.io/busybox:musl /bin/busybox /busybox
SHELL ["/busybox", "sh", "-c"]

RUN /busybox printf 'Hello world!\n' > /in; \
	/busybox nc -v -l -u -s 127.0.0.1 -p 51820 > /out & /busybox sleep 1; \
	/udptunnel  -v -s 127.0.0.1:8080  127.0.0.1:51820 & /busybox sleep 1; \
	/udptunnel  -v    127.0.0.1:51821 127.0.0.1:8080  & /busybox sleep 1; \
	/busybox nc -v -u 127.0.0.1 51821 < /in           & /busybox sleep 1; \
	/busybox cmp /in /out

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/udptunnel,target=/udptunnel ["/udptunnel", "-h"]
