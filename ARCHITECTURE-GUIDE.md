# Architecture Guide: Understanding the N8N Deployment

This guide explains the "why" behind each architectural decision in our N8N deployment.

## Table of Contents

- [The Big Picture: What Are We Building?](#the-big-picture-what-are-we-building)
- [Why This Architecture? The Core Problems We're Solving](#why-this-architecture-the-core-problems-were-solving)
- [Component Breakdown: What Each Piece Does](#component-breakdown-what-each-piece-does)
  - [1. Personal PC with Ollama](#1-personal-pc-with-ollama)
  - [2. Cloudflare Tunnel](#2-cloudflare-tunnel)
  - [3. AWS Application Load Balancer (ALB)](#3-aws-application-load-balancer-alb)
  - [4. EC2 Instance (The Main Server)](#4-ec2-instance-the-main-server)
  - [5. Nginx (Reverse Proxy)](#5-nginx-reverse-proxy)
  - [6. N8N Application](#6-n8n-application)
  - [7. PostgreSQL Database](#7-postgresql-database)
- [Security Layers: Defense in Depth](#security-layers-defense-in-depth)
- [Data Flow: Following a Request](#data-flow-following-a-request)
- [Deployment Strategy: How Code Gets to Production](#deployment-strategy-how-code-gets-to-production)
- [Monitoring and Observability](#monitoring-and-observability)
- [Cost Optimization Decisions](#cost-optimization-decisions)
  - [Why Not Kubernetes?](#why-not-kubernetes)
  - [Why Not RDS?](#why-not-rds)
  - [Why Not Serverless?](#why-not-serverless)

## The Big Picture: What Are We Building?

We're building a **workflow automation platform** that can:
- Run automated tasks and integrations 24/7
- Connect to external APIs and services
- Use AI (our personal Ollama instance) for intelligent workflows
- Scale reliably without manual intervention
- Stay secure and accessible from anywhere

## Why This Architecture? The Core Problems We're Solving

### Problem 1: "I want to run workflows 24/7 without my computer being on"
**Solution**: Cloud hosting on AWS EC2
- EC2 gives us a computer that runs 24/7 in the cloud
- We pay only for what we use
- AWS handles the physical infrastructure

### Problem 2: "I want my workflows to use AI, but Cloud APIs are expensive"
**Solution**: Personal Ollama instance + Cloudflare tunnel
- Run our own AI model on a powerful gaming PC (RTX 5080)
- Cloudflare tunnel securely connects our home PC to the cloud
- No API costs, full control over the model

### Problem 3: "I need this to be reliable and not break"
**Solution**: Multiple layers of redundancy and health checks
- Load balancer distributes traffic
- Health checks automatically restart failed services
- Database backups prevent data loss
- Monitoring tells us when something's wrong

## Component Breakdown: What Each Piece Does

### 1. Personal PC with Ollama
**What it is**: Your computer running an AI model
**Why we need it**: 
- Free AI inference (no API costs)
- Full control over model and data
- Powerful GPU (RTX 5080) for fast responses

**Real-world analogy**: Like having your own personal AI assistant that never leaves your house, but can still help with work tasks remotely.

### 2. Cloudflare Tunnel
**What it is**: A secure connection between your home PC and the internet
**Why we need it**:
- Your home PC doesn't have a public IP address
- ISPs block incoming connections for security
- Cloudflare creates a secure "tunnel" through their network

**Real-world analogy**: Like a private phone line between your house and your office that goes through a trusted operator.

### 3. AWS Application Load Balancer (ALB)
**What it is**: The "front door" that receives all web traffic
**Why we need it**:
- Handles SSL certificates (the lock icon in browsers)
- Can distribute traffic to multiple servers (even though we only have one)
- AWS manages it, so it's highly reliable

**Real-world analogy**: Like a receptionist at a company who greets visitors and directs them to the right department.

### 4. EC2 Instance (The Main Server)
**What it is**: A virtual computer running in AWS
**Why we chose t3.small**:
- Cost-effective for our workload
- Can handle N8N + database + web server
- Easy to upgrade if we need more power

**Real-world analogy**: Like renting a small office space - you get what you need without buying a whole building.

### 5. Nginx (Reverse Proxy)
**What it is**: A web server that sits in front of N8N
**Why we need it**:
- N8N isn't designed to handle internet traffic directly
- Nginx is battle-tested for web traffic
- Provides health checks and version endpoints
- Can serve static files efficiently

**Real-world analogy**: Like a security guard who checks visitors before they enter the building and directs them to the right floor.

### 6. N8N Application
**What it is**: The actual workflow automation software
**Why Docker**:
- Consistent environment (works the same everywhere)
- Easy updates and rollbacks
- Isolated from the host system

**Real-world analogy**: Like having your application in a shipping container - it works the same whether it's on a truck, ship, or train.

### 7. PostgreSQL Database
**What it is**: Where N8N stores all workflow data
**Why PostgreSQL**:
- Reliable and well-supported by N8N
- ACID compliance (data integrity)
- Good performance for our use case

**Real-world analogy**: Like a filing cabinet that never loses documents and can quickly find what you're looking for.

## Security Layers: Defense in Depth

### Layer 1: Cloudflare Access
- Only authorized users can reach the N8N interface
- Protects against random internet attacks
- Free tier includes basic DDoS protection

### Layer 2: AWS Security Groups
- Firewall rules at the network level
- Only allows specific ports and protocols
- Blocks everything else by default

### Layer 3: Application-Level Security
- N8N has its own user authentication
- Database credentials stored securely in AWS Parameter Store
- No secrets in code or configuration files

## Data Flow: Following a Request

1. **User visits n8n.zvonkos.com**
2. **Cloudflare** checks if user is authorized
3. **AWS ALB** receives the request and terminates SSL
4. **Nginx** on EC2 receives HTTP request from ALB
5. **Nginx** proxies request to N8N container
6. **N8N** processes request, may query PostgreSQL
7. **Response flows back**: N8N → Nginx → ALB → Cloudflare → User

## Deployment Strategy: How Code Gets to Production

### The Problem
- We want to deploy new versions safely
- We need zero-downtime deployments
- We want to be able to rollback quickly

### The Solution: Artifact-Based Deployment
1. **GitHub Actions** builds a deployment package
2. **Package uploaded** to S3 for storage
3. **AWS SSM** runs deployment commands on EC2
4. **Health checks** verify the deployment worked
5. **Rollback available** by deploying previous artifact

## Monitoring and Observability

### Health Check Strategy
- **Nginx health**: Is the web server responding?
- **N8N health**: Is the application working?
- **Database health**: Can we connect to PostgreSQL?
- **Version endpoint**: What version is currently deployed?

### Logging Strategy
- **Application logs**: Docker container logs
- **Deployment logs**: CloudWatch for deployment history
- **System logs**: Standard Linux logs on EC2

## Cost Optimization Decisions

### Why Not Kubernetes?
- **Complexity**: Overkill for a single application
- **Cost**: EKS costs $72/month just for the control plane
- **Maintenance**: Docker Compose is much simpler

### Why Not RDS?
- **Cost**: RDS has additional overhead costs
- **Simplicity**: PostgreSQL in Docker is easier to backup with EBS
- **Control**: Full control over database configuration

### Why Not Serverless?
- **State**: N8N needs persistent connections and state
- **Cost**: Would be more expensive for 24/7 workloads
- **Complexity**: Cold starts would hurt user experience