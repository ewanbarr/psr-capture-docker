# Copyright (C) 2016 by Ewan Barr
# Licensed under the Academic Free License version 3.0
# This program comes with ABSOLUTELY NO WARRANTY.
# You are free to modify and redistribute this code as long
# as you do not remove the above attribution and reasonably
# inform receipients that you have modified the original work.

FROM ubuntu:16.04

MAINTAINER Ewan Barr "ebarr@mpifr-bonn.mpg.de"

# Suppress debconf warnings
ENV DEBIAN_FRONTEND noninteractive

# Switch account to root and adding user accounts and password
USER root
RUN echo "root:root" | chpasswd && \
    mkdir -p /root/.ssh

# Create psr user which will be used to run commands with reduced privileges.
RUN adduser --disabled-password --gecos 'unprivileged user' psr && \
    echo "psr:psr" | chpasswd && \
    mkdir -p /home/psr/.ssh && \
    chown -R psr:psr /home/psr/.ssh

# Create space for ssh daemon and update the system
RUN echo 'deb http://us.archive.ubuntu.com/ubuntu trusty main multiverse' >> /etc/apt/sources.list && \
    mkdir /var/run/sshd && \
    apt-get -y check && \
    apt-get -y update && \
    apt-get install -y apt-utils apt-transport-https software-properties-common python-software-properties && \
    apt-get -y update --fix-missing && \
    apt-get -y upgrade 

# Install dependencies
RUN apt-get --no-install-recommends -y install \
    build-essential \
    autoconf \
    autotools-dev \
    automake \
    autogen \
    libtool \
    csh \
    gcc \
    gfortran \
    wget \
    git \
    cvs \
    expect \
    libcfitsio-dev \
    libltdl-dev \
    gsl-bin \
    libgsl-dev \
    libgsl2 \
    hwloc \
    libhwloc-dev \
    libboost1.58-all-dev 

RUN apt-get --no-install-recommends -y install \
    pkg-config

USER psr

# Define home, psrhome, OSTYPE and create the directory
ENV HOME /home/psr
ENV PSRHOME $HOME/software
ENV OSTYPE linux
RUN mkdir -p $PSRHOME
WORKDIR $PSRHOME

# Install PSRDADA
COPY psrdada_cvs_login $PSRHOME
USER root
RUN chown -R psr:psr psrdada_cvs_login && \
    chmod +x psrdada_cvs_login
USER psr
RUN ls -lrt psrdada_cvs_login && \
    chmod +x psrdada_cvs_login &&\
    ./psrdada_cvs_login && \
    cvs -z3 -d:pserver:anonymous@psrdada.cvs.sourceforge.net:/cvsroot/psrdada co -P psrdada
ENV PSRDADA_HOME $PSRHOME/psrdada
WORKDIR $PSRDADA_HOME
RUN mkdir build/ && \
    ./bootstrap && \
    ./configure --prefix=$PSRDADA_HOME/build && \
    make && \
    make install && \
    make clean 
ENV PATH $PATH:$PSRDADA_HOME/build/bin
ENV PSRDADA_BUILD $PSRDADA_HOME/build/
ENV PACKAGES $PSRDADA_BUILD

# Install SPEAD2
WORKDIR $PSRHOME
RUN git clone https://github.com/ska-sa/spead2.git
WORKDIR $PSRHOME/spead2
RUN ./bootstrap.sh && \
    ./configure --prefix=$(pwd)/build && \
    make -j && \
    make install && \
    make clean 
ENV PACKAGES $PACKAGES:$(pwd)/build

# Install SPIP
WORKDIR $PSRHOME
RUN git clone https://github.com/ajameson/spip.git
ENV SPIP $PSRHOME/spip
WORKDIR $SPIP
RUN ./bootstrap && \
    ./configure --prefix=$SPIP/build && \
    make -j && \
    make install

# THIS STILL REQUIRES A VMA COMPATIBLE BUILD


WORKDIR $HOME
RUN env | awk '{print "export ",$0}' > $HOME/.profile && \
    echo "source $HOME/.profile" >> $HOME/.bashrc
USER root
