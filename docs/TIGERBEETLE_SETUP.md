# TigerBeetle Database Setup Summary

**Date**: October 3, 2025  
**System**: Arch Linux  
**TigerBeetle Version**: 0.16.60  

## Overview

Successfully set up TigerBeetle high-performance accounting database using Docker and created a .NET client application for testing and development.

## What is TigerBeetle?

TigerBeetle is a high-performance accounting database designed specifically for financial applications. It provides:
- ACID guarantees for financial transactions
- Double-entry bookkeeping enforcement
- High throughput and low latency
- Built-in financial safety checks
- Multi-currency support

## Setup Components

### 1. Docker Installation ✅

- **Container Name**: `tigerbeetle`
- **Image**: `ghcr.io/tigerbeetle/tigerbeetle:0.16.60`
- **Port**: `3000` (mapped to host)
- **Data Directory**: `~/tigerbeetle-data/`
- **Database File**: `~/tigerbeetle-data/0_0.tigerbeetle` (1.1GB)
- **Cluster ID**: `0` (development/testing only)

### 2. .NET Client Application ✅

- **Project**: `TigerBeetleDemo` (Console App)
- **Framework**: .NET 9.0
- **Package**: `tigerbeetle` version `0.16.60`
- **Location**: `~/tigerbeetle-dotnet/`

## Docker Commands

### Essential Commands
```bash
# Check container status
docker ps

# View logs
docker logs tigerbeetle

# Stop the database
docker stop tigerbeetle

# Start the database
docker start tigerbeetle

# Remove container (keeps data persistent)
docker rm tigerbeetle
```

### Restart from Scratch
```bash
# Stop and remove container
docker stop tigerbeetle && docker rm tigerbeetle

# Format new database
docker run --rm --privileged -v ~/tigerbeetle-data:/data ghcr.io/tigerbeetle/tigerbeetle:0.16.60 format --cluster=0 --replica=0 --replica-count=1 /data/0_0.tigerbeetle

# Start new container
docker run -d --name tigerbeetle --privileged -p 3000:3000 -v ~/tigerbeetle-data:/data ghcr.io/tigerbeetle/tigerbeetle:0.16.60 start --addresses=0.0.0.0:3000 /data/0_0.tigerbeetle
```

## .NET Project Details

### Project Structure
```
~/tigerbeetle-dotnet/
├── Program.cs              # Demo application
├── TigerBeetleDemo.csproj  # Project file with package reference
├── bin/                    # Build output
└── obj/                    # Build intermediate files
```

### Package Reference
```xml
<PackageReference Include="tigerbeetle" Version="0.16.60" />
```

### Running the Demo
```bash
cd ~/tigerbeetle-dotnet
dotnet run
```

## Demo Application Features

The demo application demonstrates:

1. **Connection**: Connects to TigerBeetle at `127.0.0.1:3000`
2. **Account Creation**: Creates a simple account with:
   - ID: 1
   - Ledger: 1  
   - Code: 1
   - Flags: None
3. **Account Lookup**: Retrieves and displays account details
4. **Error Handling**: Shows proper exception handling

### Sample Output
```
Connected to TigerBeetle!
Cluster ID: 0
Server: 127.0.0.1:3000
✅ Account created successfully!
✅ Account lookup successful!
   ID: 1
   Ledger: 1
   Code: 1
   Debits: 0
   Credits: 0

🎉 TigerBeetle .NET demo completed!
```

## Network Configuration

- **Server**: Listening on `0.0.0.0:3000`
- **Client Connection**: `127.0.0.1:3000`
- **Protocol**: TigerBeetle native protocol (not HTTP)

Verify connection:
```bash
ss -tlnp | grep 3000
```

## Client Libraries Available

TigerBeetle provides official client libraries for:

- **.NET**: `dotnet add package tigerbeetle --version 0.16.60`
- **Node.js**: `npm install tigerbeetle-node@0.16.60`
- **Python**: `pip install tigerbeetle==0.16.60`
- **Go**: `go mod edit -require github.com/tigerbeetle/tigerbeetle-go@v0.16.60`
- **Java**: Update `pom.xml` with `com.tigerbeetle.tigerbeetle-java` version `0.16.60`

## Key Notes

### Security Warnings
- **Cluster ID 0**: Reserved for testing/benchmarking only - do not use in production
- **Privileged Container**: Required for io_uring support in Docker

### Performance
- **Database Size**: Pre-allocated 1.1GB file
- **Memory**: ~3.3GB allocated during startup
- **Cache**: 1024MB grid cache, 128MB LSM-tree manifests

### Compatibility
- **Client Compatibility**: Clients must be same version or older than server
- **Oldest Supported**: Client version 0.16.4
- **Oldest Upgradable**: Replica version 0.16.56

## Container Management

### Restart Behavior After Reboot

**Current Setup**: The container will **NOT** automatically restart after system reboots.

- **Restart Policy**: `no` (default)
- **Data Safety**: ✅ Data persists in `~/tigerbeetle-data/` 
- **Manual Start Required**: Run `docker start tigerbeetle` after reboot

Check restart policy:
```bash
docker inspect tigerbeetle --format='{{.HostConfig.RestartPolicy.Name}}'
```

#### Auto-Restart Setup (Optional)
To make the container restart automatically:
```bash
# Stop and remove current container
docker stop tigerbeetle && docker rm tigerbeetle

# Recreate with auto-restart policy
docker run -d --name tigerbeetle \
  --restart unless-stopped \
  --privileged \
  -p 3000:3000 \
  -v ~/tigerbeetle-data:/data \
  ghcr.io/tigerbeetle/tigerbeetle:0.16.60 \
  start --addresses=0.0.0.0:3000 /data/0_0.tigerbeetle
```

**Restart Policy Options**:
- `--restart no` (current) - Never restart
- `--restart unless-stopped` - Always restart unless manually stopped
- `--restart always` - Always restart (even if manually stopped)
- `--restart on-failure` - Only restart on error exit codes

### Safe Shutdown

**✅ Yes, it's completely safe to stop the TigerBeetle container**

TigerBeetle is designed as an ACID-compliant database that handles shutdowns gracefully.

#### Preferred Method (Graceful)
```bash
docker stop tigerbeetle
```
- Sends SIGTERM for graceful shutdown
- Waits 10 seconds for clean shutdown
- Allows active transactions to complete
- Flushes buffers and closes files properly

#### Emergency Method (If Unresponsive)
```bash
docker kill tigerbeetle
```
- Immediately sends SIGKILL
- Only use if container is unresponsive

#### Why It's Safe
1. **ACID Compliance**: All committed transactions are persisted before acknowledgment
2. **Write-Ahead Logging**: Transaction durability guaranteed
3. **Graceful Recovery**: Database recovers cleanly on next start
4. **Orderly Shutdown**: Logs show "orderly shutdown" when clients disconnect
5. **Persistent Data**: Host filesystem storage survives container stops

#### What Happens During Stop
- Active transactions complete or are safely rolled back
- Memory buffers are flushed to disk
- Files are properly closed
- Next startup recovers from last committed state

## Troubleshooting

### Common Issues

1. **io_uring Permission Denied**
   - Solution: Use `--privileged` flag with Docker

2. **Connection Refused**
   - Check if container is running: `docker ps`
   - Check logs: `docker logs tigerbeetle`
   - Verify port binding: `ss -tlnp | grep 3000`

3. **Account Creation Errors**
   - Ensure unique account IDs
   - Check account properties are valid
   - Review TigerBeetle documentation for business logic rules

## Next Steps

1. **Explore Transfers**: Create transfers between accounts
2. **Business Logic**: Implement account codes and ledgers properly
3. **Production Setup**: Use proper cluster IDs and multi-replica setup
4. **Monitoring**: Set up logging and monitoring for production use
5. **Security**: Implement proper authentication and network security

## Resources

- **Documentation**: https://docs.tigerbeetle.com/
- **GitHub**: https://github.com/tigerbeetle/tigerbeetle
- **Docker Hub**: https://github.com/tigerbeetle/tigerbeetle/pkgs/container/tigerbeetle
- **Releases**: https://github.com/tigerbeetle/tigerbeetle/releases

---

**Setup completed successfully on October 3, 2025**  
**Environment**: Arch Linux with Docker and .NET 9.0