# Orqus Network

Run a full node on the Orqus blockchain network.

## Overview

Orqus is a high-performance EVM-compatible blockchain built on:
- **orqus-reth**: Modified Reth execution layer
- **orqusbft**: ABCI bridge connecting execution and consensus
- **CometBFT**: Byzantine fault-tolerant consensus engine

## Quick Start

### One-Line Install (Recommended)

```bash
# Install orqus-node CLI
curl -L https://orqes.com/install | bash

# Initialize and start node
orqus-node init --network testnet
orqus-node start

# Check status
orqus-node status
orqus-node logs -f
```

### CLI Commands

```bash
orqus-node init --network testnet   # Initialize node
orqus-node start                    # Start node
orqus-node stop                     # Stop node
orqus-node restart                  # Restart node
orqus-node status                   # Show sync status
orqus-node logs -f                  # Follow logs
orqus-node info                     # Show node info
orqus-node update                   # Update to latest
```

### Manual Setup (Docker Compose)

```bash
# Clone the repository
git clone https://github.com/orqus-chain/orqus-network.git
cd orqus-network

# Configure environment
cp docker/.env.example docker/.env
# Edit docker/.env with your settings

# Start the node
cd docker
docker-compose up -d

# Check logs
docker-compose logs -f
```

For more details, see [Full Node Guide](docs/full-node-guide.md).

## Networks

| Network | Chain ID | Status | Documentation |
|---------|----------|--------|---------------|
| Testnet | 153871 | Active | [networks/testnet/](networks/testnet/) |
| Mainnet | TBD | Coming Soon | [networks/mainnet/](networks/mainnet/) |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Your Node                          │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  orqus-reth │◄─┤  orqusbft   │◄─┤    CometBFT     │  │
│  │ (Execution) │  │   (Bridge)  │  │   (Consensus)   │  │
│  │             │  │             │  │                 │  │
│  │ Port: 8545  │  │ Port: 8080  │  │ Port: 26656 P2P │  │
│  │ Port: 30303 │  │             │  │ Port: 26657 RPC │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 8545 | TCP | JSON-RPC HTTP |
| 8546 | TCP | JSON-RPC WebSocket |
| 30303 | TCP/UDP | Reth P2P |
| 26656 | TCP | CometBFT P2P |
| 26657 | TCP | CometBFT RPC |

## Hardware Requirements

### Minimum
- CPU: 4 cores
- RAM: 8 GB
- Storage: 200 GB SSD
- Network: 100 Mbps

### Recommended
- CPU: 8 cores
- RAM: 16 GB
- Storage: 500 GB NVMe SSD
- Network: 1 Gbps

## Documentation

- [Full Node Guide](docs/full-node-guide.md) - Step-by-step deployment
- [Architecture](docs/architecture.md) - Technical details
- [Troubleshooting](docs/troubleshooting.md) - Common issues

## Resources

- Website: https://orqus.io
- Explorer: https://explorer.orqes.com
- RPC Endpoint: https://rpc.orqes.com

## Support

For technical support, please open an issue or contact us at support@orqus.io

## License

Apache 2.0
