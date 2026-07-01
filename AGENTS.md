# Evander — Hermes Agent on Fly.io

Deployment repo for a Hermes Agent instance running on Fly Machines. No application code — just infrastructure config and a derived Dockerfile.

## Deploy

```bash
./bin/flyctl deploy --build-only && sleep 30 && ./bin/flyctl deploy
```

Two-step is required: `--build-only` pushes the image, then the 30s wait lets the Fly registry propagate before the machine update. A single `fly deploy` fails with `MANIFEST_UNKNOWN` due to registry propagation race.

`flyctl` is managed by Hermit (`./bin/flyctl`). Don't install a system-level flyctl.

## Architecture

- `Dockerfile` — derived from `nousresearch/hermes-agent:latest`; adds `gh`, `gws` CLI, WhatsApp bridge deps, and cont-init scripts.
- `fly.toml` — no `[build] image` (removed so Fly builds from the Dockerfile instead of pulling the stock image).
- `machine_config.json` — **required**. Hermes uses s6-overlay as PID 1; `s6-overlay-suexec` checks `getpid() == 1` and aborts without the container namespace that `machine_config` provides. Never remove this file.
- `cont-init/` — s6 init scripts copied into `/etc/cont-init.d/`. Run as root before the gateway starts.
- `/opt/data` — Fly volume mount. All Hermes state lives here (`.env`, `config.yaml`, `SOUL.md`, sessions, skills, WhatsApp session). Persists across restarts and deploys.

## Secrets don't work with machine_config containers

Fly secrets are set at the app level but **not injected into the container environment** when using `machine_config.json` with `containers`. This is a known limitation of the Fly container feature.

To set secrets (API keys, tokens, credential files), SSH in and write them to the volume:

```bash
./bin/flyctl ssh console --machine 1854537b5343d8
echo 'GH_TOKEN=ghp_xxx' >> /opt/data/.env
echo 'GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/opt/data/.gws/service-account.json' >> /opt/data/.env
# Write credential JSONs to /opt/data/ (e.g. /opt/data/.gws/service-account.json)
```

The gateway reads `/opt/data/.env` and passes env vars to all subprocesses (`gh`, `gws`, etc.).

## SSH and interactive commands

```bash
./bin/flyctl ssh console --machine 1854537b5343d8              # interactive shell
./bin/flyctl ssh console --machine 1854537b5343d8 -C "cmd"    # non-interactive (no pty)
./bin/flyctl ssh console --machine 1854537b5343d8 --pty -C "cmd"  # with pty
```

`-C` without `--pty` does not allocate a terminal. Commands that need interactivity (e.g. `hermes whatsapp` QR onboarding) require either `--pty` or an interactive shell (no `-C`).

The `hermes` binary drops to uid 10000 (`hermes`) via `s6-setuidgid`. Root-only operations need the full path: `/package/admin/s6-2.15.0.0/command/s6-setuidgid`.

## cont-init scripts

- `016-fix-soul-perms` — `chmod 644 /opt/data/SOUL.md`. The base image seeds SOUL.md via `cp` without a subsequent chmod; a restrictive s6 umask leaves it 444 (read-only), which blocks `save_env_value` → `/sethome` fails with `PermissionError`.
- `017-fix-debounce` — ensures WhatsApp message batching (`text_batch_delay_seconds: 5.0`) is in `config.yaml` under `gateway.platforms.whatsapp.extra`.
- `018-gws-credentials` — writes `GOOGLE_WORKSPACE_CLI_CREDENTIALS_JSON` env var to `/opt/data/.gws/service-account.json`. Currently non-functional because Fly secrets don't reach the container (see above). Write the JSON file manually instead.

## Key paths inside the container

- `/opt/hermes/` — immutable install tree (root-owned, read-only to hermes user).
- `/opt/data/` — persistent volume (hermes-owned, writable). `HERMES_HOME=/opt/data`.
- `/opt/hermes/scripts/whatsapp-bridge/` — WhatsApp bridge code. Pre-installed deps in the Dockerfile (base image has 555 perms on this dir).
- `/opt/data/.env` — API keys and secrets. The gateway reads this and sets env vars for subprocesses.
- `/opt/data/config.yaml` — Hermes config (gateway, platforms, debounce, etc.).
- `/opt/data/SOUL.md` — agent persona. Must be writable (644) or `save_env_value` fails.

## .gitignore

`*.json` is gitignored except `machine_config.json`. Service account JSONs and other credential files are excluded from version control.

## Hermes docs

- WhatsApp setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/whatsapp
- Docker guide: https://hermes-agent.nousresearch.com/docs/user-guide/docker
- Fly blueprint: https://fly.io/docs/blueprints/hermes-agent-on-fly-io/
