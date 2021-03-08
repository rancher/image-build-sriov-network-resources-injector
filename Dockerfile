ARG TAG="v1"
ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.8b5

# Build the project
FROM ${GO_IMAGE} as builder
#RUN apk add --update --virtual build-dependencies build-base linux-headers bash
RUN apk add --update patch
ARG TAG
RUN git clone --depth=1 https://github.com/k8snetworkplumbingwg/network-resources-injector
WORKDIR network-resources-injector
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
COPY 0001-fix-modebuild.patch .
RUN patch -p1 < 0001-fix-modebuild.patch
RUN make

# Create the network resources injector image
FROM ${UBI_IMAGE}
RUN microdnf update -y && microdnf install bash
WORKDIR /
COPY --from=builder /go/network-resources-injector/bin/webhook /usr/bin/
COPY --from=builder /go/network-resources-injector/bin/installer /usr/bin/
ENTRYPOINT ["webhook"]
