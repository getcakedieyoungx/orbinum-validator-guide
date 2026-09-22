```
   ██████╗ ██████╗ ██████╗ ██╗███╗   ██╗██╗   ██╗███╗   ███╗
  ██╔═══██╗██╔══██╗██╔══██╗██║████╗  ██║██║   ██║████╗ ████║
  ██║   ██║██████╔╝██████╔╝██║██╔██╗ ██║██║   ██║██╔████╔██║
  ██║   ██║██╔══██╗██╔══██╗██║██║╚██╗██║██║   ██║██║╚██╔╝██║
  ╚██████╔╝██║  ██║██████╔╝██║██║ ╚████║╚██████╔╝██║ ╚═╝ ██║
   ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝
            V A L I D A T O R   ·   T E S T N E T
```

# Orbinum Validator Guide

A tested, script-driven guide to running an **Orbinum testnet validator**: install, sync, session keys, `session.setKeys`, and the application email. The scripts check every gate the Orbinum team checks before approving a validator.

> Written from a real install on 22 Sep 2026. Warp sync reached the chain head in about 5 minutes.

---

## What Orbinum is, and what you actually earn

- **A privacy chain.** Substrate + EVM, with a shielded pool: balances and transfers inside it are hidden behind zero-knowledge (Groth16) proofs.
- **The validator set is permissioned.** No bond, no stake, no slashing. You run a node, register session keys, email the team, and they add you with one sudo call. The set is capped at **32**.
- **A validator's only income is relay fees** from private transactions, paid in testnet ORB.

> ⚠️ **Running a validator does not earn Season 1 airdrop credits.** The 20,000,000 ORB Season 1 pool is split by **ORB Credits**, which come from quests, testnet quests, weekly streaks, quizzes and referrals. Network-security rewards are planned for Seasons 2–3, after mainnet. If the airdrop is your goal, do the quests (see [Earn ORB Credits](#earn-orb-credits)). The node is a bonus.

---

## How it works

```
  ┌──────────────┐  install.sh  ┌──────────────┐  warp sync  ┌──────────────┐
  │   VPS        │ ───────────▶ │  orbinum     │ ──────────▶ │  synced      │
  │ Ubuntu 24.04 │              │  node        │             │  (~5 min)    │
  └──────────────┘              └──────────────┘             └──────┬───────┘
                                                                    │ session-keys.sh
                                                                    ▼
  ┌──────────────┐    email     ┌──────────────┐  setKeys    ┌──────────────┐
  │  team adds   │ ◀─────────── │  check.sh    │ ◀────────── │  keys+proof  │
  │  you (sudo)  │              │  all green   │ Polkadot.js │              │
  └──────────────┘              └──────────────┘             └──────────────┘
```

---

## 1. Get a server

| Spec | Minimum | Recommended |
|---|---|---|
| CPU | 4 **dedicated** cores | 8 dedicated cores |
| RAM | 8 GB | 16 GB |
| Disk | 200 GB NVMe | 500 GB NVMe |
| Network | 100 Mbit, static IPv4 | 1 Gbit |
| OS | Ubuntu 22.04 | Ubuntu 24.04 |

The docs say shared vCPU is **not enough**: validators verify ZK proofs inside blocks, and a throttled CPU misses slots. A shared-vCPU VPS will run the node fine, but it lowers your chances of being picked. Provider diversity is also a selection factor, so a less common provider helps.

State import peaks at **~5–6 GB RAM**. `install.sh` adds a 4 GB swap file if the server has less than 16 GB and no swap.

## 2. Install the node

```bash
git clone https://github.com/getcakedieyoungx/orbinum-validator-guide.git
cd orbinum-validator-guide
sudo bash scripts/install.sh <your-validator-name>
```

What it does:

- installs Docker from **Docker's own apt repo**, not a third-party script
- clones the official [`orbinum/node-deploy`](https://github.com/orbinum/node-deploy) and creates `.env` with a fresh node key and warp sync
- opens only **30333/tcp** in ufw. The RPC port 9944 runs `--rpc-methods Unsafe` and must never be public.
- starts the node plus Watchtower, which applies image updates automatically

Follow the sync:

```bash
cd /root/node-deploy/testnet/validator && docker compose logs -f orbinum-validator
```

Wait until the logs show `Imported #…` at the chain head.

## 3. Wallet and faucet

1. Install [Talisman](https://talisman.xyz) (or SubWallet / Polkadot.js extension) and create a **Polkadot / Substrate** account. Its address starts with `5…`.
2. Join the Orbinum Discord and verify. The link is on the [Channels](https://docs.orbinum.network/community/channels) page.
3. Get ORB from the [faucet](https://faucet.orbinum.network/) (5 ORB / 24 h). `setKeys` is a signed transaction and needs a balance for the fee.

Use this same wallet for the quests: sign in at the [Orbinum App](https://app.orbinum.network/community?ref=ORB-KGTWCB) *(referral)*. Talisman gets a **+5 credit bonus** on every testnet quest.

## 4. Generate session keys

```bash
sudo bash scripts/session-keys.sh <your 5… address>
```

It refuses to run until the node is synced, binds the keys to your account (`author_rotateKeysWithOwner`), and prints:

- `keys`, both as one field and split into **aura** / **grandpa** (some Polkadot.js versions show two boxes)
- `proof`
- whether the node holds the private halves (`true` is what you want)

The output is saved to `/root/orbinum-session-keys.json`. **Run it once.** Running it again rotates the keys, and the ones you submitted stop working. The script refuses a second run unless you pass `--force`.

## 5. Submit `session.setKeys`

1. Open [Polkadot.js → Extrinsics](https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Frpc-1.testnet.orbinum.io#/extrinsics).
2. **Account box empty?** Talisman is not connected to the site. Click the Talisman icon → connect `polkadot.js.org` → pick your account → reload.
3. Select your account, then `session` → `setKeys(keys, proof)`.
4. Paste `keys` and `proof` from step 4 → **Submit Transaction** → sign.

`Session.InvalidProof` means the signing account is not the one you passed to the script.

## 6. Check every gate

```bash
sudo bash scripts/check.sh <your 5… address>
```

```
Orbinum validator check
  synced (isSyncing false)           yes
  peers                              8
  session.nextKeys on-chain          yes
  node holds those keys              true
  matches last generated keys        yes
  telemetry flag                     on
```

`session.nextKeys` is read straight from chain storage. No Polkadot.js needed, and no pip installs (the storage key is computed by `scripts/nextkeys.py`).

Also confirm **30333** is reachable from outside: `nc -vz <server-ip> 30333` from another machine.

## 7. Apply by email

Send to **contact@orbinum.net**, subject `Testnet validator application — <your name>`:

```
Hi Orbinum team,

I'd like to apply for the testnet validator set.

- SS58 address: <your 5… address>
- Operator: <name / X / GitHub>
- Experience: <networks you run, or "first validator">
- Provider / region: <e.g. Hetzner, Finland>
- Contact: <Discord or Telegram handle>
- Telemetry name: <your validator name>
- Monitoring: <how you'd notice an outage>

Session keys are set (session.nextKeys returns them) and
author_hasSessionKeys is true on the node.

Thanks!
```

There's no SLA and no guaranteed acceptance. If you're added, the node starts authoring after **two session rotations (~2 hours)**.

---

## Earn ORB Credits

The airdrop comes from here, not from the node. Start at the [Orbinum App](https://app.orbinum.network/community?ref=ORB-KGTWCB) *(referral)*: connect your wallet, then link Discord, Telegram and X for the +30 signup bonus. See [ORB Credits](https://docs.orbinum.network/community/orb-credits).

| Source | Credits |
|---|---|
| Verify wallet + Discord + Telegram + X | +30 once |
| Testnet quests: shield, private transfer, unshield, selective disclosure | 15–20 each (+5 with Talisman), up to ×1.5 with streak |
| Weekly social quests | 5–10 each |
| Weekly streak | 50, +25 / week, cap 500 |
| Quizzes | 20 each |
| Daily wheel | varies |

> ❌ **Do not automate quests.** The [rules](https://docs.orbinum.network/community/rules) ban bots, scripts and "automated quest claims". Bans are permanent and cover your Discord/Telegram too. One account per person.

---

## Useful commands

```bash
cd /root/node-deploy/testnet/validator
docker compose logs -f orbinum-validator            # live logs
docker compose ps                                   # container status
docker compose up -d --force-recreate orbinum-validator   # after editing .env (restart is not enough)
sudo bash ~/orbinum-validator-guide/scripts/check.sh <address>
```

## Ports

| Port | Exposure | Purpose |
|---|---|---|
| 30333/tcp | public | P2P, required |
| 9944 | **never public** (loopback only) | RPC with unsafe methods: anyone reaching it can rotate your keys |
| 9615 | loopback / private IP | Prometheus metrics |

## FAQ

**The node says my hardware doesn't meet the requirements.** That's the benchmark warning for the Authority role. The node still runs. It's a signal for the team, not a blocker.

**Can I run it next to another node?** Yes. It runs in Docker and only needs 30333. I run it on the same VPS as an Asentum validator.

**I rotated keys by accident.** Run `session-keys.sh --force`, submit `setKeys` again with the new values, then re-run `check.sh`.

---

## Links

- Orbinum App (quests): https://app.orbinum.network/community?ref=ORB-KGTWCB *(referral)*
- Docs: https://docs.orbinum.network
- Faucet: https://faucet.orbinum.network
- Telemetry: https://telemetry.orbinum.network
- Official deploy files: https://github.com/orbinum/node-deploy
- Telegram group: https://t.me/getcakedieyoungx

Thanks to [molla202](https://github.com/molla202/orbinum) for the original Turkish walkthrough.

## Disclaimer

Community guide, not affiliated with Orbinum. Testnet tokens have no value and the chain may be reset. Scripts are provided as-is. Read them before running anything as root.

MIT License
