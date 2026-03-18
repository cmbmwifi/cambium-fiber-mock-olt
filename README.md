# Cambium Fiber Mock OLT

Six containerized mock Cambium Fiber OLTs for hardware-free API development and integration testing.

**For:** Developers and integrators building against [Cambium Fiber API](https://github.com/cmbmwifi/cambium-fiber-api)

## Key Capabilities

- **Six mock OLTs in one command** — Full stack up with a single `docker compose` command
- **Fixture-backed device state** — ONUs, profiles, and configuration defined in editable JSON fixtures
- **Multi-firmware coverage** — One OLT runs the 1.2.0 login flow; five run the 1.3.0 flow
- **Resettable state** — Recreate any container to return it to fixture-defined state

## Quick Start

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) and [Cambium Fiber API](https://github.com/cmbmwifi/cambium-fiber-api) installed

### Install

From GitHub (recommended):
```bash
curl -fsSL https://raw.githubusercontent.com/cmbmwifi/cambium-fiber-mock-olt/main/install.sh | bash
```

Or locally if you've already cloned the repo:
```bash
./install.sh
```

This clones the repo to `/opt/cambium-fiber-mock-olt`, connects the API container to the mock OLT network, and starts all six mock OLT containers.

### Add OLTs to Cambium Fiber API

Open the Cambium Fiber API setup wizard and add these six OLTs:

| Hostname       | HTTPS Port | SSH Port |
|----------------|------------|----------|
| `mock-olt-631` | `443`      | `22`     |
| `mock-olt-632` | `443`      | `22`     |
| `mock-olt-633` | `443`      | `22`     |
| `mock-olt-634` | `443`      | `22`     |
| `mock-olt-635` | `443`      | `22`     |
| `mock-olt-636` | `443`      | `22`     |

Create a shared credential group:

- Username: `admin`
- Password: `password`

## Behavior That Matters

- OLT `mock-olt-632` models the 1.2 authentication flow. It does not expose `/api/v1/get_csrf_token`.
- The other five OLTs model the 1.3 authentication flow. They require a CSRF token before login.
- Login returns an auth token sent on subsequent requests as `Authorization: Basic <token>`.
- Sessions expire after 30 minutes.
- Concurrent session limits come from each fixture's `httpMaxGuiUsers` value.
- Runtime mutations are stored in memory. Recreating a container returns that OLT to its fixture-defined state.

## Fixture-Backed State

The files in `fixtures/*.json` define each OLT's starting state: device name, ONUs, management profiles, service profiles, and other configuration data.

Change a fixture when you want a different starting point for an integration test. Those edits apply only to newly started containers.

```bash
cd /opt/cambium-fiber-mock-olt
docker compose down
docker compose up -d --build
```

Treat fixtures as the source of truth and containers as disposable state.

## Useful Interfaces

The mock exposes the API surface that Cambium Fiber API expects.

REST API:

- `/api/v1/get_csrf_token`
- `/api/v1/login`
- `/api/v1/logout`
- `/api/v1/get_device_config`
- `/api/v1/apply_device_config`
- `/api/v1/config/system/device_name`

Debug and reset endpoints:

- `/api/v1/debug/state`
- `/api/v1/debug/sessions`
- `/api/v1/reset`

## Managing the Mock OLTs

```bash
# View logs
docker logs -f mock-olt-631

# Stop/Start
cd /opt/cambium-fiber-mock-olt
docker compose down
docker compose up -d

# Rebuild after fixture changes
cd /opt/cambium-fiber-mock-olt
docker compose up -d --build

# Override simulated latency (default: 1100ms)
cd /opt/cambium-fiber-mock-olt
MOCK_LATENCY_MS=500 docker compose up -d --build

# Uninstall
curl -fsSL https://raw.githubusercontent.com/cmbmwifi/cambium-fiber-mock-olt/main/uninstall.sh | bash
```

## Background Reading

New to fiber networking? [docs/concepts.md](docs/concepts.md) explains OLTs, ONUs, ONU profiles, service profiles, and how the fixture JSON maps to real device configuration.

---

**Mock OLTs:** 6 containers • **Firmware coverage:** 1.2.x–1.3.x • **License:** Apache 2.0

## Why This Exists

Hardware should not be the dependency that blocks integration work.

Use this repository to build against the same API shape you will encounter later in production, then swap in real OLT addresses when you are ready.

## Background Reading

New to fiber networking? [docs/concepts.md](docs/concepts.md) explains OLTs, ONUs, ONU profiles, service profiles, and how the fixture JSON maps to real device configuration.
