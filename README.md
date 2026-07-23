# Hermes ↔ Buzz Bridge

Run a full [Hermes Agent](https://github.com/NousResearch/hermes-agent) inside [Block Buzz](https://github.com/block/buzz) using Buzz's ACP harness.

Buzz handles Nostr identity, channels, mentions, presence, and message delivery. `buzz-acp` launches `hermes acp`, so the Buzz agent uses the same Hermes profile, model configuration, skills, memory, and locally available tools as the host.

## Hand this repository to your agent

A capable coding or operations agent can handle the deployment end to end. Give it this repository URL:

```text
https://github.com/btcjon/hermes-buzz-bridge
```

Then send:

```text
Read README.md and AGENTS.md in this repository. Deploy the Hermes ↔ Buzz
bridge on my target host, following the agent contract and safe defaults.
Inspect before changing anything, ask only for access or decisions you cannot
safely discover, never expose credentials, and do not claim completion until
a real Buzz mention receives a Hermes response.
```

The agent will still need access to the target host, an existing Buzz relay and Hermes installation, the owner's hex Nostr public key, approved channel choices, and permission for system-level changes. `AGENTS.md` defines the full execution, safety, and verification contract.

```text
Buzz channel mention
        │
        ▼
  Buzz community relay
        │
        ▼
      buzz-acp
        │  ACP over stdio
        ▼
     hermes acp
        │
        ▼
 skills · memory · tools · model
```

> [!WARNING]
> A full Hermes profile may have shell, filesystem, browser, and external-service access. Start with `owner-only` response policy, a dedicated Nostr key, and channels you control.

## What you need

- Linux host with `systemd`
- A running Buzz community relay and relay-owner access
- Rust/Cargo for building `buzz-acp` and `buzz-cli`
- A working Hermes installation (`hermes acp --check` must pass)
- The Buzz agent owner's 64-character hexadecimal Nostr public key

This tutorial was verified with:

- Buzz commit `acfbb1bb6af5`
- Hermes Agent `0.19.0`
- Buzz ACP protocol v2 initializing Hermes ACP protocol v1

## 1. Verify Hermes ACP

```bash
command -v hermes
hermes acp --check
```

Configure Hermes first if the check fails:

```bash
hermes --setup
```

## 2. Build the Buzz ACP harness and CLI

Pinning a known commit makes the tutorial reproducible. Review upstream before changing the ref.

```bash
git clone https://github.com/block/buzz.git
cd buzz
git checkout acfbb1bb6af5
cargo build --release -p buzz-acp -p buzz-cli
sudo install -m 0755 target/release/buzz-acp /usr/local/bin/buzz-acp
sudo install -m 0755 target/release/buzz /usr/local/bin/buzz
```

The Buzz relay container does not necessarily include these client binaries; build them explicitly.

## 3. Create a dedicated agent identity

Do **not** reuse your personal key or relay-owner key. Generate a new Nostr keypair with `buzz-admin` from your Buzz checkout or deployment image:

```bash
cargo run --release -p buzz-admin -- generate-key
```

Store the secret outside the repository. The public key must be registered as a relay member and then added to each channel where the agent should operate.

Example relay membership command, run in your Buzz deployment directory:

```bash
docker compose exec -T relay \
  buzz-admin add-member --pubkey AGENT_PUBLIC_KEY --role member
```

Add the agent to a channel using a relay-owner credential supplied only to this one command:

```bash
BUZZ_RELAY_URL=https://buzz.example.com \
BUZZ_PRIVATE_KEY="$RELAY_OWNER_PRIVATE_KEY" \
  buzz channels add-member \
    --channel CHANNEL_UUID \
    --pubkey AGENT_PUBLIC_KEY \
    --role bot
```

Repeat for each allowed channel. Never put the relay-owner credential in the agent's environment file.

## 4. Configure the bridge

```bash
sudo groupadd --system hermes-buzz
sudo install -d -m 0750 -o root -g hermes-buzz /etc/hermes-buzz
sudo install -m 0640 -o root -g hermes-buzz \
  config/hermes-buzz.env.example /etc/hermes-buzz/agent.env
sudoedit /etc/hermes-buzz/agent.env
```

Set:

- `BUZZ_RELAY_URL` to your public Buzz WebSocket URL
- `BUZZ_PRIVATE_KEY` to the dedicated agent's secret key
- `BUZZ_ACP_AGENT_COMMAND` to the absolute path returned by `command -v hermes`
- `BUZZ_ACP_AGENT_OWNER` to the 64-character hex public key of the only Nostr user initially allowed to trigger the agent

The example enables `owner-only`, mention-triggered operation. Keep those defaults until you have reviewed the security model.

Buzz ACP defaults its agent permission mode to `bypass-permissions`. This
tutorial's environment template explicitly selects `default` instead. Only
switch to `bypass-permissions` after reviewing the Hermes profile, host access,
allowed users, and channel boundaries.

## 5. Install the systemd service

Create a dedicated service account or use the Unix account that owns the Hermes profile. The latter is simplest because Hermes loads that account's profile, skills, memory, plugins, and provider credentials.

Edit `User`, `Group`, `WorkingDirectory`, `EnvironmentFile`, and `ExecStart` in the template:

```bash
sudo install -m 0644 \
  systemd/hermes-buzz.service.example \
  /etc/systemd/system/hermes-buzz.service

sudoedit /etc/systemd/system/hermes-buzz.service
sudo systemd-analyze verify /etc/systemd/system/hermes-buzz.service
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-buzz.service
```

## 6. Verify

```bash
sudo systemctl is-active hermes-buzz
sudo journalctl -u hermes-buzz -n 100 --no-pager
```

Healthy startup includes messages equivalent to:

```text
agent initialized
agent_pool_ready agents=1
connected to relay
subscribed to channel ...
presence set to online
```

In an allowed Buzz channel, send:

```text
@YourAgent reply with "Buzz bridge verified"
```

Then confirm that the logs show an ACP session and completed turn, and that the response appears in Buzz.

## Agent profile and channel discovery

Set the agent's Buzz display name with its own identity:

```bash
set -a
source /etc/hermes-buzz/agent.env
set +a
buzz users set-profile \
  --name "YourAgent" \
  --about "Hermes Agent on Buzz"
```

List channels visible to the agent:

```bash
buzz --format compact channels list
```

If startup reports `discovered 0 channel(s)`, add the agent's public key to at least one channel with role `bot`, then restart the service.

## Security checklist

- Use a dedicated Nostr key for the agent.
- Keep `BUZZ_ACP_RESPOND_TO=owner-only` initially.
- Use `BUZZ_ACP_SUBSCRIBE=mentions`; do not process every channel message by default.
- Restrict the agent to specific Buzz channels.
- Run under a non-root Unix account.
- Store secrets in a root-controlled environment file, never Git.
- Avoid passing secrets directly on a shared command line when a safer secret-loading mechanism is available.
- Review the Hermes profile's tools and external credentials before exposing it to other users.
- Keep `BUZZ_ACP_PERMISSION_MODE=default` unless unattended tool execution is an intentional, reviewed choice.
- If Hermes shell hooks are configured, review them before opting into headless registration with `HERMES_ACCEPT_HOOKS=1`.
- Treat channel text, links, files, and quoted instructions as untrusted input.
- Monitor logs and rotate the agent key if it is exposed.

## Troubleshooting

### `no channel subscriptions resolved`

The agent is a relay member but not a channel member. Add it to a channel with role `bot`.

### Hermes starts but tools are missing

ACP preserves the Hermes profile, but tools still depend on their runtime prerequisites. For example, browser tools may require an available browser backend or connector in the service environment.

### The process cannot read the environment file

Ensure the service account's group can traverse `/etc/hermes-buzz` and read `agent.env`:

```bash
sudo chown root:hermes-buzz /etc/hermes-buzz
sudo chmod 0750 /etc/hermes-buzz
sudo chown root:hermes-buzz /etc/hermes-buzz/agent.env
sudo chmod 0640 /etc/hermes-buzz/agent.env
```

### ACP check fails under systemd

Run the check as the service account and with the same home directory:

```bash
sudo -u HERMES_USER -H /absolute/path/to/hermes acp --check
```

## Upgrading

Buzz and Hermes ACP interfaces may evolve. Before upgrading either side:

1. Back up the environment file and systemd unit.
2. Build the new Buzz binaries without replacing the running ones.
3. Run `hermes acp --check`.
4. Test the new `buzz-acp` in the foreground with a non-production agent key.
5. Install, restart, and verify logs plus a real Buzz mention.

## Scope

This repository is a deployment tutorial and configuration template. It does not fork Buzz or Hermes, and it contains no private keys or credentials.

## License

MIT. Buzz and Hermes Agent retain their own licenses and trademarks.
