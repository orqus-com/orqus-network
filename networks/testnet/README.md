# Orqus Testnet

## Network Information

| Property | Value |
|----------|-------|
| Chain ID | `153871` |
| Network ID | `153871` |
| Native Token | ORQUS (ORQ) |
| Block Time | ~2 seconds |
| Consensus | CometBFT |

## RPC Endpoints

```
HTTP:  https://rpc-testnet.orqus.network
WS:    wss://rpc-testnet.orqus.network/ws
```

## Genesis Files

| File | Description |
|------|-------------|
| `cometbft-genesis.json` | CometBFT consensus layer genesis |
| `genesis-alloc.json` | Reth execution layer genesis allocation |
| `chain-info.json` | Network configuration and seed nodes |

## Seed Nodes

### CometBFT P2P (Port 26656)
```
<NODE_ID>@seed1.testnet.orqus.network:26656
```

### Reth P2P (Port 30303)
```
enode://<PUBKEY>@seed1.testnet.orqus.network:30303
```

> Note: Contact Orqus team to get the actual seed node addresses.

## Block Explorer

https://explorer-testnet.orqus.network

## Faucet

https://faucet-testnet.orqus.network
