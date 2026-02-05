# CARE Platform - Production Nomad Deployment

Production-ready Nomad deployment for the CARE application with PostgreSQL and Redis.

## Quick Start

### Prerequisites
- Nomad >= 1.11.0
- Consul >= 1.18.0
- Docker >= 20.10
- Linux with bridge networking support

### Starting the Deployment

```bash
# Start all services
make nomad-up
# or
./scripts/nomad-up.sh
```

### Stopping the Deployment

```bash
# Stop all services and clean up
make nomad-down
# or
./scripts/nomad-down.sh
```

### Check Status

```bash
# View all jobs
make nomad-status
# or
sudo nomad job status

# View specific job
sudo nomad job status care-backend
sudo nomad job status care-postgres
sudo nomad job status care-redis

# View allocations
sudo nomad job allocs care-backend
```

## Service Access

- **Backend API**: http://localhost:9000 (redirects to HTTPS)
- **PostgreSQL**: localhost:5432 (user: postgres, password: postgres)
- **Redis**: localhost:6379
- **Nomad UI**: http://localhost:4646
- **Consul UI**: http://localhost:8500

## Architecture

```
┌─────────────────────────────────────┐
│         Nomad Cluster               │
├─────────────────────────────────────┤
│  care-backend (Django + Gunicorn)   │
│  care-postgres (PostgreSQL 16)      │
│  care-redis (Redis 8)               │
├─────────────────────────────────────┤
│  Service Discovery (Consul)         │
│  Health Checks & Load Balancing     │
└─────────────────────────────────────┘
```

## Job Specifications

### care-backend
- **Type**: Service
- **CPU**: 800 MHz
- **Memory**: 1024 MB
- **Port**: 9000
- **Health Check**: TCP on port 9000

### care-postgres
- **Type**: Service
- **CPU**: 500 MHz
- **Memory**: 1024 MB
- **Port**: 5432
- **Storage**: Local persistent volume
- **Health Check**: TCP on port 5432

### care-redis
- **Type**: Service
- **CPU**: 250 MHz
- **Memory**: 512 MB
- **Port**: 6379
- **Storage**: Local persistent volume (AOF)
- **Health Check**: TCP on port 6379

## Environment Variables

Backend environment is configured in `nomad/backend.nomad`:
- `DJANGO_SETTINGS_MODULE`: config.settings.production
- `DATABASE_URL`: postgresql://postgres:postgres@localhost:5432/care
- `REDIS_URL`: redis://localhost:6379/0
- `DEBUG`: false
- `ALLOWED_HOSTS`: * (configure for production)

## Logs

View service logs:
```bash
# Get allocation ID
ALLOC_ID=$(sudo nomad job allocs care-backend | grep running | awk '{print $1}')

# View logs
sudo nomad alloc logs $ALLOC_ID
```

## Deployment Status

For detailed deployment status and production checklist, see [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md).

## Troubleshooting

### Service Won't Start
```bash
# Check node resources
sudo nomad node status -verbose

# Check evaluation errors
sudo nomad job status care-backend
```

### Health Check Failing
```bash
# Check Consul service health
curl http://localhost:8500/v1/health/service/care-backend
```

### Database Connection Issues
```bash
# Check if postgres is running
sudo nomad alloc status $(sudo nomad job allocs care-postgres | grep running | head -1 | awk '{print $1}')

# Test connection
nc -zv localhost 5432
```

### Memory Issues
Adjust resource limits in the respective `.nomad` files and redeploy:
```bash
# Edit and redeploy
sudo nomad job run nomad/backend.nomad
```

## Production Deployment Checklist

- [ ] Configure SSL/TLS certificates
- [ ] Set secure database password
- [ ] Set secure Redis password (if needed)
- [ ] Configure proper ALLOWED_HOSTS
- [ ] Enable backup strategy for PostgreSQL
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Set up automated deployment pipeline
- [ ] Configure resource scaling policies
- [ ] Implement disaster recovery plan

## Files

- `nomad/backend.nomad` - Backend API job specification
- `nomad/postgres.nomad` - PostgreSQL job specification
- `nomad/redis.nomad` - Redis job specification
- `scripts/nomad-up.sh` - Deployment startup script
- `scripts/nomad-down.sh` - Deployment cleanup script
- `Makefile` - Convenience commands
- `DEPLOYMENT_STATUS.md` - Detailed deployment status
