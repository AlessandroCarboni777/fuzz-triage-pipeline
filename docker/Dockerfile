FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    clang \
    lld \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    gdb \
    && rm -rf /var/lib/apt/lists/*

# libFuzzer is included in clang
ENV CC=clang
ENV CXX=clang++

WORKDIR /workspace

CMD ["/bin/bash"]