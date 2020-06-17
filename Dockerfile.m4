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
ENV CFLAGS='-O2 -fPIC -fPIE -fstack-protector-strong -frandom-seed=42 -Wformat -Werror=format-security'
m4_ifelse(CROSS_ARCH, amd64, [[ENV CFLAGS="${CFLAGS} -fstack-clash-protection -fcf-protection=full"]])
ENV CPPFLAGS='-Wdate-time -D_FORTIFY_SOURCE=2 -DHAVE_GETOPT_LONG=1'
ENV LDFLAGS='-static -Wl,-pie -Wl,-z,defs -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack'
ENV LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=1

# Build udptunnel
ARG UDPTUNNEL_TREEISH=5a3c103505f7a84ffd154ab0b73dbd237b91e6a4
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

# Copy udptunnel binary
COPY --from=build /tmp/udptunnel/udptunnel /

##################################################
## "test" stage
##################################################

FROM base AS test
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

RUN ["/udptunnel", "--help"]

##################################################
## "udptunnel" stage
##################################################

FROM base AS udptunnel

ENTRYPOINT ["/udptunnel"]
CMD ["--help"]
