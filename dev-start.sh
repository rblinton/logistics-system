#!/bin/bash

# Logistics System - Development Session Starter
# Run this at the start of any session: ./dev-start.sh
# This script verifies environment, starts services, and prepares for development

echo "🚀 Logistics System - Development Session Starter"
echo "================================================="
echo ""

# Pull latest changes from GitHub
echo "🔄 Syncing with GitHub:"
if git pull > /dev/null 2>&1; then
    echo "✅ Repository synchronized with remote"
else
    echo "⚠️  Could not sync with remote (continuing with local)"
fi
echo ""

# Check current directory
echo "📁 Working Directory:"
pwd
echo ""

# Check git status
echo "📝 Git Status:"
git status --short
echo ""
echo "📊 Recent Commits:"
git log --oneline -3
echo ""

# Check if TigerBeetle is running and start if needed
echo "🐅 TigerBeetle Status:"
if docker ps | grep -q tigerbeetle; then
    echo "✅ TigerBeetle container is running"
else
    echo "⚠️  TigerBeetle container is not running - attempting to start..."
    if docker start tigerbeetle > /dev/null 2>&1; then
        echo "✅ TigerBeetle container started successfully"
    else
        echo "❌ Failed to start TigerBeetle container (may need: docker run setup)"
    fi
fi
echo ""

# Build and test status
echo "🔧 Build & Test Status:"
echo "Building..."
if dotnet build --no-restore > /dev/null 2>&1; then
    echo "✅ Build: SUCCESS"
else
    echo "❌ Build: FAILED"
    exit 1
fi

echo "Running tests..."
if dotnet test --no-build --verbosity quiet > /dev/null 2>&1; then
    TEST_COUNT=$(dotnet test --no-build --verbosity quiet 2>&1 | grep -o "total: [0-9]*" | grep -o "[0-9]*")
    echo "✅ Tests: $TEST_COUNT passing"
else
    echo "❌ Tests: FAILED"
fi
echo ""

# Show current progress
echo "📊 Current Progress (from PROGRESS_LOG.md):"
echo "==========================================="
head -20 PROGRESS_LOG.md | tail -15
echo ""

# Save session start time for dev-stop.sh
echo "$(date '+%Y-%m-%d %H:%M:%S')" > .session_start

echo "🎯 Development Environment Ready!"
echo "===================================="
echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Quick commands:"
echo "  dotnet test                         # Run all tests"
echo "  dotnet run --project src/LogisticsSystem.Api  # Start API (https://localhost:7158)"
echo "  ./dev-stop.sh                      # Save work and end session"
echo ""
echo "Documentation:"
echo "  cat docs/DEVELOPMENT_GUIDE.md      # Development workflow"
echo "  cat PROGRESS_LOG.md                # Current progress and next steps"
echo "  cat docs/LOGISTICS_IMPLEMENTATION.md  # Complete system design"
