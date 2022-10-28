m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/alpine:3]], [[FROM docker.io/alpine:3]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

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

# Build udptunnel
ARG UDPTUNNEL_TREEISH=v3
ARG UDPTUNNEL_REMOTE=https://github.com/hectorm/udptunnel.git
RUN mkdir /tmp/udptunnel/
WORKDIR /tmp/udptunnel/
RUN git clone "${UDPTUNNEL_REMOTE:?}" ./
RUN git checkout "${UDPTUNNEL_TREEISH:?}"
RUN git submodule update --init --recursive
RUN make all STATIC=1
RUN strip -s ./udptunnel
RUN ./udptunnel --help

##################################################
## "test" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/hectorm/scratch:CROSS_ARCH]], [[FROM scratch]]) AS test
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

COPY --from=build /tmp/udptunnel/udptunnel /
COPY --from=docker.io/busybox:musl /bin/busybox /busybox

RUN ["/busybox", "sh", "-c", "/busybox printf 'Hello world!\n' > /in; \
/busybox nc -v -l -u -s 127.0.0.1 -p 51820 > /out & /busybox sleep 1; \
/udptunnel  -v -s 127.0.0.1:8080  127.0.0.1:51820 & /busybox sleep 1; \
/udptunnel  -v    127.0.0.1:51821 127.0.0.1:8080  & /busybox sleep 1; \
/busybox nc -v -u 127.0.0.1 51821 < /in           & /busybox sleep 1; \
/busybox cmp /in /out"]

##################################################
## "main" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/hectorm/scratch:CROSS_ARCH]], [[FROM scratch]]) AS main

COPY --from=test /udptunnel /

ENTRYPOINT ["/udptunnel"]
CMD ["--help"]
