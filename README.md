# Nomad Setup Guide

Nomad orchestrates the CARE application and its dependencies in a development environment.

## Quick Start

### Starting the Nomad Cluster

```bash
./scripts/nomad-up.sh
```

### Stopping the Nomad Cluster

```bash
./scripts/nomad-down.sh
```

### Check Status

```bash
make nomad-status
```

### Accessing the Application

- **Nomad UI**: <http://localhost:4646>
- **Backend API**: <http://localhost:9000>

---

> Note: if you get an error like postgres time out or something related to connections do thism its probably a consul: IP issue

### Check if PostgreSQL service is registered in Consul

```bash
consul catalog services
```

### Check PostgreSQL service details

```bash
consul catalog nodes -service=care-postgres
```

### Check if PostgreSQL is actually running

```bash
sudo systemctl status postgresql
```

### Or if it's in Docker/Nomad

```bash
docker ps | grep postgres
nomad job status care-postgres
```

then get the consul IP and update the [backend](nomad/backend.nomad) file

```py
# Consul services as /etc/hosts entries
extra_hosts = [
    "care-postgres.service.consul:10.78.35.98",  #<- change the ip here
    "care-redis.service.consul:10.78.35.98"
]
```

Same goes for redis too
