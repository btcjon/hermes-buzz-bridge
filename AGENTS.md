# Agent Deployment Contract

This repository is designed so a capable coding or operations agent can deploy the Hermes ↔ Buzz bridge for its user.

## Objective

Connect one dedicated Buzz/Nostr agent identity to an existing Buzz community relay through `buzz-acp`, launching the user's existing Hermes profile with `hermes acp`.

## Required user-owned inputs

Ask only for inputs you cannot discover safely:

1. Buzz relay WebSocket URL.
2. Relay-owner access needed to register the new agent and add it to channels.
3. The owner's 64-character hexadecimal Nostr public key.
4. Which Buzz channels should contain the agent.
5. Approval before installing system services or changing host configuration.

Never ask the user to paste a private key into chat when it can be generated and stored directly on the target host.

## Execution contract

1. Read `README.md` completely before changing the host.
2. Inspect the host, existing Hermes installation, Buzz deployment, and current service state.
3. Verify `hermes acp --check` under the intended service account.
4. Build Buzz from the pinned commit in the README and install only `buzz-acp` and `buzz`.
5. Generate a dedicated agent keypair. Never reuse the user's personal key or relay-owner key.
6. Register the public key as a relay member and add it only to approved channels.
7. Copy `config/hermes-buzz.env.example` to a root-controlled path outside the repository and fill it there.
8. Keep these safe defaults unless the user explicitly approves a broader policy:
   - `BUZZ_ACP_RESPOND_TO=owner-only`
   - `BUZZ_ACP_SUBSCRIBE=mentions`
   - `BUZZ_ACP_PERMISSION_MODE=default`
9. Install the systemd template only after replacing every placeholder and validating it with `systemd-analyze verify`.
10. Start the service and verify all of the following:
    - service is active;
    - relay connection succeeds;
    - at least one approved channel is subscribed;
    - presence is online;
    - a real owner mention receives a Hermes response in Buzz.
11. Report the result without printing secrets. Include blockers and exact safe next actions if verification fails.

## Safety boundaries

- Never commit, log, display, or transmit private keys, provider tokens, database credentials, or environment files.
- Never copy credentials from `/etc`, `/srv`, backups, shell history, or another service into this repository.
- Never set `BUZZ_ACP_RESPOND_TO=anyone` or `BUZZ_ACP_PERMISSION_MODE=bypass-permissions` without explicit informed approval.
- Never expose the bridge before channel membership and author gates are verified.
- Never claim completion from process startup alone; require a real Buzz mention → Hermes → Buzz response.
- Prefer reversible changes and back up any existing unit or environment file before replacement.

## Completion report

Return:

- relay URL, with credentials omitted;
- agent public key;
- approved channel names or IDs;
- service status;
- Hermes ACP check result;
- end-to-end mention test result;
- any intentionally unavailable Hermes tools and why.
