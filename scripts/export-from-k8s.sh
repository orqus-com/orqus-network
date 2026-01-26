#!/bin/bash
# Export network configuration from K8s cluster
# Usage: ./scripts/export-from-k8s.sh <network-name> [namespace] [release-name]
# Example: ./scripts/export-from-k8s.sh testnet orqus-test orqus-node

set -e

NETWORK_NAME="${1:-testnet}"
NAMESPACE="${2:-orqus-test}"
RELEASE_NAME="${3:-orqus-node}"
OUTPUT_DIR="networks/${NETWORK_NAME}"

# Capitalize first letter
NETWORK_NAME_CAP="$(echo "${NETWORK_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${NETWORK_NAME:1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "=== Exporting network config from K8s ==="
echo "Network: $NETWORK_NAME"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Output: $OUTPUT_DIR"
echo ""

# Check kubectl access
if ! kubectl get pods -n $NAMESPACE &>/dev/null; then
  error "Cannot access namespace $NAMESPACE. Check kubectl config."
fi

# Check pod exists
if ! kubectl get pod ${RELEASE_NAME}-0 -n $NAMESPACE &>/dev/null; then
  error "Pod ${RELEASE_NAME}-0 not found in namespace $NAMESPACE"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# 1. Export CometBFT genesis (genesis.json)
info "[1/6] Exporting CometBFT genesis..."
kubectl cp ${RELEASE_NAME}-0:/data/cometbft/config/genesis.json "$OUTPUT_DIR/genesis.json" -n $NAMESPACE -c cometbft
echo "  -> genesis.json"

# 2. Export Reth genesis (keep original format for exact hash match)
info "[2/6] Exporting Reth genesis..."
kubectl cp ${RELEASE_NAME}-0:/data/reth/genesis.json "$OUTPUT_DIR/el-genesis.json" -n $NAMESPACE -c orqus-reth
echo "  -> el-genesis.json"

# 3. Extract genesis alloc to separate file
info "[3/6] Extracting genesis alloc..."
jq '.alloc' "$OUTPUT_DIR/el-genesis.json" > "$OUTPUT_DIR/genesis-alloc.json"
echo "  -> genesis-alloc.json"

# 4. Export JWT secret
info "[4/6] Exporting JWT secret..."
kubectl cp ${RELEASE_NAME}-0:/data/reth/jwt.hex "$OUTPUT_DIR/jwt.hex" -n $NAMESPACE -c orqus-reth
echo "  -> jwt.hex"

# 5. Gather connection info
info "[5/6] Gathering connection info..."

# Get chain ID from genesis
CHAIN_ID=$(jq -r '.config.chainId // .chainId // empty' "$OUTPUT_DIR/el-genesis.json")
if [ -z "$CHAIN_ID" ] || [ "$CHAIN_ID" = "null" ]; then
  CHAIN_ID=$(jq -r '.chain_id // empty' "$OUTPUT_DIR/genesis.json")
fi
echo "  Chain ID: $CHAIN_ID"

# Get CometBFT node ID from first node
COMETBFT_NODE_ID=$(kubectl exec ${RELEASE_NAME}-0 -n $NAMESPACE -c cometbft -- cometbft show-node-id 2>/dev/null || echo "")
echo "  CometBFT Node ID: ${COMETBFT_NODE_ID:-<not found>}"

# Get Reth enode from logs (if available)
RETH_ENODE=$(kubectl logs ${RELEASE_NAME}-0 -n $NAMESPACE -c orqus-reth 2>&1 | grep -oE 'enode://[a-f0-9]+' | head -1 || echo "")
echo "  Reth Enode: ${RETH_ENODE:-<not found>}"

# Get NodePort info
P2P_SVC=$(kubectl get svc ${RELEASE_NAME}-p2p -n $NAMESPACE -o json 2>/dev/null || echo "{}")
COMETBFT_NODEPORT=$(echo "$P2P_SVC" | jq -r '.spec.ports[] | select(.name=="cometbft-p2p") | .nodePort // empty' 2>/dev/null || echo "")
RETH_NODEPORT=$(echo "$P2P_SVC" | jq -r '.spec.ports[] | select(.name=="reth-p2p-tcp") | .nodePort // empty' 2>/dev/null || echo "")
echo "  CometBFT NodePort: ${COMETBFT_NODEPORT:-<not found>}"
echo "  Reth NodePort: ${RETH_NODEPORT:-<not found>}"

# Get K8s node IPs
NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
if [ -z "$NODE_IPS" ]; then
  NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
fi
FIRST_NODE_IP=$(echo $NODE_IPS | awk '{print $1}')
echo "  K8s Node IP: ${FIRST_NODE_IP:-<not found>}"

# Get ingress host
INGRESS_HOST=$(kubectl get ingress ${RELEASE_NAME} -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
echo "  Ingress Host: ${INGRESS_HOST:-<not found>}"

# Build seeds
COMETBFT_SEED=""
if [ -n "$COMETBFT_NODE_ID" ] && [ -n "$FIRST_NODE_IP" ] && [ -n "$COMETBFT_NODEPORT" ]; then
  COMETBFT_SEED="${COMETBFT_NODE_ID}@${FIRST_NODE_IP}:${COMETBFT_NODEPORT}"
fi

RETH_SEED=""
if [ -n "$RETH_ENODE" ] && [ -n "$FIRST_NODE_IP" ] && [ -n "$RETH_NODEPORT" ]; then
  RETH_SEED="${RETH_ENODE}@${FIRST_NODE_IP}:${RETH_NODEPORT}"
fi

# 6. Generate chain-info.json
info "[6/6] Generating chain-info.json..."

# Use default RPC host if ingress not found
RPC_HOST="${INGRESS_HOST:-rpc-${NETWORK_NAME}.orqes.com}"

cat > "$OUTPUT_DIR/chain-info.json" << CHAININFO
{
  "name": "Orqus ${NETWORK_NAME_CAP}",
  "chainId": ${CHAIN_ID},
  "networkId": ${CHAIN_ID},
  "nativeCurrency": {
    "name": "ORQUS",
    "symbol": "ORQ",
    "decimals": 18
  },
  "rpc": {
    "http": "https://${RPC_HOST}",
    "ws": "wss://${RPC_HOST}/ws"
  },
  "explorer": "https://explorer-${NETWORK_NAME}.orqes.com",
  "consensus": {
    "type": "CometBFT",
    "blockTime": "2s",
    "epochLength": 270
  },
  "seeds": {
    "cometbft": [
      "${COMETBFT_SEED:-<NODE_ID>@seed1.${NETWORK_NAME}.orqes.com:26656}"
    ],
    "reth": [
      "${RETH_SEED:-enode://<PUBKEY>@seed1.${NETWORK_NAME}.orqes.com:30303}"
    ]
  },
  "contracts": {
    "validatorRegistry": "0x0000000000000000000000000000001000000001",
    "staking": "0x0000000000000000000000000000001000000002"
  },
  "status": "active",
  "launchDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CHAININFO
echo "  -> chain-info.json"

# Generate README
CURRENT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$OUTPUT_DIR/README.md" << README
# Orqus ${NETWORK_NAME_CAP}

Network configuration exported from K8s cluster.

## Chain Info

- **Chain ID**: ${CHAIN_ID}
- **Network Name**: Orqus ${NETWORK_NAME_CAP}
- **RPC**: https://${RPC_HOST}

## Files

- \`genesis.json\` - CometBFT genesis configuration
- \`el-genesis.json\` - Ethereum execution layer genesis
- \`genesis-alloc.json\` - Genesis account allocations
- \`chain-info.json\` - Network metadata and endpoints
- \`jwt.hex\` - JWT secret for Engine API authentication

## Seeds

### CometBFT P2P
\`\`\`
${COMETBFT_SEED:-<configure manually>}
\`\`\`

### Reth P2P
\`\`\`
${RETH_SEED:-<configure manually>}
\`\`\`

## Run RPC Node with Docker

\`\`\`bash
cd docker/sentry

# Create .env file
cat > .env << EOF
NETWORK=${NETWORK_NAME}
EXTERNAL_IP=\$(curl -s ifconfig.me)
COMETBFT_SEEDS=${COMETBFT_SEED:-}
RETH_BOOTNODES=${RETH_SEED:-}
RPC_HOST=0.0.0.0
EOF

# Create data directories
mkdir -p data/{reth,cometbft,orqusbft,jwt}

# Copy JWT secret
cp ../../networks/${NETWORK_NAME}/jwt.hex data/jwt/

# Initialize CometBFT
docker run --rm -v \$(pwd)/data/cometbft:/cometbft cometbft/cometbft:v0.38.15 init

# Start services
docker compose up -d
\`\`\`

## Generated

- Date: ${CURRENT_DATE}
- Namespace: ${NAMESPACE}
- Release: ${RELEASE_NAME}
README
echo "  -> README.md"

echo ""
echo "========================================="
info "Export complete!"
echo "========================================="
echo ""
echo "Files:"
ls -la "$OUTPUT_DIR"
