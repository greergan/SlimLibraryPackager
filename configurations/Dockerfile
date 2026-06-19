FROM ubuntu:26.04

# git running on local forgejo instance
ENV SLIM_GIT_URL="http://forgejo"
ENV SLIM_GIT_REPO_OWNER="greergan"
ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"
ENV TZ="America/Los_Angeles"

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive

# Combine apt operations into one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        catch2 \
        cmake \
        curl \
        git \
        libtool \
        ninja-build \
        nodejs \
        openssh-client \
        pkg-config \
        rpm \
        zip \
        unzip \
    && rm -rf /var/lib/apt/lists/*
