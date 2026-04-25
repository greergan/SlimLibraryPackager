# Overview
This project provides a containerized build environment for generating Linux installation packages. The included Docker configuration installs the required toolchain to produce both Debian (`.deb`) and Red Hat (`.rpm`) packages.

# Prerequisites
- Docker
- Visual Studio Code
- VS Code Dev Containers extension

# Build the Docker Image
Use the provided [Dockerfile](Dockerfile) to build the image:

```bash
docker build -t slim-toolchain .
```

This image includes:
- GNU build tools (autoconf, automake, libtool)
- Compilers and build essentials
- CMake and Ninja
- Git and curl
- RPM tooling
- pkg-config
- Locale configuration

# Usage
Run the container and mount your workspace:

```bash
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  slim-toolchain
```

You can now build Debian and Red Hat packages inside the container.

# VS Code Dev Container
A sample [devcontainer.json](devcontainer.json) is provided to simplify development in Visual Studio Code.

## Steps
1. Install the Dev Containers extension in VS Code.
2. Open the project folder.
3. When prompted, reopen the folder in a container.

Alternatively:
- Open Command Palette
- Select: `Dev Containers: Reopen in Container`

The configuration mounts your workspace into the container and uses the prebuilt toolchain image.

# Notes
- The container is configured with UTF-8 locale support.
- Package dependencies are preinstalled to minimize setup time.
- The environment is consistent across Debian and Red Hat packaging workflows.
