# Architecture Diagrams

Visual representations of the N8N deployment architecture, data flows, and operational processes.

## Table of Contents

- [Network Architecture](#network-architecture)
- [Request Flow Diagram](#request-flow-diagram)
- [Deployment Flow](#deployment-flow)
- [Health Check Architecture](#health-check-architecture)
- [Security Architecture](#security-architecture)
- [Data Flow Architecture](#data-flow-architecture)
- [Ollama Integration Flow](#ollama-integration-flow)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
- [Cost Optimization Model](#cost-optimization-model)
- [Scaling Scenarios](#scaling-scenarios)

## Network Architecture

```mermaid
graph TB
    subgraph "Internet"
        User[👤 User]
        GitHub[🐙 GitHub Actions]
    end
    
    subgraph "Cloudflare"
        CF_DNS[DNS Resolution]
        CF_Access[Access Control]
        CF_Tunnel[Tunnel Service]
    end
    
    subgraph "Personal PC"
        Ollama[🤖 Ollama<br/>RTX 5080<br/>gpt-oss:20b]
    end
    
    subgraph "AWS ca-central-1"
        subgraph "ALB"
            LB[Application Load Balancer<br/>n8n-alb]
        end
        
        subgraph "EC2 Instance (t3.small)"
            subgraph "Security Groups"
                SG_ALB[alb-sg]
                SG_N8N[n8n-sg]
            end
            
            subgraph "Docker Containers"
                Nginx[🌐 Nginx<br/>Port 80]
                N8N[⚡ N8N<br/>Port 5678]
                Postgres[🗄️ PostgreSQL<br/>Port 5432]
            end
        end
        
        subgraph "Storage"
            EBS1[n8n-server-ssd<br/>20GiB]
            EBS2[n8n-runtime-data<br/>2GiB]
            Vol1[pg_data volume]
            Vol2[n8n_data volume]
        end
        
        subgraph "AWS Services"
            S3[S3 Bucket<br/>Deploy Artifacts]
            SSM[Parameter Store<br/>Secrets]
            CW[CloudWatch<br/>Logs]
            Backup[EBS Snapshots<br/>Daily Backups]
        end
    end
    
    User -->|HTTPS| CF_DNS
    CF_DNS --> CF_Access
    CF_Access -->|Authorized| LB
    LB -->|HTTP| Nginx
    Nginx -->|Proxy| N8N
    N8N -->|DB Connection| Postgres
    
    Ollama -.->|Tunnel| CF_Tunnel
    CF_Tunnel -.->|llm.zvonkos.com| CF_DNS
    N8N -.->|AI Requests| CF_Tunnel
    
    GitHub -->|Deploy| S3
    GitHub -->|SSM Commands| EC2
    
    Postgres --> Vol1
    N8N --> Vol2
    Vol1 --> EBS2
    Vol2 --> EBS1
    
    EBS1 --> Backup
    EBS2 --> Backup
    
    N8N --> SSM
    EC2 --> CW
```

## Request Flow Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant CF as Cloudflare
    participant ALB as AWS ALB
    participant NGX as Nginx
    participant N8N as N8N App
    participant PG as PostgreSQL
    participant OL as Ollama (PC)
    
    U->>CF: 1. HTTPS Request to n8n.zvonkos.com
    CF->>CF: 2. DNS Resolution
    CF->>CF: 3. Access Control Check
    CF->>ALB: 4. Forward to ALB
    ALB->>ALB: 5. SSL Termination
    ALB->>NGX: 6. HTTP to Nginx (port 80)
    NGX->>N8N: 7. Proxy to N8N (port 5678)
    
    alt Workflow needs data
        N8N->>PG: 8a. Database Query
        PG-->>N8N: 8b. Return Data
    end
    
    alt Workflow uses AI
        N8N->>CF: 9a. AI Request to llm.zvonkos.com
        CF->>OL: 9b. Tunnel to Ollama
        OL-->>CF: 9c. AI Response
        CF-->>N8N: 9d. Return Response
    end
    
    N8N-->>NGX: 10. Response
    NGX-->>ALB: 11. HTTP Response
    ALB-->>CF: 12. HTTPS Response
    CF-->>U: 13. Final Response
```

## Deployment Flow

```mermaid
flowchart TD
    subgraph "Developer Workflow"
        Dev[👨‍💻 Developer] --> Code[Code Changes]
        Code --> Commit[Git Commit]
        Commit --> Push[Push to main]
    end
    
    subgraph "GitHub Actions"
        Push --> Trigger[Workflow Trigger]
        Trigger --> Build[Build Artifact]
        Build --> Version[Generate Version Info]
        Version --> Package[Create Tarball]
        Package --> Upload[Upload to S3]
    end
    
    subgraph "AWS Deployment"
        Upload --> SSM_Send[Send SSM Command]
        SSM_Send --> EC2_Receive[EC2 Receives Command]
        EC2_Receive --> Download[Download from S3]
        Download --> Extract[Extract Artifact]
        Extract --> Secrets[Fetch Secrets from Parameter Store]
        Secrets --> EnvFile[Generate .env File]
        EnvFile --> Compose[Docker Compose Down/Up]
        Compose --> Health[Health Checks]
    end
    
    subgraph "Verification"
        Health --> NGX_Check[Nginx Health Check]
        NGX_Check --> N8N_Check[N8N Health Check]
        N8N_Check --> Version_Check[Version Endpoint Check]
        Version_Check --> Success[✅ Deployment Success]
    end
    
    subgraph "Monitoring"
        Success --> CW_Logs[CloudWatch Logs]
        Success --> Backup[EBS Snapshots]
    end
    
    style Success fill:#90EE90
    style Health fill:#FFE4B5
    style Secrets fill:#FFB6C1
```

## Health Check Architecture

```mermaid
graph TB
    subgraph "Health Check Layers"
        subgraph "External Checks"
            GHA[GitHub Actions<br/>Post-Deploy Check]
            Monitor[External Monitoring<br/>Future]
        end
        
        subgraph "Load Balancer Level"
            ALB_HC[ALB Target Group<br/>Health Check]
        end
        
        subgraph "Nginx Level"
            NGX_Self[nginx-healthz<br/>Nginx Self Check]
            NGX_Upstream[upstream-health<br/>N8N Proxy Check]
            Version[version<br/>Deployment Version]
        end
        
        subgraph "Container Level"
            N8N_HC[N8N Container<br/>Health Check]
            PG_HC[PostgreSQL<br/>pg_isready Check]
            NGX_HC[Nginx Container<br/>Curl Check]
        end
        
        subgraph "Application Level"
            N8N_API[N8N healthz<br/>Endpoint]
            DB_Conn[Database<br/>Connection Pool]
        end
    end
    
    GHA -->|HTTP GET| Version
    ALB_HC -->|HTTP GET| NGX_Self
    NGX_Upstream --> N8N_API
    N8N_HC --> N8N_API
    N8N_API --> DB_Conn
    PG_HC --> DB_Conn
    
    style NGX_Self fill:#90EE90
    style N8N_API fill:#87CEEB
    style DB_Conn fill:#DDA0DD
```

## Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Edge Security"
            CF_DDoS[Cloudflare DDoS Protection]
            CF_WAF[Web Application Firewall]
            CF_Access[Cloudflare Access<br/>Authentication]
        end
        
        subgraph "Network Security"
            ALB_SG[ALB Security Group<br/>Port 443 from Internet]
            EC2_SG[EC2 Security Group<br/>Port 80 from ALB only]
            VPC[Default VPC<br/>Network Isolation]
        end
        
        subgraph "Application Security"
            SSL_Term[SSL Termination<br/>at ALB]
            Nginx_Proxy[Nginx Reverse Proxy<br/>Request Filtering]
            N8N_Auth[N8N Authentication<br/>User Management]
        end
        
        subgraph "Data Security"
            SSM_Encrypt[Parameter Store<br/>Encrypted Secrets]
            EBS_Encrypt[EBS Volume<br/>Encryption at Rest]
            Backup_Encrypt[Backup Encryption<br/>AWS Managed Keys]
        end
        
        subgraph "Access Control"
            IAM_Deploy[IAM Role<br/>GitHub Deploy]
            IAM_SSM[IAM Role<br/>SSM Access]
            EC2_Profile[Instance Profile<br/>Least Privilege]
        end
    end
    
    Internet[🌐 Internet] --> CF_DDoS
    CF_DDoS --> CF_WAF
    CF_WAF --> CF_Access
    CF_Access --> ALB_SG
    ALB_SG --> SSL_Term
    SSL_Term --> EC2_SG
    EC2_SG --> Nginx_Proxy
    Nginx_Proxy --> N8N_Auth
    
    N8N_Auth --> SSM_Encrypt
    SSM_Encrypt --> EBS_Encrypt
    EBS_Encrypt --> Backup_Encrypt
    
    IAM_Deploy --> SSM_Encrypt
    IAM_SSM --> EC2_Profile
    
    style CF_Access fill:#FFB6C1
    style SSL_Term fill:#90EE90
    style SSM_Encrypt fill:#87CEEB
```

## Data Flow Architecture

```mermaid
graph LR
    subgraph "Data Sources"
        Workflows[N8N Workflows]
        Config[Configuration]
        Logs[Application Logs]
        Metrics[System Metrics]
    end
    
    subgraph "Storage Layer"
        PG_Data[(PostgreSQL<br/>Workflow Data)]
        N8N_Files[N8N Files<br/>/home/node/.n8n]
        Static_Files[Static Files<br/>nginx/html]
    end
    
    subgraph "Persistence Layer"
        EBS_App[EBS Volume<br/>n8n-server-ssd<br/>20GiB]
        EBS_Runtime[EBS Volume<br/>n8n-runtime-data<br/>2GiB]
        Docker_Vols[Docker Volumes<br/>pg_data, n8n_data]
    end
    
    subgraph "Backup Layer"
        Daily_Snap[Daily EBS<br/>Snapshots]
        Retention[Backup<br/>Retention Policy]
    end
    
    subgraph "Monitoring Layer"
        CW_Logs[CloudWatch<br/>Deployment Logs]
        Docker_Logs[Container<br/>Logs]
    end
    
    Workflows --> PG_Data
    Config --> N8N_Files
    Logs --> CW_Logs
    Logs --> Docker_Logs
    
    PG_Data --> Docker_Vols
    N8N_Files --> Docker_Vols
    Static_Files --> Docker_Vols
    
    Docker_Vols --> EBS_App
    Docker_Vols --> EBS_Runtime
    
    EBS_App --> Daily_Snap
    EBS_Runtime --> Daily_Snap
    Daily_Snap --> Retention
    
    style PG_Data fill:#DDA0DD
    style Daily_Snap fill:#90EE90
    style CW_Logs fill:#87CEEB
```

## Ollama Integration Flow

```mermaid
sequenceDiagram
    participant N8N as N8N Workflow
    participant CF as Cloudflare
    participant Tunnel as CF Tunnel
    participant PC as Personal PC
    participant Ollama as Ollama Service
    participant GPU as RTX 5080
    
    Note over N8N,GPU: AI-Powered Workflow Execution
    
    N8N->>CF: 1. HTTP Request to llm.zvonkos.com
    Note right of N8N: No auth headers needed<br/>(EC2 bypass configured)
    
    CF->>CF: 2. Check Access Rules
    Note right of CF: EC2 IP whitelisted<br/>for bypass
    
    CF->>Tunnel: 3. Route via Tunnel
    Tunnel->>PC: 4. Forward to localhost
    PC->>Ollama: 5. API Request
    
    Ollama->>GPU: 6. Load Model (gpt-oss:20b)
    GPU->>GPU: 7. Process with 8k context
    GPU-->>Ollama: 8. Generated Response
    
    Ollama-->>PC: 9. API Response
    PC-->>Tunnel: 10. Return via Tunnel
    Tunnel-->>CF: 11. Back through CF
    CF-->>N8N: 12. Final Response
    
    Note over N8N: 13. Continue workflow<br/>with AI response
    
    rect rgb(255, 248, 220)
        Note over CF,Tunnel: Secure tunnel eliminates<br/>need for port forwarding<br/>or dynamic DNS
    end
    
    rect rgb(240, 248, 255)
        Note over GPU: Local GPU processing<br/>No API costs<br/>Full model control
    end
```

## Disaster Recovery Scenarios

```mermaid
flowchart TD
    subgraph "Failure Scenarios"
        F1[Container Failure]
        F2[EC2 Instance Failure]
        F3[EBS Volume Failure]
        F4[Database Corruption]
        F5[Complete Region Failure]
    end
    
    subgraph "Recovery Mechanisms"
        R1[Docker Health Checks<br/>+ Restart Policy]
        R2[Redeploy to New Instance<br/>+ Attach EBS Volumes]
        R3[Restore from<br/>EBS Snapshots]
        R4[Database Recovery<br/>from Backup]
        R5[Manual Rebuild<br/>in Different Region]
    end
    
    subgraph "Recovery Times"
        T1[< 30 seconds<br/>Automatic]
        T2[5-10 minutes<br/>Semi-automatic]
        T3[10-30 minutes<br/>Manual]
        T4[30-60 minutes<br/>Manual]
        T5[2-4 hours<br/>Manual]
    end
    
    F1 --> R1 --> T1
    F2 --> R2 --> T2
    F3 --> R3 --> T3
    F4 --> R4 --> T4
    F5 --> R5 --> T5
    
    style T1 fill:#90EE90
    style T2 fill:#FFE4B5
    style T3 fill:#FFB6C1
    style T4 fill:#FFA07A
    style T5 fill:#FF6347
```

## Cost Optimization Model

```mermaid
graph TB
    subgraph "Monthly Costs (USD)"
        subgraph "Compute"
            EC2[EC2 t3.small<br/>~$16/month]
            ALB[Application LB<br/>~$16/month]
        end
        
        subgraph "Storage"
            EBS[EBS Volumes<br/>22GB × $0.10<br/>~$2.20/month]
            Snap[EBS Snapshots<br/>~$2-4/month]
            S3[S3 Storage<br/>~$1/month]
        end
        
        subgraph "Network"
            Data[Data Transfer<br/>~$3-6/month]
        end
        
        subgraph "Services"
            SSM[Parameter Store<br/>Free tier]
            CW[CloudWatch<br/>~$1-2/month]
        end
        
        subgraph "External"
            CF[Cloudflare<br/>Free tier]
            Domain[Domain<br/>~$12/year]
        end
    end
    
    subgraph "Total Monthly Cost"
        Total[~$40-45/month<br/>+ $1/month domain]
    end
    
    EC2 --> Total
    ALB --> Total
    EBS --> Total
    Snap --> Total
    S3 --> Total
    Data --> Total
    CW --> Total
    
    style Total fill:#90EE90
    style EC2 fill:#FFE4B5
    style ALB fill:#FFE4B5
```

## Scaling Scenarios

```mermaid
graph TB
    subgraph "Current State"
        C1[Single EC2 Instance<br/>t3.small]
        C2[Single Database<br/>PostgreSQL Container]
        C3[Manual Scaling<br/>Vertical Only]
    end
    
    subgraph "Phase 1: Vertical Scaling"
        P1[Larger EC2 Instance<br/>t3.medium/large]
        P2[More EBS Storage<br/>50-100GB]
        P3[Database Tuning<br/>Connection Pooling]
    end
    
    subgraph "Phase 2: Horizontal Scaling"
        P4[Multiple EC2 Instances<br/>Auto Scaling Group]
        P5[RDS PostgreSQL<br/>Multi-AZ]
        P6[Application Load Balancer<br/>Multiple Targets]
    end
    
    subgraph "Phase 3: Advanced Scaling"
        P7[Container Orchestration<br/>ECS/EKS]
        P8[Database Clustering<br/>Read Replicas]
        P9[Multi-Region<br/>Disaster Recovery]
    end
    
    C1 --> P1
    C2 --> P2
    C3 --> P3
    
    P1 --> P4
    P2 --> P5
    P3 --> P6
    
    P4 --> P7
    P5 --> P8
    P6 --> P9
    
    style C1 fill:#87CEEB
    style P1 fill:#FFE4B5
    style P4 fill:#FFB6C1
    style P7 fill:#DDA0DD
```