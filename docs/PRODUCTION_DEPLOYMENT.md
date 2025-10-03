# TigerBeetle Production Deployment Guide

> **Complete workflow for deploying TigerBeetle and .NET applications to production**

Created: October 3, 2025  
Environment: Arch Linux with Docker  
TigerBeetle Version: 0.16.60  
.NET Version: 9.0  

---

## 🚀 **Production Deployment Workflow**

### **Phase 1: Pre-Production Planning**

#### **1.1 Infrastructure Requirements**

**Hardware Sizing (Moderate Load)**
```bash
# Minimum Production Specs
- CPU: 8+ cores (TigerBeetle is CPU-intensive)
- RAM: 16GB+ (for caching and performance)
- Storage: NVMe SSD (for low-latency disk I/O)
- Network: Low-latency networking between replicas
```

**Architecture Components**
- **Replicas**: 3+ nodes for high availability
- **Load Balancer**: HAProxy/Nginx for .NET applications
- **Monitoring**: Prometheus + Grafana stack
- **Logging**: Centralized logging (ELK/Loki)
- **Networking**: Private VPC/VLAN for cluster communication

#### **1.2 Pre-Deployment Checklist**
- [ ] Infrastructure provisioned
- [ ] Network security configured
- [ ] SSL certificates obtained
- [ ] Monitoring stack deployed
- [ ] Backup storage configured
- [ ] DNS records prepared
- [ ] Load testing environment ready

---

### **Phase 2: TigerBeetle Production Setup**

#### **2.1 Generate Production Cluster ID**

**⚠️ CRITICAL: Never use cluster=0 in production!**

```bash
# Generate proper random cluster ID
docker run --rm -v /production/data/replica0:/data \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 format \
  --replica=0 --replica-count=3 \
  /data/cluster_0.tigerbeetle

# Note: Cluster ID is automatically generated and logged
```

#### **2.2 Multi-Replica Cluster Setup**

**High Availability Configuration (3 Replicas)**

```bash
# Production data directories
mkdir -p /production/data/{replica0,replica1,replica2}
mkdir -p /production/logs

# Format Replica 0 (Primary)
docker run --rm -v /production/data/replica0:/data \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 format \
  --replica=0 --replica-count=3 \
  /data/cluster_0.tigerbeetle

# Format Replica 1 (Secondary)
docker run --rm -v /production/data/replica1:/data \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 format \
  --replica=1 --replica-count=3 \
  /data/cluster_1.tigerbeetle

# Format Replica 2 (Secondary)
docker run --rm -v /production/data/replica2:/data \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 format \
  --replica=2 --replica-count=3 \
  /data/cluster_2.tigerbeetle
```

#### **2.3 Production Container Configuration**

```bash
# Production TigerBeetle Replica 0
docker run -d --name tigerbeetle-prod-0 \
  --restart unless-stopped \
  --privileged \
  -p 3000:3000 \
  -v /production/data/replica0:/data \
  -v /production/logs:/logs \
  --memory=8g \
  --cpus=4 \
  --network=tigerbeetle-cluster \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 \
  start --addresses=10.0.1.10:3000,10.0.1.11:3001,10.0.1.12:3002 \
  /data/cluster_0.tigerbeetle

# Production TigerBeetle Replica 1
docker run -d --name tigerbeetle-prod-1 \
  --restart unless-stopped \
  --privileged \
  -p 3001:3001 \
  -v /production/data/replica1:/data \
  -v /production/logs:/logs \
  --memory=8g \
  --cpus=4 \
  --network=tigerbeetle-cluster \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 \
  start --addresses=10.0.1.10:3000,10.0.1.11:3001,10.0.1.12:3002 \
  /data/cluster_1.tigerbeetle

# Production TigerBeetle Replica 2
docker run -d --name tigerbeetle-prod-2 \
  --restart unless-stopped \
  --privileged \
  -p 3002:3002 \
  -v /production/data/replica2:/data \
  -v /production/logs:/logs \
  --memory=8g \
  --cpus=4 \
  --network=tigerbeetle-cluster \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 \
  start --addresses=10.0.1.10:3000,10.0.1.11:3001,10.0.1.12:3002 \
  /data/cluster_2.tigerbeetle
```

---

### **Phase 3: .NET Application Production Setup**

#### **3.1 Production Configuration**

**appsettings.Production.json**
```json
{
  "TigerBeetle": {
    "ClusterAddresses": [
      "10.0.1.10:3000",
      "10.0.1.11:3001", 
      "10.0.1.12:3002"
    ],
    "ConnectionTimeout": "30s",
    "MaxRetries": 3,
    "RetryBackoffMs": 100
  },
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "TigerBeetle": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "yourdomain.com"
}
```

#### **3.2 Service Registration & Health Checks**

**Program.cs (Production Setup)**
```csharp
var builder = WebApplication.CreateBuilder(args);

// TigerBeetle client configuration
builder.Services.AddSingleton<TigerBeetleClient>(provider => 
{
    var config = provider.GetRequiredService<IConfiguration>();
    var addresses = config.GetSection("TigerBeetle:ClusterAddresses")
        .Get<string[]>() ?? throw new InvalidOperationException("TigerBeetle addresses not configured");
    
    return new TigerBeetleClient(addresses);
});

// Health checks
builder.Services.AddHealthChecks()
    .AddCheck<TigerBeetleHealthCheck>("tigerbeetle")
    .AddCheck("self", () => HealthCheckResult.Healthy("Application is running"));

// Production services
builder.Services.AddScoped<IAccountService, AccountService>();
builder.Services.AddScoped<ITransferService, TransferService>();

var app = builder.Build();

// Health check endpoints
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false
});

app.Run();
```

#### **3.3 Production Dockerfile**

```dockerfile
# Multi-stage production build
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Create non-root user
RUN addgroup --system --gid 1001 dotnet \
    && adduser --system --uid 1001 --ingroup dotnet dotnet
USER dotnet

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["YourApp.csproj", "."]
RUN dotnet restore "YourApp.csproj"

# Copy source and build
COPY . .
RUN dotnet build "YourApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "YourApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["dotnet", "YourApp.dll"]
```

#### **3.4 TigerBeetle Health Check Implementation**

```csharp
public class TigerBeetleHealthCheck : IHealthCheck
{
    private readonly TigerBeetleClient _client;
    private readonly ILogger<TigerBeetleHealthCheck> _logger;
    
    public TigerBeetleHealthCheck(TigerBeetleClient client, ILogger<TigerBeetleHealthCheck> logger)
    {
        _client = client;
        _logger = logger;
    }
    
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, 
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Test connectivity with non-existent account lookup
            var testAccountId = UInt128.MaxValue;
            var results = await _client.LookupAccountsAsync(new[] { testAccountId });
            
            // Should return empty result (account doesn't exist)
            if (results.Length == 0)
            {
                return HealthCheckResult.Healthy("TigerBeetle cluster is responsive");
            }
            
            return HealthCheckResult.Degraded("TigerBeetle returned unexpected data");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "TigerBeetle health check failed");
            return HealthCheckResult.Unhealthy("TigerBeetle connection failed", ex);
        }
    }
}
```

---

### **Phase 4: Security & Networking**

#### **4.1 Network Security**

```bash
# Create isolated Docker network
docker network create --driver bridge \
  --subnet=172.20.0.0/16 \
  --ip-range=172.20.240.0/20 \
  tigerbeetle-cluster

# Production firewall rules (iptables/ufw)
# Allow TigerBeetle cluster communication
ufw allow from 10.0.1.0/24 to any port 3000:3002

# Allow application access to TigerBeetle
ufw allow from 10.0.2.0/24 to any port 3000:3002

# Deny external access to TigerBeetle ports
ufw deny 3000:3002

# Allow HTTP/HTTPS for applications
ufw allow 80
ufw allow 443
```

#### **4.2 SSL/TLS Configuration**

**Note**: TigerBeetle doesn't have built-in TLS. Use network-level security:

```yaml
# nginx.conf - TLS termination for .NET apps
server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /etc/ssl/certs/yourdomain.pem;
    ssl_certificate_key /etc/ssl/private/yourdomain.key;
    
    location / {
        proxy_pass http://dotnet-app-cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        proxy_pass http://dotnet-app-cluster/health;
        access_log off;
    }
}

upstream dotnet-app-cluster {
    server 10.0.2.10:80;
    server 10.0.2.11:80;
    server 10.0.2.12:80;
}
```

---

### **Phase 5: Monitoring & Observability**

#### **5.1 Prometheus Configuration**

**prometheus.yml**
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'dotnet-apps'
    static_configs:
      - targets: ['10.0.2.10:80', '10.0.2.11:80', '10.0.2.12:80']
    metrics_path: '/metrics'
    
  - job_name: 'tigerbeetle-health'
    static_configs:
      - targets: ['10.0.2.10:80', '10.0.2.11:80', '10.0.2.12:80']
    metrics_path: '/health'
```

#### **5.2 Monitoring Stack**

**docker-compose.monitoring.yml**
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-prod
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-prod
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
```

#### **5.3 Log Management**

**Centralized Logging with Loki**
```yaml
# docker-compose.logging.yml
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki
    restart: unless-stopped

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log:ro
      - /production/logs:/production/logs:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    restart: unless-stopped

volumes:
  loki-data:
```

---

### **Phase 6: Backup & Disaster Recovery**

#### **6.1 Automated Backup Strategy**

**backup-tigerbeetle.sh**
```bash
#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_DIR="/backups/tigerbeetle"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$DATE"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo "Starting TigerBeetle backup at $(date)"

# Stop all replicas for consistent backup
echo "Stopping TigerBeetle replicas..."
docker stop tigerbeetle-prod-0 tigerbeetle-prod-1 tigerbeetle-prod-2

# Create backup
echo "Creating backup..."
cp -r /production/data/* "$BACKUP_PATH/"

# Restart replicas in order
echo "Restarting TigerBeetle replicas..."
docker start tigerbeetle-prod-0
sleep 10
docker start tigerbeetle-prod-1
sleep 10
docker start tigerbeetle-prod-2

# Compress backup
echo "Compressing backup..."
tar -czf "$BACKUP_PATH.tar.gz" "$BACKUP_PATH"
rm -rf "$BACKUP_PATH"

# Cleanup old backups
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Verify backup
if [ -f "$BACKUP_PATH.tar.gz" ]; then
    echo "Backup completed successfully: $BACKUP_PATH.tar.gz"
    echo "Backup size: $(du -h "$BACKUP_PATH.tar.gz" | cut -f1)"
else
    echo "ERROR: Backup failed!"
    exit 1
fi

echo "Backup completed at $(date)"
```

**Crontab entry for daily backups**
```bash
# Daily backup at 2 AM
0 2 * * * /production/scripts/backup-tigerbeetle.sh >> /var/log/tigerbeetle-backup.log 2>&1
```

#### **6.2 Disaster Recovery Procedure**

**disaster-recovery.md**
```markdown
# TigerBeetle Disaster Recovery Procedure

## Emergency Response Steps

### 1. Assessment
- [ ] Identify scope of failure (single replica, cluster, or complete system)
- [ ] Determine data integrity status
- [ ] Estimate downtime window

### 2. Infrastructure Recovery
- [ ] Provision new infrastructure if needed
- [ ] Restore network connectivity
- [ ] Configure security groups/firewalls

### 3. Data Recovery
- [ ] Locate latest valid backup
- [ ] Extract backup files
- [ ] Verify backup integrity

### 4. TigerBeetle Recovery
- [ ] Restore data files to production directories
- [ ] Start replica 0 (primary) first
- [ ] Wait for primary to become ready
- [ ] Start replica 1, wait for sync
- [ ] Start replica 2, wait for sync
- [ ] Verify cluster health

### 5. Application Recovery
- [ ] Deploy .NET applications
- [ ] Run health checks
- [ ] Execute integration tests
- [ ] Verify application functionality

### 6. DNS/Traffic Switch
- [ ] Update DNS records
- [ ] Configure load balancer
- [ ] Monitor traffic and errors

### 7. Post-Recovery
- [ ] Full system verification
- [ ] Performance monitoring
- [ ] Incident post-mortem
```

---

### **Phase 7: CI/CD Pipeline**

#### **7.1 GitHub Actions Workflow**

**.github/workflows/deploy-production.yml**
```yaml
name: Deploy to Production

on:
  push:
    tags: 
      - 'v*'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  TIGERBEETLE_VERSION: "0.16.60"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '9.0.x'
          
      - name: Run tests
        run: |
          dotnet restore
          dotnet test --configuration Release --verbosity minimal

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Deploy to Production
        run: |
          echo "Deploying ${{ needs.build.outputs.image-tag }} to production"
          # Add your deployment scripts here
          # Example: Ansible playbook, kubectl apply, etc.
```

#### **7.2 Rolling Deployment Strategy**

**deploy-production.sh**
```bash
#!/bin/bash
set -euo pipefail

NEW_IMAGE=$1
HEALTH_CHECK_URL="http://localhost/health"

echo "Starting rolling deployment of $NEW_IMAGE"

# Deploy to each instance with health checks
for instance in prod-app-1 prod-app-2 prod-app-3; do
    echo "Deploying to $instance"
    
    # Pull new image
    docker pull "$NEW_IMAGE"
    
    # Stop old container
    docker stop "$instance" || true
    docker rm "$instance" || true
    
    # Start new container
    docker run -d --name "$instance" \
        --restart unless-stopped \
        -p 80:80 \
        --network app-network \
        "$NEW_IMAGE"
    
    # Wait for health check
    echo "Waiting for $instance to be healthy..."
    for i in {1..30}; do
        if curl -f "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
            echo "$instance is healthy"
            break
        fi
        
        if [ $i -eq 30 ]; then
            echo "ERROR: $instance failed health check"
            exit 1
        fi
        
        sleep 10
    done
    
    sleep 30  # Allow traffic to distribute
done

echo "Rolling deployment completed successfully"
```

---

### **Phase 8: Go-Live Checklist**

#### **8.1 Pre-Launch Verification**

**Technical Checklist**
- [ ] All TigerBeetle replicas healthy and in sync
- [ ] Load testing completed with production traffic patterns
- [ ] Backup/restore procedures tested successfully
- [ ] Monitoring dashboards configured and alerting
- [ ] Security audit completed and vulnerabilities addressed
- [ ] Performance benchmarks meet SLA requirements
- [ ] SSL certificates installed and verified
- [ ] DNS records configured correctly
- [ ] Disaster recovery plan tested

**Operational Checklist**
- [ ] On-call rotation established
- [ ] Runbook documentation complete
- [ ] Team trained on production procedures
- [ ] Rollback plan documented and tested
- [ ] Customer communication plan ready
- [ ] Success metrics defined

#### **8.2 Launch Day Execution**

```bash
# Pre-launch health verification
curl -f http://your-app/health/ready || exit 1
curl -f http://your-app/health/live || exit 1

# Check TigerBeetle cluster status
docker logs tigerbeetle-prod-0 --tail 50
docker logs tigerbeetle-prod-1 --tail 50  
docker logs tigerbeetle-prod-2 --tail 50

# Monitor key metrics during launch
# - Response times
# - Error rates
# - TigerBeetle transaction throughput
# - Database connections
# - Resource utilization

# Switch traffic (example with AWS ALB)
aws elbv2 modify-target-group --target-group-arn $PROD_TG_ARN

# Monitor for 30 minutes post-launch
# Be ready to execute rollback if needed
```

---

### **Phase 9: Post-Production Operations**

#### **9.1 Daily Operations**

**Daily Checklist**
- [ ] Verify backup completion
- [ ] Check cluster health status
- [ ] Review error logs and alerts
- [ ] Monitor performance metrics
- [ ] Verify security scans

**Weekly Operations**
- [ ] Performance trend analysis
- [ ] Capacity planning review
- [ ] Security update assessment
- [ ] Disaster recovery drill (monthly)

#### **9.2 Monitoring & Alerting**

**Critical Alerts**
```yaml
# Grafana alert rules
groups:
  - name: tigerbeetle-critical
    rules:
      - alert: TigerBeetleClusterDown
        expr: up{job="tigerbeetle-health"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "TigerBeetle cluster is down"
          
      - alert: HighTransactionLatency
        expr: tigerbeetle_transaction_duration_seconds > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High transaction latency detected"
```

#### **9.3 Scaling Considerations**

**Horizontal Scaling (.NET Apps)**
```bash
# Add more application instances
docker run -d --name prod-app-4 \
    --restart unless-stopped \
    -p 80:80 \
    --network app-network \
    your-app:latest

# Update load balancer configuration
```

**Vertical Scaling (TigerBeetle)**
```bash
# Stop and recreate with more resources
docker stop tigerbeetle-prod-0
docker rm tigerbeetle-prod-0

docker run -d --name tigerbeetle-prod-0 \
  --restart unless-stopped \
  --privileged \
  -p 3000:3000 \
  -v /production/data/replica0:/data \
  --memory=16g \    # Increased from 8g
  --cpus=8 \        # Increased from 4
  --network=tigerbeetle-cluster \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 \
  start --addresses=10.0.1.10:3000,10.0.1.11:3001,10.0.1.12:3002 \
  /data/cluster_0.tigerbeetle
```

---

## 📊 **Production vs Development Comparison**

| Aspect | Development | Production |
|--------|-------------|------------|
| **Cluster ID** | `0` (testing) | Random UUID |
| **Replicas** | 1 | 3+ (HA) |
| **Restart Policy** | `no` | `unless-stopped` |
| **Resource Limits** | Unlimited | `--memory`, `--cpus` |
| **Network** | Bridge | Private/VPN |
| **Storage** | Host bind mount | Persistent volumes |
| **Monitoring** | Basic logs | Full observability |
| **Backups** | None | Automated daily |
| **Security** | Open ports | Firewall + TLS |
| **Health Checks** | None | Multiple endpoints |
| **Load Balancer** | None | HAProxy/Nginx |
| **SSL/TLS** | None | Required |

---

## ⚠️ **Critical Production Warnings**

1. **Never use cluster=0 in production** - It's reserved for testing
2. **Always use multiple replicas** - Single points of failure are unacceptable
3. **Implement proper backups** - Data loss is not recoverable
4. **Monitor cluster health** - Consensus failures require immediate attention
5. **Test disaster recovery** - Untested backups are worthless
6. **Secure network traffic** - TigerBeetle has no built-in encryption
7. **Resource monitoring** - TigerBeetle is memory and CPU intensive
8. **Version compatibility** - Keep clients and servers compatible

---

## 📚 **Additional Resources**

- [TigerBeetle Official Documentation](https://docs.tigerbeetle.com)
- [TigerBeetle GitHub Repository](https://github.com/tigerbeetle/tigerbeetle)
- [.NET Client Documentation](https://github.com/tigerbeetle/tigerbeetle/tree/main/src/clients/dotnet)
- [Production Deployment Best Practices](https://docs.tigerbeetle.com/deploy)
- [Performance Tuning Guide](https://docs.tigerbeetle.com/performance)

---

*This production deployment guide provides a comprehensive workflow for deploying TigerBeetle with .NET applications in a secure, scalable, and maintainable production environment.*
