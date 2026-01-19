# Troubleshooting Guide

## Common Issues

### Node Not Syncing

**Symptoms:**
- Block height not increasing
- `eth_syncing` returns `false` but block height is behind

**Solutions:**

1. **Check peer connectivity:**
```bash
# CometBFT peers
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# Reth peers
curl -s localhost:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

2. **Verify seed nodes are configured:**
```bash
# Check CometBFT config
grep "seeds\|persistent_peers" /path/to/cometbft/config/config.toml
```

3. **Check firewall:**
```bash
# Ensure P2P ports are open
sudo ufw status
netstat -tlnp | grep -E "26656|30303"
```

4. **Restart services:**
```bash
docker-compose restart
# or
sudo systemctl restart orqus-reth orqusbft cometbft
```

### CometBFT Connection Refused

**Symptoms:**
```
Error: dial tcp 127.0.0.1:26657: connect: connection refused
```

**Solutions:**

1. **Check if CometBFT is running:**
```bash
docker-compose ps cometbft
# or
systemctl status cometbft
```

2. **Check logs:**
```bash
docker-compose logs cometbft
# or
journalctl -u cometbft -f
```

3. **Verify genesis file:**
```bash
# Ensure genesis.json exists and is valid
cat /path/to/cometbft/config/genesis.json | jq .
```

### Engine API Authentication Failed

**Symptoms:**
```
Error: JWT authentication failed
```

**Solutions:**

1. **Verify JWT secret exists:**
```bash
ls -la /path/to/jwt.hex
cat /path/to/jwt.hex
```

2. **Regenerate JWT secret:**
```bash
openssl rand -hex 32 > /path/to/jwt.hex
```

3. **Ensure same secret is used by both services:**
```bash
# Both orqus-reth and orqusbft must use the same jwt.hex file
```

### Out of Disk Space

**Symptoms:**
- Services crashing
- "No space left on device" errors

**Solutions:**

1. **Check disk usage:**
```bash
df -h
du -sh /var/lib/orqus/*
```

2. **Prune old data (if supported):**
```bash
# CometBFT state sync can help reduce disk usage
# See state sync documentation
```

3. **Expand storage:**
- Increase disk size
- Move data directory to larger disk

### High Memory Usage

**Symptoms:**
- OOM kills
- System slowdown

**Solutions:**

1. **Check memory usage:**
```bash
docker stats
# or
htop
```

2. **Reduce cache sizes:**
```bash
# In reth config, reduce:
# --db.max-open-files
# --db.write-buffer-size
```

3. **Increase system memory or add swap:**
```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## Logs and Debugging

### View Logs

```bash
# Docker Compose
docker-compose logs -f orqus-reth
docker-compose logs -f orqusbft
docker-compose logs -f cometbft

# Systemd
journalctl -u orqus-reth -f
journalctl -u orqusbft -f
journalctl -u cometbft -f
```

### Enable Debug Logging

```bash
# In .env or service config
LOG_LEVEL=debug
```

### Check RPC Health

```bash
# Reth
curl http://localhost:8545/health

# CometBFT
curl http://localhost:26657/health
```

## Getting Help

1. **Check documentation:** https://docs.orqus.network
2. **Search issues:** https://github.com/orqus-chain/orqus-network/issues
3. **Contact support:** support@orqus.network

When reporting issues, please include:
- Node version (docker image tags or binary versions)
- Operating system
- Relevant logs
- Steps to reproduce
