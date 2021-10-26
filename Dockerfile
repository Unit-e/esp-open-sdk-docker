# It is a multi-stages docker build with following stages:
# - "esp-opensdk-builder" stage has all the stuff required to build esp-open-sdk
# - "esp-openrtos-bulder" stage takes only the binary toolchain from the first
#   stage + only a few prerequisites to perform esp-openrtos-build

# if set, remove the SDK build directory from the final container
# greate if you only need the xtensa compiler binary file and don't care about anything else (default)

### "esp-opensdk-builder" stage ###
FROM ubuntu:20.04 as esp-opensdk-builder
ARG MAKEFLAGS=-j$(nproc)
ARG REMOVE_SDK_BUILD_DIR=1
ARG DEBIAN_FRONTEND=noninteractive

# original (bulk of work)
LABEL author="Maciej Pijanowski <maciej.pijanowski@3mdeb.com>"

# some minor changes / upgrades
LABEL author="Dominic Cerquetti <dom at cerquetti dot solutions>"

USER root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    make \
    unrar-free \
    autoconf \
    automake \
    libtool \
    gcc \
    g++ \
    gperf \
    flex \
    bison \
    texinfo \
    gawk \
    ncurses-dev \
    libexpat-dev \
    python-is-python3 \
    python3-dev \
    python3 \
    python3-serial \
    python3-pip \
    python3-setuptools \
    sed \
    git \
    unzip \
    bash \
    help2man \
    wget \
    bzip2 \
    libtool-bin \
    patch

RUN pip install --upgrade pip

RUN mkdir /opt/esp-open-sdk && chown 1000:1000 /opt/esp-open-sdk

RUN useradd --uid 1000 build

# 1. esp-open-sdk build must NOT be performed by root.
# 2. also, changed to a fork which has a couple fixes to crosstool-NG that fix build errors
USER build

RUN cd /opt/esp-open-sdk && \
    git clone --recursive https://github.com/Unit-e/esp-open-sdk && \
    cd esp-open-sdk && \
    make toolchain esptool libhal STANDALONE=n && \
    cd ../ && \
    mv esp-open-sdk/xtensa-lx106-elf . && \
    /bin/bash -c "if [[ \"${REMOVE_SDK_BUILD_DIR}\" == '1' ]]; then rm -rf esp-open-sdk/; else echo 'Keeping build dir.'; fi"

# or, do it as a second step (ineffecient but useful for debugging docker container builds)
# RUN cd /opt/esp-open-sdk && rm -rf esp-open-sdk

### "esp-openrtos-builder" stage ###
FROM ubuntu:20.04 as esp-openrtos-builder

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    make \
    python3 \
    python3-serial \
    bash

RUN useradd --uid 1000 build

USER build
COPY --from=esp-opensdk-builder /opt/esp-open-sdk /opt/esp-open-sdk
WORKDIR /home/build
ENV PATH="/opt/esp-open-sdk/xtensa-lx106-elf/bin:${PATH}"
