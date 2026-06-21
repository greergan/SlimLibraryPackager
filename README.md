<a href="https://codeberg.org/greergan/SlimTS">
  <img src="https://raw.githubusercontent.com/greergan/SlimTS/master/assets/slimts_logo.png" width="75" alt="SlimTS Logo">
</a>

# SlimLibraryPackager

A unified build system for the [SlimCommon](https://codeberg.org/greergan/SlimCommon) c++ library and its contained micro-libraries.  
The SlimCommon library is used by the [SlimTS](https://codeberg.org/greergan/SlimTS) typescript first platform.

## Table of Contents

- [Overview](#overview)
- [Project Definition](#project-definition)
  - [Project File List](#file-list)
- [Library Setup](#library-setup)
  - [Defining Dependencies](#defining-dependencies)
  - [Code Testing](#code-testing)
  - [update_env.sh](#update_env)
  - [Building a Library](#building-a-library)
  - [Building SlimCommon](#building-slimcommon)
- [Forgejo Workflows](#forgejo-workflows)
  - [Setup](#workflow-setup)
  - [build.yml](#build-workflow)
  - [publish.yml](#publish-workflow)
- [Using Docker](#using-docker)
  - [Container Creation](#container-creation)
  - [Dev Containers](#dev-containers)
    - [How It's Wired Up](#how-it-s-wired-up)
    - [Using It (VS Code)](#using-it-vs-code)
    - [Using It (Zed)](#using-it-zed)
    - [Workspace Directory](#workspace-directory)
  - [Docker Compose](#docker-compose)

## Overview


*Add content for the Overview here.*

[↑ Top](#table-of-contents)

## Project Definition

A project is defined by a set of files which are used to build, test and package the [SlimCommon](https://codeberg.org/greergan/SlimCommon) c++ library and its contained micro-libraries a long with a git repository structure. Also includes a .gitignore, LICENSE and [Forgejo](https://forgejo.org/) workflows. 

### File List  
* `src/main.cpp`
* `include/slim/common/[*]/[microlibrary].h.in`
* `include/slim/common/[microlibrary]/*.h.in`
* `src/test.cpp`
* `tests/*.cpp`
* `required_packages`  
* `.gitignore`
* `LICENSE`
* `.forgejo/workflows/build.yml`
* `.forgejo/workflows/publish.yml`

| File | Purpose |
| --- | --- |
| `src/main.cpp` | contains library code |
| `include/slim/common/[*]/[microlibrary].h.in` | i.e. [`SlimCommonHttpCookieStore`](https://codeberg.org/greergan/SlimCommonHttpCookieStore) uses `include/slim/common/Http/Cookie/store.h.in` |
| `include/slim/common/[microlibrary]/*.h.in` - optional | i.e. [`SlimCommonHttp`](https://codeberg.org/greergan/SlimCommonHttp) uses `include/slim/common/http/*.h.in` |
| `src/test.cpp` | optional, used to build small program that will test functionality |
| `tests/*.cpp` | i.e. `tests/main.cpp` - [Catch2 V3](https://github.com/catchorg/Catch2) test harness |
| `required_packages` | Slim library, micro-library [required package definitions](#defining-dependencies) |
| `.gitignore` | the git ignore list, provided by [update_env.sh](#update_env) |
| `LICENSE` | the project license file, provided by [update_env.sh](#update_env) |
| `.forgejo/workflows/build.yml` | provided by [update_env.sh](#update_env) |
| `.forgejo/workflows/publish.yml` | provided by [update_env.sh](#update_env) |

[↑ Top](#table-of-contents)

## Library Setup

SlimCommon and its micro-libraries are all made using the same build files and workflows.  
Follow this examples to get started.  

~~~ bash
mkdir workspace
cd workspace

git clone ssh://git@forgejo/greergan/SlimLibraryPackager.git

mkdir SlimCommon[Lib[Sublib][Sublib]]
cd project directory
git init
bash ../SlimLibraryPackager/update_env.sh

mkdir src
touch src/main.cpp

# example: SlimCommonHttpCookieStore
# directory: include/slim/common/http/cookie
# file:      include/slim/common/http/cookie/store.h.in
mkdir -p include/slim/common/cookie
touch include/slim/common/cookie/store.h.in

mkdir tests
touch test/main.cpp

git add .
git commit -m"Initial commit"

# ensure things are setup correctly to do a build
make
~~~

[↑ Top](#table-of-contents)

## Defining Dependencies

Library dependencies are found in a file called `required_packages` found in the project root.

`required_packages` file
~~~
# PackageName [minVersion [maxVersion]]
SlimCommonLog
SlimCommonMemoryMapper 1.0.0
~~~

[↑ Top](#table-of-contents)

## Code Testing

Code testing is handled by [Catch2 v3](https://github.com/catchorg/Catch2). All testing code is compiled and run automatically when the project is built.  
The following examples are based on tests found here `tests/main.cpp` in [SlimCommonHttpHeader](https://codeberg.org/greergan/SlimCommonHttpHeaders/src/branch/master/tests/main.cpp).

~~~ cpp
#include <catch2/catch_test_macros.hpp>

#include <slim/common/http/headers.h>

using namespace slim::common::http;

TEST_CASE("Headers::append adds a new header when the key does not exist", "[headers][append]") {
    Headers h;

    SECTION("simple header") {
        REQUIRE(h.append("Accept", "text/html") == HeaderStatus::OK);
        REQUIRE(h.entries().size() == 1);

        auto entry = h.get("Accept");
        REQUIRE(entry != nullptr);
        CHECK(entry->get_name() == "Accept");
        REQUIRE(entry->get_value().size() == 1);
        CHECK(entry->get_value()[0] == "text/html");
    }

    SECTION("invalid name does not create an entry") {
        REQUIRE(h.append("", "text/html") == HeaderStatus::NameEmpty);
        CHECK(h.entries().empty());
    }
}

TEST_CASE("Headers::serialize renders entries as wire-format header lines", "[headers][serialize]") {
    Headers h;
    REQUIRE(h.append("Accept", "text/html") == HeaderStatus::OK);
    REQUIRE(h.append("Accept", "application/json") == HeaderStatus::OK);
    REQUIRE(h.append("Vary", "Accept-Encoding") == HeaderStatus::OK);

    const std::string expects = "Accept: text/html, application/json\r\n"
                                 "Vary: Accept-Encoding\r\n";
                                 "\r\n";

    CHECK(h.serialize() == expects);
}
~~~

`make` builds the project and runs the full `tests/*.cpp` suite as part of every build.

[↑ Top](#table-of-contents)

## update_env

* Most importantly, this bash script links build files into your current micro-library repository directory  
* Next most important, this bash script copies official SlimLibraryPackager workflows into your current project directory
* It also keeps the official LICENSE file and .gitignore file in sync  

[update_env.sh](update_env.sh)


Run prior to building a project
~~~ bash
git clone ssh://git@forgejo/greergan/SlimLibraryPackager.git
git clone ssh://git@forgejo/greergan/SlimCommonHttpCookie.git
cd SlimCommonHttpCookie
bash ../SlimLibraryPackager/update_env.sh
make
~~~


[↑ Top](#table-of-contents)

## Building a Library

There are several options for building a project
* make
* make local
* make install
* make packages

Running [update_env.sh](#update_env) is a prerequisite for building.

| Command | Effects |
| --- | --- |
| make | compiles complete project, runs tests |
| make local | compiles complete project, runs tests, installs unversioned micro-library |
| make install | pulls latest tagged git source, compiles complete project, runs tests, installs versioned micro-library |
| make packages | pulls latest tagged git source, compiles complete project, runs tests and creates .deb and .rpm packages |
**check project_root/dist for packages

[↑ Top](#table-of-contents)

## Forgejo Workflows

[Forgejo Actions](https://forgejo.org/docs/latest/user/actions/) builds and publishes [SlimCommon](https://codeberg.org/greergan/SlimCommon) and its micro-libraries using two workflows that run inside the `slim-toolchain` [container image](#container-creation) on the [self-hosted runner](#docker-compose):

- [`build.yml`](#build-workflow) — compiles and tests the project on every push to `master`.
- [`publish.yml`](#publish-workflow) — builds and publishes versioned `.deb`/`.rpm` packages on tag pushes.

Both workflows depend on repository variables and secrets configured in Forgejo — see [Setup](#workflow-setup) before running either one.

[↑ Top](#table-of-contents)

### Workflow Setup

Before either workflow can run successfully, the repository variables and secrets below must be configured in Forgejo under **Settings → Actions → Variables** and **Settings → Actions → Secrets**.

| Name | Type | Used In | Purpose |
| --- | --- | --- | --- |
| `GIT_URL` | Variable | `build.yml`, `publish.yml` | Forgejo instance URL passed to `make` as `SLIM_GIT_URL`, used to resolve micro-library dependencies. |
| `REPO_OWNER` | Variable | `build.yml`, `publish.yml` | Default repo owner passed to `make` as `SLIM_GIT_REPO_OWNER`. |
| `SMTP_SERVER_ADDR` | Variable | `build.yml`, `publish.yml` | SMTP server hostname used for failure-notification email. |
| `SMTP_SERVER_PORT` | Variable | `build.yml`, `publish.yml` | SMTP server port used for failure-notification email. |
| `SMTP_USER` | Variable | `build.yml`, `publish.yml` | SMTP username used to authenticate when sending failure-notification email. |
| `NOTIFICATIONS_EMAIL` | Variable | `build.yml`, `publish.yml` | Recipient address for failure-notification email. |
| `NOTIFICATIONS_FROM_EMAIL` | Variable | `build.yml`, `publish.yml` | From address for failure-notification email. |
| `SMTP_SERVER_PASSWORD` | Secret | `build.yml`, `publish.yml` | Password/credential used to authenticate to the SMTP server. |
| `REGISTRY_USER` | Secret | `publish.yml` | Username used to authenticate to the Forgejo package registry when publishing packages. |
| `REGISTRY_TOKEN` | Secret | `publish.yml` | Token used to authenticate to the Forgejo package registry when publishing packages. |

[↑ Top](#table-of-contents)

### build workflow

Runs on every push to `master`, or manually via **workflow_dispatch**. Executes on the self-hosted runner inside a privileged `slim-toolchain` container.

[`forgejo/workflows/build.yml`](forgejo/workflows/build.yml)

1. Checks out the current repository and the [SlimLibraryPackager](https://codeberg.org/greergan/SlimLibraryPackager) repo (needed for `update_env.sh`).
2. Runs [`update_env.sh`](#update_env) to sync build files, the workflow definitions, `LICENSE`, and `.gitignore`.
3. Validates that the `GIT_URL` and `REPO_OWNER` variables are set, then compiles the project and runs its tests:

   ```bash
   make RELEASE_TYPE=RELEASE SHARED_ONLY=OFF SLIM_GIT_URL="${{ vars.GIT_URL }}" SLIM_GIT_REPO_OWNER="${{ vars.REPO_OWNER }}"
   ```
4. On failure, sends a notification email using the SMTP variables/secrets from [Workflow Setup](#workflow-setup).

[↑ Top](#table-of-contents)

### publish workflow

Runs on pushes of tags matching `v*`, or manually via **workflow_dispatch** with an optional `version` input. Executes on the self-hosted runner inside a privileged `slim-toolchain` container.

[`forgejo/workflows/publish.yml`](forgejo/workflows/publish.yml)

1. Checks out the current repository at the triggering ref and the [SlimLibraryPackager](https://codeberg.org/greergan/SlimLibraryPackager) repo.
2. Validates that the `GIT_URL` and `REPO_OWNER` variables are set.
3. Determines the version to publish — from the manual `version` input, the `v*` tag name, or `0.0.0` as a fallback.
4. Runs [`update_env.sh`](#update_env), then builds and packages the project:

   ```bash
   make packages SLIM_GIT_URL="${{ vars.GIT_URL }}" SLIM_GIT_REPO_OWNER="${{ vars.REPO_OWNER }}"
   ```

   This compiles, runs tests, and produces `.deb`/`.rpm` packages in `dist/`.
5. Uploads each package in `dist/` to the Forgejo generic package registry for the repository's owner, authenticating with the `REGISTRY_USER` / `REGISTRY_TOKEN` secrets.
6. On failure, sends a notification email using the SMTP variables/secrets from [Workflow Setup](#workflow-setup).

[↑ Top](#table-of-contents)

## Using Docker

Docker is used throughout this project to keep the build toolchain reproducible across machines and CI:

- [Container Creation](#container-creation) — the [`Dockerfile`](configurations/Dockerfile) defining the `slim-toolchain` image used to build [SlimCommon](https://codeberg.org/greergan/SlimCommon), its micro-libraries, and the [Google V8](https://v8.dev/docs) embedder libraries.
- [Dev Containers](#dev-containers) — open this repo directly inside that same `slim-toolchain` image from [VS Code](https://code.visualstudio.com/docs/devcontainers/containers) or [Zed](https://zed.dev/docs/dev-containers) for local development.
- [Docker Compose](#docker-compose) — a self-hosted [Forgejo](https://forgejo.org/) stack (server, Postgres, and Actions runner) for running the [Forgejo Workflows](#forgejo-workflows) that build and publish the libraries.

[↑ Top](#table-of-contents)

### Container Creation

Required build toolchain for
- [Forgejo Workflows](#forgejo-workflows)
- [SlimCommon](https://codeberg.org/greergan/SlimCommon) and its micro-libraries
- [Google V8](https://v8.dev/docs) embedder libraries

** Configuration file
[`configurations/Dockerfile`](configurations/Dockerfile)

**Base image**

Built `FROM ubuntu:26.04`.

**Environment variables**

| Variable | Purpose |
| --- | --- |
| `SLIM_GIT_URL` | Points at the local Forgejo instance (`http://forgejo`) so builds can resolve dependencies from it. |
| `SLIM_GIT_REPO_OWNER` | Default repo owner (`greergan`) used when resolving dependency repos. |
| `LANG` / `LC_ALL` | Pinned to `C.UTF-8` for consistent, locale-independent build output. |
| `TZ` | Set to `America/Los_Angeles`. |
| `DEBIAN_FRONTEND` | Set to `noninteractive` so `apt-get` never blocks waiting on prompts. |

**Installed packages**

All `apt-get` work is combined into a single layer to keep the image small, and the package list cache is removed afterward (`rm -rf /var/lib/apt/lists/*`). Installed packages:

- `build-essential`, `cmake`, `ninja-build`, `pkg-config`, `libtool` — builds [SlimCommon](https://codeberg.org/greergan/SlimCommon) and [Google V8](https://v8.dev/docs) libraries.
- `ca-certificates` — root CA certificates for TLS/HTTPS connections (e.g. cloning over HTTPS, package downloads).
- `catch2` — the Catch2 v3 test framework used by [SlimCommon](https://codeberg.org/greergan/SlimCommon)'s C++ test suite.
- `git`, `openssh-client`, `curl` — source checkout and dependency fetching, including over SSH.
- `nodejs` — needed for the Forgejo actions.
- `rpm`, `zip`, `unzip` — packaging utilities for produced artifacts.

**Building the image**

```bash
docker build -t slim-toolchain:latest -f configurations/Dockerfile .
```

[↑ Top](#table-of-contents)

### Dev Containers

[Dev Containers](https://containers.dev/) let you open a workspace directly inside the [`slim-toolchain`](#container-creation) build environment.

Tested with
- [Zed Dev Containers](https://zed.dev/docs/dev-containers)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

[↑ Top](#table-of-contents)

#### How It's Wired Up

** [`configurations/devcontainer.json`](configurations/devcontainer.json)  
** [`configurations/Dockerfile`](configurations/Dockerfile)

- `build.dockerfile` points at the same [`Dockerfile`](configurations/Dockerfile) used for [Container Creation](#container-creation), so the dev container and the CI build environment stay in sync.
- `runArgs` names the running container `slim-toolchain`.
- `workspaceFolder` is `/workspace`, and `workspaceMount` bind-mounts the local repo there with `cached` consistency for better I/O performance.
- `mounts` adds two additional bind mounts:
  - `/product/google/v8` on the host → `/opt/v8` in the container, for prebuilt [Google V8](https://v8.dev/docs) embedder libraries.
  - `${localEnv:HOME}/.ssh` → `/root/.ssh`, so the container can use your existing SSH keys to clone/push against Forgejo without copying credentials into the image. 
    - This approach is needed by the version of [Zed](https://zed.dev/) available at the time of this writing.

[↑ Top](#table-of-contents)

#### Using It (VS Code)

1. Open the [Workspace Directory](#workspace-directory) in VS Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed.
2. Run **Dev Containers: Reopen in Container** from the command palette.
3. VS Code builds the image from `configurations/Dockerfile` (or reuses it if already built) and reopens the workspace inside the `slim-toolchain` container at `/workspace`.

[↑ Top](#table-of-contents)

#### Using It (Zed)

1. Open the [Workspace Directory](#workspace-directory) in [Zed](https://zed.dev/), which reads the same `configurations/devcontainer.json`.
2. Run **dev containers: reopen in container** from the command palette (see [Zed's Dev Containers docs](https://zed.dev/docs/dev-containers) for current details, as support is still evolving).
3. Zed builds (or reuses) the image from `configurations/Dockerfile` and reopens the workspace inside the `slim-toolchain` container at `/workspace`.

> **Note:** `/product/google/v8` must exist on the host machine with the expected V8 build output before opening the dev container, or the mount will fail.

[↑ Top](#table-of-contents)

### Workspace Directory

Your workspace directory must contain a sub-directory called `.devcontainer`  
Check [SlimCommon](https://codeberg.org/greergan/SlimCommon) for a list of micro-libraries.  

~~~ bash
mkdir workspace
git clone ssh://git@forgejo/greergan/SlimLibraryPackager.git

mkdir .devcontainer
ln -s SlimLibraryPackager/configurations/devcontainer.js .devcontainer/devcontainer.js
ln -s SlimLibraryPackager/configurations/Dockerfile .devcontainer/Dockerfile

git clone other SlimCommon library and micro-library repositories as needed

# Setup library/micro-library build environment
for d in SlimCommon*; do (cd "$d" && bash ../SlimLibraryPackager/update_env.sh); done

# Start your editor using the workspace directory
zed workspace

~~~

[↑ Top](#table-of-contents)

### Docker Compose

This repo includes a Docker Compose stack (`configurations/docker-compose.yml`) that spins up a self-hosted [Forgejo](https://forgejo.org/) instance, its Postgres database, and a Forgejo Actions runner — useful for running the [Forgejo Workflows](#forgejo-workflows) used to build and publish the [SlimCommon](https://codeberg.org/greergan/SlimCommon) library and micro-libraries.

**Services**

- `forgejo` — the Forgejo server itself (web UI + git over SSH). Exposes port `80` for HTTP and `22` for SSH (mapped to the container's internal `2222`).
- `db` — a `postgres:16-alpine` database used as Forgejo's backing store. A healthcheck gates Forgejo's startup until Postgres is ready.
- `runner` — a Forgejo Actions runner (`code.forgejo.org/forgejo/runner:12`). On startup it generates its own `config.yaml` from the `FORGEJO_RUNNER_TOKEN` / `FORGEJO_RUNNER_UUID` environment variables and registers itself against the `forgejo` service, with the `self-hosted` and `docker` labels. It mounts the host's Docker socket so jobs run in sibling containers on the `forgejo_forgejo_net` network.

All three services share a single bridge network, `forgejo_net`, and persist their data in the named volumes `forgejo_data`, `postgres_data`, and `runner_data`.

**Setup**

1. Copy the sample environment file into the same directory as `docker-compose.yml` and rename it:

   ```bash
   cp configurations/env.sample configurations/.env
   ```

2. Edit `.env` and fill in the required values:

   | Variable | Description |
   | --- | --- |
   | `FORGEJO_DOMAIN` | Hostname Forgejo will be served from and used to generate links/SSH clone URLs. |
   | `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | Credentials for the Postgres database. |
   | `FORGEJO__mailer__*` | SMTP settings used for outgoing notification email (defaults shown are for Gmail SMTP). |
   | `FORGEJO_RUNNER_UUID` / `FORGEJO_RUNNER_TOKEN` | Registration UUID and token for the Actions runner. See step 3 below for how to obtain these. |

3. Obtain a runner registration token. This requires Forgejo to already be running, so start just that service first:

   ```bash
   docker compose up -d db forgejo
   ```

   Then log in to Forgejo as an admin and navigate to **Site Administration → Actions → Runners**, then click **Create new runner**. Copy the generated UUID and token into `FORGEJO_RUNNER_UUID` and `FORGEJO_RUNNER_TOKEN` in your `.env` file.

4. Stop the partial stack, then start (or restart) the full stack now that the runner's credentials are set:

   ```bash
   docker compose down
   docker compose up -d
   ```

5. Browse to `http://<FORGEJO_DOMAIN>` to complete first-run setup. Since `FORGEJO__security__INSTALL_LOCK=true` is set, the install wizard is skipped — Forgejo comes up ready to use with the database settings supplied via environment variables.

**Notes**

- `FORGEJO__actions__ENABLED=true` is set, so Actions (and therefore the [`build.yml`](#build-workflow) / [`publish.yml`](#publish-workflow) workflows) are enabled out of the box.
- The runner container mounts `/var/run/docker.sock`, so jobs execute as sibling Docker containers on the host rather than nested inside the runner container.
- `/etc/timezone` and `/etc/localtime` are mounted read-only into the `forgejo` container so timestamps in the UI match the host's timezone.
- To stop the stack at any point, run `docker compose down` from the `configurations` directory. Add `-v` to also remove the named volumes (`forgejo_data`, `postgres_data`, `runner_data`) and wipe all data.

[↑ Top](#table-of-contents)
