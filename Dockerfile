ARG BCI_IMAGE=registry.suse.com/bci/bci-base
ARG GO_IMAGE=rancher/hardened-build-base:v1.24.10b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld patch
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc 

# Build the project
FROM base-builder AS builder
#RUN apk add --update --virtual build-dependencies build-base linux-headers bash
ARG TAG=v1.7.1
ARG SRC="github.com/k8snetworkplumbingwg"
ARG REPO_PATH="${SRC}/network-resources-injector"
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/network-resources-injector
WORKDIR network-resources-injector
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
ARG TARGETPLATFORM
ENV CGO_ENABLED=0
ENV GO15VENDOREXPERIMENT=1
RUN xx-go --wrap &&\
    go build -ldflags "-s -w" -tags no_openssl "$@" ${REPO_PATH}/cmd/installer &&\
    go build -ldflags "-s -w" -tags no_openssl "$@" ${REPO_PATH}/cmd/webhook

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=builder /go/network-resources-injector/webhook /usr/bin/
COPY --from=builder /go/network-resources-injector/installer /usr/bin/
RUN strip /usr/bin/webhook &&\
    strip /usr/bin/installer

# Create the network resources injector image
FROM ${BCI_IMAGE}
RUN zypper refresh && \
    zypper update -y && \
    zypper install -y gawk which && \
    zypper clean -a
WORKDIR /
USER 1001
COPY --from=strip_binary /usr/bin/webhook /usr/bin/
COPY --from=strip_binary /usr/bin/installer /usr/bin/

CMD ["webhook"]
