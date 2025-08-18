# N8N Self-Hosted
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**N8N Platform on AWS**
[![N8N](https://img.shields.io/badge/N8N-Workflow%20Automation-4A90E2)](https://n8n.io/) [![Docker](https://img.shields.io/badge/Docker-N8N%20%7C%20PostgreSQL%20%7C%20Nginx-2496ED)](https://www.docker.com/) [![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20ALB%20%7C%20S3%20%7C%20EBS%20%7C%20SSM%20%7C%20ACM%20%7C%20IAM%20%7C%20CW%20-FF9900)](https://aws.amazon.com/) [![GitHub%20Actions](https://img.shields.io/badge/GitHub%20Actions-Build%20%7C%20Deploy%20%7C%20Test%20-22C55E)](https://github.com/features/actions)
[![Cost](https://img.shields.io/badge/Monthly%20Cost-~$48--50-10B981)](https://github.com/zhorvatic/n8n-self-hosted) 

**Local PC LLM Integration**
[![LLM](https://img.shields.io/badge/LLM-Ollama%20%7C%20gpt--oss:20b%20%7C%20RTX5080%20-4A90E2)](https://ollama.ai/) [![Cloudflare](https://img.shields.io/badge/Cloudflare-%20Zero%20Trust%20Tunnel%20%7C%20DNS%7C%20SSL/TLS-F38020)](https://www.cloudflare.com/) 
[![Cost](https://img.shields.io/badge/Monthly%20AI%20Cost-~$Free-10B981)](https://github.com/zhorvatic/n8n-self-hosted) [![Cost](https://img.shields.io/badge/Savings%20vs%20API-~90%-10B981)](https://github.com/zhorvatic/n8n-self-hosted) [![Cost](https://img.shields.io/badge/Savings%20vs%20Subscriptions-~99%-10B981)](https://github.com/zhorvatic/n8n-self-hosted)

A **production-ready N8N workflow automation platform** that combines enterprise-grade infrastructure with innovative cost optimization through personal AI integration.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Infrastructure Details](#infrastructure-details)
  - [AWS Resources (ca-central-1)](#aws-resources-ca-central-1)
  - [Cloudflare Configuration](#cloudflare-configuration)
- [Services](#services)
  - [N8N Configuration](#n8n-configuration)
  - [PostgreSQL](#postgresql)
  - [Nginx](#nginx)
- [Deployment](#deployment)
  - [Automated Deployment (GitHub Actions)](#automated-deployment-github-actions)
  - [Manual Deployment](#manual-deployment)
  - [Environment Variables](#environment-variables)
- [Health Monitoring](#health-monitoring)
  - [Health Check Endpoints](#health-check-endpoints)
  - [Docker Health Checks](#docker-health-checks)
- [Ollama Integration](#ollama-integration)
  - [Connection Details](#connection-details)
  - [Usage in N8N](#usage-in-n8n)
- [Development Workflow](#development-workflow)
- [Maintenance](#maintenance)
  - [Backup Strategy](#backup-strategy)
  - [Log Access](#log-access)
  - [Updates](#updates)
- [Security](#security)
  - [Access Control](#access-control)
  - [SSL/TLS](#ssltls)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Log Locations](#log-locations)

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Personal PC   │    │   Cloudflare     │    │   AWS EC2       │
│                 │    │                  │    │                 │
│ Ollama (RTX5080)│◄───┤ Tunnel + Access  │◄───┤ N8N + Postgres  │
│ gpt-oss:20b     │    │ llm.zvonkos.com  │    │ n8n.zvonkos.com │
│ 8k context      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components

- **N8N Instance**: Workflow automation platform running in Docker
- **PostgreSQL**: Database for N8N data persistence
- **Nginx**: Reverse proxy with health checks and version endpoint
- **AWS ALB**: Load balancer with SSL termination
- **Cloudflare**: DNS, SSL certificates, and access control
- **Ollama Integration**: Personal LLM accessible via secure tunnel

## Infrastructure Details

### AWS Resources

**EC2 Instance**
- **Name:** `n8n-server`
- **Type:** `t3.small`
- **OS**: Ubuntu 24.04.23
- **Key**: `n8n-ec2`
- **Security Group**: `n8n-sg`

**Storage**
- `n8n-server-ssd`: 20GiB (application data)
- `n8n-runtime-data`: 2GiB (runtime files)

**Load Balancer**
- **ALB:** `n8n-alb`
- **Target Group**: `n8n-version-tg`
- **Security Group**: `alb-sg`

**Backup**
- **Plan**: `n8n-backups`
- **Rule**: `n8n-daily-backups`
- **Resources**: `n8n-ebs-resources` (EBS snapshots)

**IAM Roles**
- `n8n-github-deploy`: GitHub Actions deployment
- `n8n-ssm-access`: EC2 Parameter Store access

**Other Resources**
- **S3 Bucket**: `n8n-deploy-artifacts-ca-central-1`
- **CloudWatch Log Group**: `/aws/ssm/n8n-deploy`
- **SSL Certificate**: `n8n.zvonkos.com`

### Cloudflare Configuration

**DNS Records**
- `n8n.zvonkos.com` → AWS ALB
- `llm.zvonkos.com` → Cloudflared PC Tunnel

## Services

### N8N Configuration
- **Image**: `docker.n8n.io/n8nio/n8n`
- **Port**: 5678 (internal)
- **Protocol**: HTTPS
- **Database**: PostgreSQL

### PostgreSQL
- **Image**: `postgres:15`
- **Database**: Configured via environment variables
- **Storage**: Persistent volume (`pg_data`)

### Nginx
- **Port**: 80 (receives traffic from ALB)
- **Endpoints**:
  - `/` → Proxy to N8N
  - `/version` → Static version info
  - `/nginx-healthz` → Nginx health check
  - `/upstream-health` → N8N health check

## Deployment

### Automated Deployment (GitHub Actions)

Deployments trigger automatically on pushes to `main` branch:

1. **Build**: Creates versioned artifact with commit info
2. **Upload**: Stores artifact in S3 bucket
3. **Deploy**: Uses AWS SSM to deploy on EC2
4. **Verify**: Health check via `/version` endpoint

### Manual Deployment

```bash
# On EC2 instance
cd /opt/n8n/current
./start.sh prod
```

### Environment Variables

Secrets are managed in AWS Parameter Store under `/n8n/prod/`:
- `POSTGRES_DB`
- `POSTGRES_USER` 
- `POSTGRES_PASSWORD`
- `CF_API_TOKEN`
- `CF_ACCESS_CLIENT_ID`
- `CF_ACCESS_CLIENT_SECRET`

## Health Monitoring

### Health Check Endpoints

- **Nginx**: `http://localhost/nginx-healthz`
- **N8N**: `http://localhost/upstream-health`
- **Version**: `https://n8n.zvonkos.com/version`

### Docker Health Checks

All services include health checks with automatic restart policies:
- N8N: HTTP check via internal endpoint
- PostgreSQL: `pg_isready` check
- Nginx: Internal curl check

## Ollama Integration

### Connection Details
- **Endpoint**: `https://llm.zvonkos.com`
- **Model**: `gpt-oss:20b`
- **Context**: 8k tokens
- **Hardware**: RTX 5080
- **Access**: Cloudflare tunnel with EC2 bypass

## Development Workflow

1. **Workflow Development**: Use N8N web interface at `https://n8n.zvonkos.com`
2. **Code Changes**: Push to `main` branch triggers automatic deployment
3. **Monitoring**: Check deployment status in GitHub Actions
4. **Verification**: Confirm deployment via `/version` endpoint

## Maintenance

### Backup Strategy
- **Frequency**: Daily EBS snapshots
- **Retention**: Managed by AWS backup plan
- **Scope**: Both application and runtime data volumes

### Log Access
- **CloudWatch**: `/aws/ssm/n8n-deploy` log group
- **Docker**: `docker compose logs` on EC2 instance

### Updates
- **N8N**: Update image tag in `docker-compose.yml`
- **System**: Standard Ubuntu package management
- **Dependencies**: Managed via Docker images

## Security

### Access Control
- **N8N Interface**: Protected by Cloudflare Access
- **Ollama API**: EC2 bypass, external access requires auth
- **EC2**: Security groups restrict access
- **Secrets**: AWS Parameter Store with IAM controls

### SSL/TLS
- **External**: AWS Certificate Manager + ALB
- **Internal**: HTTP between ALB and Nginx
- **Cloudflare**: Full SSL encryption

## Troubleshooting

### Common Issues

**Deployment Failures**
```bash
# Check SSM logs in CloudWatch
# Review GitHub Actions output
# Verify EC2 instance health
```

**Service Health**
```bash
# Check container status
docker compose --project-name n8n ps

# View service logs
docker compose --project-name n8n logs n8n
```

**Connectivity Issues**
```bash
# Test health endpoints
curl http://localhost/nginx-healthz
curl http://localhost/upstream-health
curl https://n8n.zvonkos.com/version
```

### Log Locations
- **Deployment**: CloudWatch `/aws/ssm/n8n-deploy`
- **Application**: Docker container logs
- **System**: Standard Ubuntu logs (`/var/log/`)


## License and Third-Party Components

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Components

This project uses the following third-party software and services:

- **N8N**: Licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) - Free for personal use
- **PostgreSQL**: Licensed under the [PostgreSQL License](https://www.postgresql.org/about/licence/)
- **Nginx**: Licensed under the [BSD 2-Clause License](http://nginx.org/LICENSE)
- **Docker**: Licensed under the [Apache 2.0 License](https://github.com/docker/docker/blob/master/LICENSE)
- **Ollama**: Licensed under the [MIT License](https://github.com/ollama/ollama/blob/main/LICENSE)

### Cloud Services

This project integrates with commercial cloud services:
- **AWS**: Commercial cloud services (pay-per-use)
- **Cloudflare**: Commercial CDN and security services
- **GitHub**: Version control and CI/CD platform

### Usage Notice

This repository contains configuration and deployment scripts. Users are responsible for:
- Complying with all third-party software licenses
- Understanding costs associated with cloud services
- Ensuring appropriate licensing for their use case (especially N8N's Sustainable Use License)

For commercial use beyond N8N's Sustainable Use License limits, consider N8N's commercial licensing options.