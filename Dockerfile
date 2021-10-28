# modified version for building these steps: https://github.com/cnlohr/esp82xx

ARG MAKEFLAGS=-j$(nproc)
ARG DEBIAN_FRONTEND=noninteractive

FROM ubuntu:20.04 as esp-cnlohr-esp82xx-base

# technically, don't need this for projects using esp82xx since they assume this is the default path.
 # but, won't hurt anything to have it here.
ENV ESP_ROOT="/home/build/esp8266"

USER root

# the 'python-is-python2' package makes /usr/bin/python be python2 (needed for esptool)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bash \
    bison \
    bzip2 \
    ca-certificates \
    curl \
    flex \
    g++ \
    gawk \
    gcc \
    git \
    gperf \
    gzip \
    help2man \
    install-info \
    libexpat-dev \
    libtool \
    libtool-bin \
    make \
    ncurses-dev \
    patch \
    python-is-python2 \
    python2 \
    python2-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-serial \
    python3-setuptools \
    sed \
    tar \
    texinfo \
    unrar-free \
    unzip \
    wget \
    xz-utils

RUN pip install --upgrade pip

# python2 stuff is for esptool.py. (sigh... python2+ubuntu.... why u so difficult)
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py && \
    python2 get-pip.py && \
    pip2 install pyserial && \
    rm -f get-pip.py

RUN useradd --disabled-password --gecos '' --uid 1000 build && \
    mkdir -p ${ESP_ROOT} && \
    chown -R 1000:1000 /home/build/

# esp-open-sdk build must NOT be performed by root.
# probably doesn't matter too much for esp82xx, but, good practice anyway.
USER build

# here, instead of using pfalcon/esp-open-sdk, we follow the instructions for using 
# an older prebuilt version from cnlohr/esp82xx (instructions at https://github.com/cnlohr/esp82xx)
#
# "This will install the SDK to ~/esp8266 - the default location for the ESP8266 SDK. This only works on 64-bit x86 systems, 
#  and has only been verified in Linux Mint and Ubuntu. Installation is about 18MB and requires about 90 MB of disk space."
RUN mkdir -p ${ESP_ROOT} && \
    cd ${ESP_ROOT} && \
    wget https://github.com/cnlohr/esp82xx_bin_toolchain/raw/master/esp-open-sdk-x86_64-20200810.tar.xz && \
    tar xJvf esp-open-sdk-x86_64-20200810.tar.xz && \
    rm -f esp-open-sdk-x86_64-20200810.tar.xz

# "Several esp82xx projects use the offical Espressif nonos SDK instead of the bundled one here. 
#  You should probably install that to your home folder using the following commands:"
RUN cd ${ESP_ROOT} && \
    git clone https://github.com/espressif/ESP8266_NONOS_SDK --recurse-submodules

WORKDIR /home/build/src/

ENV PATH="${ESP_ROOT}/xtensa-lx106-elf/bin:${PATH}"


# some extra junk that's useful if you're interactively poking around in the container via 'docker exec'.
# if you want the more barebones version, use the base
FROM esp-cnlohr-esp82xx-base as esp-cnlohr-esp82xx

USER root
RUN apt-get install -y --no-install-recommends && \
    sudo \
    iputils-ping \
    dnsutils

RUN adduser -aG sudo build && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER build
RUN echo "alias ls='ls --color=auto'" >> ~/.bash_profile