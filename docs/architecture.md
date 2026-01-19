# Orqus Architecture

## Overview

Orqus is a high-performance EVM-compatible blockchain that combines:
- **Reth**: Modified Ethereum execution layer
- **CometBFT**: Byzantine fault-tolerant consensus
- **OrqusBFT**: ABCI bridge connecting the two layers

```
┌────────────────────────────────────────────────────────────────┐
│                        Orqus Node                              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │              │    │              │    │                  │  │
│  │  orqus-reth  │◄──►│   orqusbft   │◄──►│    CometBFT      │  │
│  │              │    │              │    │                  │  │
│  │  (Execution) │    │   (Bridge)   │    │   (Consensus)    │  │
│  │              │    │              │    │                  │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│         │                   │                    │              │
│         │ Engine API        │ ABCI               │ P2P          │
│         │ (JWT Auth)        │                    │              │
│         ▼                   ▼                    ▼              │
│    Port 8551           Port 8080            Port 26656         │
│                                                                │
└────────────────────────────────────────────────────────────────┘
                              │
                              │ External APIs
                              ▼
        ┌─────────────────────────────────────────┐
        │  RPC: 8545 (HTTP) / 8546 (WS)           │
        │  CometBFT RPC: 26657                    │
        │  Metrics: 9001 (reth) / 26660 (cometbft)│
        └─────────────────────────────────────────┘
```

## Component Details

### orqus-reth (Execution Layer)

Modified Reth client responsible for:
- EVM transaction execution
- State management
- JSON-RPC API
- P2P block propagation

**Key Ports:**
| Port | Protocol | Description |
|------|----------|-------------|
| 8545 | TCP | JSON-RPC HTTP |
| 8546 | TCP | JSON-RPC WebSocket |
| 8551 | TCP | Engine API (internal) |
| 30303 | TCP/UDP | P2P |
| 9001 | TCP | Prometheus metrics |

### orqusbft (Bridge Layer)

ABCI application that bridges execution and consensus:
- Receives transactions from CometBFT
- Forwards to Reth via Engine API
- Returns execution results to CometBFT
- Handles validator set updates

**Key Ports:**
| Port | Protocol | Description |
|------|----------|-------------|
| 8080 | TCP | ABCI (internal) |
| 9002 | TCP | Prometheus metrics |

### CometBFT (Consensus Layer)

Byzantine fault-tolerant consensus engine:
- Block proposal and voting
- Validator management
- P2P networking for consensus
- Transaction mempool

**Key Ports:**
| Port | Protocol | Description |
|------|----------|-------------|
| 26656 | TCP | P2P |
| 26657 | TCP | RPC |
| 26660 | TCP | Prometheus metrics |

## Transaction Flow

```
1. User submits tx via JSON-RPC (port 8545)
         │
         ▼
2. orqus-reth validates and adds to mempool
         │
         ▼
3. CometBFT proposer collects txs from mempool
         │
         ▼
4. Block proposed and voted on by validators
         │
         ▼
5. Committed block sent to orqusbft via ABCI
         │
         ▼
6. orqusbft forwards to orqus-reth via Engine API
         │
         ▼
7. orqus-reth executes txs and updates state
         │
         ▼
8. Execution result returned to CometBFT
```

## Consensus Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Block Time | ~2s | Target block interval |
| Epoch Length | 270 blocks | Validator set update period |
| Max Validators | 100 | Maximum active validators |

## Data Storage

```
/var/lib/orqus/
├── reth/           # Execution layer state
│   ├── db/         # State database
│   └── static/     # Static files
├── cometbft/       # Consensus layer data
│   ├── config/     # Configuration
│   └── data/       # Blockchain data
└── orqusbft/       # Bridge layer data
```

## Network Security

### Internal Communication
- Engine API (reth ↔ orqusbft): JWT authentication
- ABCI (orqusbft ↔ cometbft): Local socket/TCP

### External Ports
Only expose these ports externally:
- 26656 (CometBFT P2P) - Required for consensus
- 30303 (Reth P2P) - Required for block propagation
- 8545/8546 (RPC) - Only if providing RPC service
