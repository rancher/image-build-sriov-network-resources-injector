ARG TAG="v1.3"
ARG BCI_IMAGE=registry.suse.com/bci/bci-base:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.18.1b7

# Build the project
FROM ${GO_IMAGE} as builder
#RUN apk add --update --virtual build-dependencies build-base linux-headers bash
RUN apk add --update patch
ARG TAG
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/network-resources-injector && \
    cd network-resources-injector  && \
    git fetch --all --tags --prune  && \
    git checkout tags/${TAG} -b ${TAG}  && \
    make

# Create the network resources injector image
FROM ${BCI_IMAGE}
RUN zypper update -y  && \
    zypper install -y bash  && \
    zypper clean --all
WORKDIR /
COPY --from=builder /go/network-resources-injector/bin/webhook /usr/bin/
COPY --from=builder /go/network-resources-injector/bin/installer /usr/bin/
ENTRYPOINT ["webhook"]
