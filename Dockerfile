ARG TAG="v1.5"
ARG BCI_IMAGE=registry.suse.com/bci/bci-base:15.3.17.20.12
ARG GO_IMAGE=rancher/hardened-build-base:v1.18.5b7

# Build the project
FROM ${GO_IMAGE} as builder
#RUN apk add --update --virtual build-dependencies build-base linux-headers bash
RUN apk add --update patch
ARG TAG
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/network-resources-injector
WORKDIR network-resources-injector
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN make

# Create the network resources injector image
FROM ${BCI_IMAGE}
RUN zypper refresh && \
    zypper update -y && \
    zypper install -y gawk which && \
    zypper clean -a
WORKDIR /
COPY --from=builder /go/network-resources-injector/bin/webhook /usr/bin/
COPY --from=builder /go/network-resources-injector/bin/installer /usr/bin/
ENTRYPOINT ["webhook"]
