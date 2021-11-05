# modified version for building these steps: https://github.com/cnlohr/esp82xx

ARG MAKEFLAGS=-j$(nproc)
FROM ubuntu:20.04 as esp-cnlohr-esp82xx-base

ARG SDK_HOME="/home/build/esp8266"

# note: I think you can also change this to be /home/build/esp8266/ESP8266_NONOS_SDK (this is not the default).
# also, user makefiles can override if they like.
ENV ESP_ROOT="${SDK_HOME}/esp-open-sdk"

USER root

# the 'python-is-python2' package makes /usr/bin/python be python2 (needed for esptool.py in the SDK)
# 
# the 'esptool' package is for a DIFFERENT and newer version of esptool than what comes bundled in ESP_ROOT
# makes flashing more accurate
# 
ARG DEBIAN_FRONTEND=noninteractive
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
    libusb-1.0-0-dev \
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
    xz-utils \
    zip

RUN pip install --upgrade pip

# python2 stuff is for SDK's version of esptool.py. (sigh... python2+ubuntu.... why u so difficult)
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py && \
    python2 get-pip.py && \
    pip2 install pyserial && \
    rm -f get-pip.py

# install very latest esptool though, unrelated to SDK
RUN cd /tmp && \
    wget https://github.com/espressif/esptool/releases/download/v3.2/esptool-v3.2-linux-amd64.zip && \
    unzip esptool-v3.2-linux-amd64.zip && \
    cd esptool-v3.2-linux-amd64 && \
    chmod a+x ./esp* && \
    mkdir -p /usr/local/bin/ && \
    cp ./esp* /usr/local/bin/ && \
    rm /tmp/esptool-v3.2-linux-amd64.zip

# setup new user "build" and home dirs.
# 
# Note: dialout stuff: allow use of serial port /dev/ttyUSB* 
# (important note: Oct 2021: host serial port access doesn't work on windows with WSL2, i.e. docker desktop on windows.
#  use esp_rfc2217_server.exe from espressif on windows to forward serial port over the network from docker->windows host.
#  this shoudl work OK with docker running on virtualbox though)
RUN useradd --uid 1000 build && \
    usermod -a -G dialout build && \
    mkdir -p ${SDK_HOME} && \
    chown -R 1000:1000 /home/build/

# esp-open-sdk build must NOT be performed by root.
# probably doesn't matter too much for esp82xx, but, good practice anyway.
USER build

# here, instead of using pfalcon/esp-open-sdk, we follow the instructions for using 
# an older prebuilt version from cnlohr/esp82xx (instructions at https://github.com/cnlohr/esp82xx)
#
# "This will install the SDK to ~/esp8266 - the default location for the ESP8266 SDK. This only works on 64-bit x86 systems, 
#  and has only been verified in Linux Mint and Ubuntu. Installation is about 18MB and requires about 90 MB of disk space."
RUN mkdir -p ${SDK_HOME} && \
    cd ${SDK_HOME} && \
    wget https://github.com/cnlohr/esp82xx_bin_toolchain/raw/master/esp-open-sdk-x86_64-20200810.tar.xz && \
    tar xJvf esp-open-sdk-x86_64-20200810.tar.xz && \
    rm -f esp-open-sdk-x86_64-20200810.tar.xz

# "Several esp82xx projects use the offical Espressif nonos SDK instead of the bundled one here. 
#  You should probably install that to your home folder using the following commands:"
RUN cd ${SDK_HOME} && \
    git clone https://github.com/espressif/ESP8266_NONOS_SDK --recurse-submodules

WORKDIR /home/build/src/

ENV PATH="${ESP_ROOT}/xtensa-lx106-elf/bin:${PATH}"

# some extra junk that's useful if you're interactively poking around in the container via 'docker exec'.
# if you want the more barebones version, use the base
FROM esp-cnlohr-esp82xx-base as esp-cnlohr-esp82xx

USER root
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y --no-install-recommends \
    sudo \
    iputils-ping \
    dnsutils

RUN usermod -a -G sudo build && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# LITERALLY ONLY EXISTS FOR GITHUB ACTIONS. probably should make this configurable. pretty horrible hack.
# in github actions, the user is 'runner' which is uid=1001.  the volume mounted into the container is this UID, so make our user be that uid.
# ugh. woof.
RUN usermod -u 1001 build

USER build
RUN echo "alias ls='ls --color=auto'" >> ~/.bashrc
