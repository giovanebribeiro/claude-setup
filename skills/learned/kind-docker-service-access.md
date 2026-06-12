# Kind Cluster Access to Local Docker Services (Linux)

**Extracted:** 2026-06-12
**Context:** Local dev with kind + any Docker-based service (MongoDB, Redis, etc.) on Linux

## Problem

Kind pods on Linux cannot reach host-bound services via `127.0.0.1` or `host.docker.internal`.
`host.docker.internal` resolves on Docker Desktop (Mac/Windows) but not on Linux kind.
Port-forwarded services (e.g. `0.0.0.0:32768`) are unreachable from pods — iptables blocks the path.

Diagnostic signals:
- `nslookup host.docker.internal` returns NXDOMAIN from inside cluster
- `nc -zv <gateway-ip> <port>` hangs (iptables dropping, not port closed)
- App logs `MongooseServerSelectionError` or equivalent connection error

## Solution

Connect the target container directly to the `kind` Docker network.
Pods reach it container-to-container using the **internal port** (not the host-mapped port).

## Example

```bash
# Connect service container to kind network
docker network connect kind <container-name>

# Get its IP on kind network
IP=$(docker inspect <container-name> \
  --format '{{(index .NetworkSettings.Networks "kind").IPAddress}}')
echo $IP  # e.g. 172.18.0.5

# Use internal port — e.g. 27017 for MongoDB, NOT the host-mapped port (32768)
echo "mongodb://${IP}:27017/?directConnection=true"
```

For MongoDB Atlas CLI local deployment:

```bash
atlas local start dev01
docker network connect kind dev01
ATLAS_IP=$(docker inspect dev01 --format '{{(index .NetworkSettings.Networks "kind").IPAddress}}')
kubectl create secret generic rsk-lgpd-secret \
  --namespace octopus \
  --from-literal=MONGODB_URI="mongodb://${ATLAS_IP}:27017/?directConnection=true" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/<name> -n <namespace>
```

## When to Use

- Any Docker container needs to be reachable from kind pods on Linux
- `host.docker.internal` resolves NXDOMAIN in cluster DNS
- `nc -zv <gateway-ip> <port>` hangs instead of failing immediately
- Service binds to `0.0.0.0:<port>` on host but pods still can't connect

## Notes

- Always use the container's **internal port**, not the host-mapped port
- `docker network connect kind` must be re-run after `atlas local start` restarts the container
- On Mac/Windows Docker Desktop `host.docker.internal` works natively — this pattern is Linux-only
- Get IPv4 gateway (not IPv6): `docker network inspect kind | grep -E '"Gateway": "[0-9]'`
