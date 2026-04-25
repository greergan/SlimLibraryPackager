FROM ubuntu:26.04
RUN apt update && apt install -y --no-install-recommends \
        autoconf \
        automake \
	autotools-dev \
        build-essential \
        cmake \
        curl \
        git \
        rpm \
	libtool \
        libtool-bin \
	ninja-build \
        openssh-client \
        ca-certificates \
        pkg-config
RUN update-ca-certificates

RUN apt-get update && apt-get install -y locales \
 && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
