FROM ubuntu:26.04
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        curl \
        git \
	libtool \
        libtool-bin \
	ninja-build \
        openssh-client \
        pkg-config \
        python3 \
        pipx \
        rpm
RUN pipx install --global pre-commit

