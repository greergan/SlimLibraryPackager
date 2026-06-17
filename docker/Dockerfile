FROM ubuntu:26.04

# git running on local forgejo instance
ENV SLIM_GIT_URL="http://192.168.0.73:3000"
ENV SLIM_GIT_REPO_OWNER="greergan"
ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"
ENV TZ="America/Los_Angeles"   

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive
ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"

# Combine apt operations into one layer
# ADDED: golang-go and perl so vcpkg can successfully build BoringSSL
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        catch2 \
        cmake \
        curl \
        git \
        libtool \
        nasm \
        ninja-build \
        nodejs \
        openssh-client \
        pkg-config \
        python3 \
        pipx \
        rpm \
        zip \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Install pre-commit globally via pipx
RUN pipx install --global pre-commit

# Setup vcpkg and install packages (Now with system tools ready)
RUN git clone --depth=1 https://github.com/microsoft/vcpkg.git ${VCPKG_ROOT} \
    && ${VCPKG_ROOT}/bootstrap-vcpkg.sh \
    && ${VCPKG_ROOT}/vcpkg install highway boringssl \
    && rm -rf ${VCPKG_ROOT}/buildtrees ${VCPKG_ROOT}/downloads

