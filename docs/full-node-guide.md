# Full Node Deployment Guide

This guide walks you through setting up an Orqus full node.

## Prerequisites

- Docker and Docker Compose v2.0+
- At least 200GB free disk space (SSD recommended)
- 8GB+ RAM
- Stable internet connection
- Ports 26656 (CometBFT P2P) and 30303 (Reth P2P) accessible

## Quick Start with Docker Compose

### 1. Clone the Repository

```bash
git clone https://github.com/orqus-chain/orqus-network.git
cd orqus-network
```

### 2. Configure Environment

```bash
cd docker
cp .env.example .env
```

Edit `.env` with your settings:

```bash
# Set your external IP (required for P2P)
EXTERNAL_IP=your.public.ip

# Set seed nodes (get from Orqus team)
COMETBFT_SEEDS=<node_id>@seed1.testnet.orqus.network:26656
RETH_BOOTNODES=enode://<pubkey>@seed1.testnet.orqus.network:30303
```

### 3. Initialize Data Directories

```bash
mkdir -p data/{reth,orqusbft,cometbft,jwt}

# Generate JWT secret for Engine API authentication
openssl rand -hex 32 > data/jwt/jwt.hex

# Initialize CometBFT
docker run --rm -v $(pwd)/data/cometbft:/cometbft cometbft/cometbft:v0.38.15 init
```

### 4. Start the Node

```bash
docker-compose up -d
```

### 5. Check Status

```bash
# View logs
docker-compose logs -f

# Check sync status
curl http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

# Check CometBFT status
curl http://localhost:26657/status
```

## Manual Setup (Without Docker)

### 1. Install Dependencies

#### orqus-reth
```bash
# Download from releases or build from source
wget https://github.com/orqus-chain/orqus-reth/releases/latest/download/orqus-reth-linux-amd64
chmod +x orqus-reth-linux-amd64
sudo mv orqus-reth-linux-amd64 /usr/local/bin/orqus-reth
```

#### CometBFT
```bash
wget https://github.com/cometbft/cometbft/releases/download/v0.38.15/cometbft_0.38.15_linux_amd64.tar.gz
tar -xzf cometbft_0.38.15_linux_amd64.tar.gz
sudo mv cometbft /usr/local/bin/
```

#### orqusbft
```bash
# Download from releases or build from source
wget https://github.com/orqus-chain/orqusbft/releases/latest/download/orqusbft-linux-amd64
chmod +x orqusbft-linux-amd64
sudo mv orqusbft-linux-amd64 /usr/local/bin/orqusbft
```

### 2. Create Data Directories

```bash
sudo mkdir -p /var/lib/orqus/{reth,cometbft,orqusbft}
sudo chown -R $USER:$USER /var/lib/orqus
```

### 3. Download Genesis Files

```bash
cd /var/lib/orqus
git clone https://github.com/orqus-chain/orqus-network.git config
```

### 4. Initialize CometBFT

```bash
cometbft init --home /var/lib/orqus/cometbft
cp config/networks/testnet/cometbft-genesis.json /var/lib/orqus/cometbft/config/genesis.json
```

### 5. Generate JWT Secret

```bash
openssl rand -hex 32 > /var/lib/orqus/jwt.hex
```

### 6. Create Systemd Services

Create `/etc/systemd/system/orqus-reth.service`:
```ini
[Unit]
Description=Orqus Reth Execution Layer
After=network.target

[Service]
Type=simple
User=orqus
ExecStart=/usr/local/bin/orqus-reth node \
    --chain /var/lib/orqus/config/networks/testnet/genesis-alloc.json \
    --datadir /var/lib/orqus/reth \
    --http --http.addr 127.0.0.1 --http.port 8545 \
    --ws --ws.addr 127.0.0.1 --ws.port 8546 \
    --authrpc.addr 127.0.0.1 --authrpc.port 8551 \
    --authrpc.jwtsecret /var/lib/orqus/jwt.hex \
    --port 30303
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Create similar services for `orqusbft` and `cometbft`.

### 7. Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable orqus-reth orqusbft cometbft
sudo systemctl start orqus-reth orqusbft cometbft
```

## Verifying Your Node

### Check Sync Status

```bash
# Reth sync status
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

# Returns false when fully synced
```

### Check Block Height

```bash
# Get current block
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Check Peer Count

```bash
# CometBFT peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# Reth peers
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

## Firewall Configuration

Open the following ports for P2P connectivity:

```bash
# UFW
sudo ufw allow 26656/tcp  # CometBFT P2P
sudo ufw allow 30303/tcp  # Reth P2P
sudo ufw allow 30303/udp  # Reth P2P discovery

# iptables
sudo iptables -A INPUT -p tcp --dport 26656 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 30303 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30303 -j ACCEPT
```

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues.

## Support

- Open an issue: https://github.com/orqus-chain/orqus-network/issues
- Email: support@orqus.network
