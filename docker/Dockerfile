FROM ubuntu:26.04

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive

# Combine apt operations into one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        catch2 \
        cmake \
        curl \
        git \
        libtool \
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

# Install pre-commit
RUN pipx install --global pre-commit

# Setup vcpkg
# Note: It is often better to use 'vcpkg integrate install' if needed
RUN git clone https://github.com/microsoft/vcpkg.git /opt/vcpkg && \
    /opt/vcpkg/bootstrap-vcpkg.sh && \
    ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg

# Run vcpkg install
RUN vcpkg install highway

# Environment configuration
# Ensure WORKSPACE_DIR is defined or use a fallback path
# zed does not yet support full parsing of .devcontainer.json
ENV WORKSPACE_DIR=/workspace
RUN echo "if [ -f ${WORKSPACE_DIR}/set_env.sh ]; then source ${WORKSPACE_DIR}/set_env.sh; fi"
