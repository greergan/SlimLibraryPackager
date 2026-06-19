<a href="https://codeberg.org/greergan/SlimTS">
  <img src="https://raw.githubusercontent.com/greergan/SlimTS/master/assets/slimts_logo.png" width="75" alt="SlimTS Logo">
</a>

# SlimLibraryPackager

A unified build system for the [SlimCommon](https://codeberg.org/greergan/SlimCommon) c++ library and its contained micro-libraries.  
The SlimCommon library is used by the [SlimTS](https://codeberg.org/greergan/SlimTS) typescript first platform.

## Table of Contents

- [Overview](#overview)
- [Library Setup](#library-setup)
  - [Links and files](#links-and-files)
  - [Defining Dependencies](#defining-dependencies)
  - [Building a Library](#building)
- [Forgejo Workflows](#forgejo-workflows)
  - [Setup](#setup)
  - [build.yml](#buildyml)
  - [publish.yml](#publishyml)
- [Using Docker](#using-docker)
  - [Dev Containers](#dev-containers)
  - [Docker Compose](#docker-compose)

## Overview


*Add content for the Overview here.*

[↑ Top](#table-of-contents)

## Defining Dependencies

*Add content for Defining Dependencies here.*

[↑ Top](#table-of-contents)

## Library Setup

*Add content for Library Setup here.*

[↑ Top](#table-of-contents)

## Building

*Add content for Building here.*

[↑ Top](#table-of-contents)

## Forgejo Workflows

*Add content for Forgejo Workflows here.*

[↑ Top](#table-of-contents)

### Setup

*Add content for Setup here.*

[↑ Top](#table-of-contents)

### build.yml

*Add content for build.yml here.*

[↑ Top](#table-of-contents)

### publish.yml

*Add content for publish.yml here.*

[↑ Top](#table-of-contents)

## Using Docker

*Add content for Using Docker here.*

[↑ Top](#table-of-contents)

### Dev Containers

*Add content for Dev Containers here.*

[↑ Top](#table-of-contents)

### Docker Compose

This repo includes a Docker Compose stack (`configurations/docker-compose.yml`) that spins up a self-hosted [Forgejo](https://forgejo.org/) instance, its Postgres database, and a Forgejo Actions runner — useful for running the [Forgejo Workflows](#forgejo-workflows) used to build and publish the SlimCommon libraries.

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

- `FORGEJO__actions__ENABLED=true` is set, so Actions (and therefore the [`build.yml`](#buildyml) / [`publish.yml`](#publishyml) workflows) are enabled out of the box.
- The runner container mounts `/var/run/docker.sock`, so jobs execute as sibling Docker containers on the host rather than nested inside the runner container.
- `/etc/timezone` and `/etc/localtime` are mounted read-only into the `forgejo` container so timestamps in the UI match the host's timezone.
- To stop the stack at any point, run `docker compose down` from the `configurations` directory. Add `-v` to also remove the named volumes (`forgejo_data`, `postgres_data`, `runner_data`) and wipe all data.

[↑ Top](#table-of-contents)
