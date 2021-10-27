# It is a multi-stages docker build with following stages:
# - "esp-opensdk-builder" stage has all the stuff required to build esp-open-sdk
# - "esp-openrtos-bulder" stage takes only the binary toolchain from the first
#   stage + only a few prerequisites to perform esp-openrtos-build

# if set, remove the SDK build directory from the final container
# greate if you only need the xtensa compiler binary file and don't care about anything else (default)

FROM ubuntu:20.04 as esp-opensdk-base
ARG MAKEFLAGS=-j$(nproc)
ARG REMOVE_SDK_BUILD_DIR=1
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    make \
    python2 \
    python3 \
    python3-serial \
    ca-certificates \
    bash \
    curl

# python2 stuff is for esptool.py
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py && python2 get-pip.py && pip2 install pyserial && rm -f get-pip.py

### "esp-opensdk-builder" stage ###
FROM esp-opensdk-base as esp-opensdk-builder

USER root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
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
    python3-pip \
    python3-setuptools \
    sed \
    git \
    unzip \
    help2man \
    wget \
    bzip2 \
    libtool-bin \
    patch

RUN pip install --upgrade pip

RUN mkdir /opt/esp-open-sdk && chown 1000:1000 /opt/esp-open-sdk

RUN useradd --uid 1000 build

# esp-open-sdk build must NOT be performed by root.
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
FROM esp-opensdk-base as esp-openrtos-builder

# original (bulk of work)
LABEL author="Maciej Pijanowski <maciej.pijanowski@3mdeb.com>"
LABEL author2="Dominic Cerquetti <dom at cerquetti dot solutions>"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    make \
    python3 \
    python3-serial \
    bash

RUN useradd --uid 1000 build

COPY --from=esp-opensdk-builder /opt/esp-open-sdk /opt/esp-open-sdk
RUN mkdir -p /opt/esp-open-sdk/esptool/ && \
    ln -s /opt/esp-open-sdk/xtensa-lx106-elf/bin/esptool.py /opt/esp-open-sdk/esptool/esptool.py && \
    chown -R root:root /opt/esp-open-sdk/

USER build

WORKDIR /home/build
ENV PATH="/opt/esp-open-sdk/xtensa-lx106-elf/bin:${PATH}"
