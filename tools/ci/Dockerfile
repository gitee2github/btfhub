# syntax=docker/dockerfile:1
# This Dockerfile is used to build a "builder" image providing required tools
# in CI pipelines without polluting the global environment.

FROM openeuler/openeuler:22.03-lts-sp2

ARG GO_INSTALL_VERSION=1.19.11

RUN yum -y install \
    clang \
    dwarves \
    findutils \
    git \
    jq \
    make \
    rsync \
    xz \
    && \
    yum clean all

RUN curl -fL -o - https://mirrors.ustc.edu.cn/golang/go${GO_INSTALL_VERSION}.linux-amd64.tar.gz \
    | tar -C /usr/local -xvzf -
ENV GOPROXY=https://repo.huaweicloud.com/repository/goproxy/,direct
ENV PATH="/usr/local/go/bin:$PATH"
