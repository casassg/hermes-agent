# Hermes Agent on Fly.io

Deploy a [Hermes Agent](https://hermes-agent.nousresearch.com/) instance on [Fly Machines](https://fly.io/docs/machines/) with persistent state, `gh`/`gws` CLI, WhatsApp bridge, and [Hermit](https://github.com/cashapp/hermit) tooling.

This repo is **infrastructure only** — no application code. It derives a Docker image from `nousresearch/hermes-agent:latest` and adds config, init scripts, and tooling.

## Quick start

```bash
# 1. Clone and set your app name in fly.toml
git clone https://github.com/casassg/hermes-agent.git
cd hermes-agent

# 2. Create the Fly app and a 1GB volume for persistent state
flyctl apps create hermes-agent
flyctl volumes create data --size 1

# 3. Deploy
./scripts/deploy.sh
```

The deploy script runs `flyctl deploy --build-only`, waits 30s for registry propagation, then deploys. See `scripts/deploy.sh`.

## Configuration

All Hermes state lives on the persistent volume at `/opt/data` (`.env`, `config.yaml`, `SOUL.md`, sessions, skills).

**Fly secrets don't reach `machine_config` containers.** SSH in to set secrets manually:

```bash
flyctl ssh console --machine <machine-id>
echo 'GH_TOKEN=ghp_xxx' >> /opt/data/.env
```

## Project structure

```
Dockerfile          Derived image: gh, gws, Hermit, WhatsApp bridge deps
fly.toml            Fly app config (region, volume mount, VM size)
machine_config.json Required for s6-overlay PID 1 namespace
cont-init/          s6 init scripts (run as root before gateway starts):
  015-chown-data      chown /opt/data → hermes:hermes
  016-fix-soul-perms  chmod 644 SOUL.md
  017-fix-debounce    WhatsApp message batching config
  018-gws-credentials GWS service account JSON (manual; see AGENTS.md)
  019-hermit-state    Hermit runtime state dir on volume
  020-gh-config       gh CLI config dir on volume
scripts/deploy.sh   Two-step deploy wrapper
```

## SSH access

```bash
flyctl ssh console --machine <machine-id>              # interactive
flyctl ssh console --machine <machine-id> -C "cmd"     # non-interactive
flyctl ssh console --machine <machine-id> --pty -C "cmd"  # with pty
```

## Docs

- [Hermes Agent docs](https://hermes-agent.nousresearch.com/)
- [Hermes Docker guide](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
- [Fly.io Hermes blueprint](https://fly.io/docs/blueprints/hermes-agent-on-fly-io/)

## License

[MIT](LICENSE)
