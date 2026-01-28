# Orqus Test

Network configuration exported from K8s cluster.

## Chain Info

- **Chain ID**: 153871
- **Network Name**: Orqus Test
- **RPC**: https://rpc-test.orqes.com

## Files

- `genesis.json` - CometBFT genesis configuration
- `el-genesis.json` - Ethereum execution layer genesis
- `genesis-alloc.json` - Genesis account allocations
- `chain-info.json` - Network metadata and endpoints
- `jwt.hex` - JWT secret for Engine API authentication

## Seeds

### CometBFT P2P
```
1206dae3ff4886b12a8e7f76b49ff487206bbf56@47.243.179.141:31259
```

### Reth P2P
```
<configure manually>
```

## Run RPC Node with Docker

```bash
cd docker/sentry

# Create .env file
cat > .env << EOF
NETWORK=test
EXTERNAL_IP=$(curl -s ifconfig.me)
COMETBFT_SEEDS=1206dae3ff4886b12a8e7f76b49ff487206bbf56@47.243.179.141:31259
RETH_BOOTNODES=
RPC_HOST=0.0.0.0
EOF

# Create data directories
mkdir -p data/{reth,cometbft,orqusbft,jwt}

# Copy JWT secret
cp ../../networks/test/jwt.hex data/jwt/

# Initialize CometBFT
docker run --rm -v $(pwd)/data/cometbft:/cometbft cometbft/cometbft:v0.38.15 init

# Start services
docker compose up -d
```

## Generated

- Date: 2026-01-28T02:44:04Z
- Namespace: orqus-test
- Release: orqus-node
