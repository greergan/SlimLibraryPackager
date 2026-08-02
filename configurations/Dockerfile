FROM ubuntu:26.04

# git running on local forgejo instance
ENV SLIM_GIT_URL="http://forgejo"
ENV SLIM_GIT_REPO_OWNER="greergan"
ENV SLIM_PUBLISHER_USER="forgejo-publisher-user"
ENV SLIM_PUBLISHER_TOKEN="forgejo-publisher-user-token"

ENV TZ="America/Los_Angeles"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive

# Combine apt operations into one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        catch2 \
        cmake \
        curl \
        gdb \
        git \
        golang-go \
        iproute2 \
        libtool \
        net-tools \
        ninja-build \
        nodejs \
        openssh-client \
        pipx \
        pkg-config \
        python3 \
        rpm \
        unzip \
        valgrind \
        zip \
    && rm -rf /var/lib/apt/lists/*
