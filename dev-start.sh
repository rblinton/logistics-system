#!/bin/bash

# Logistics System - Development Session Starter
# Run this at the start of any session: ./dev-start.sh
# This script verifies environment, starts services, and prepares for development

echo "🚀 Logistics System - Development Session Starter"
echo "================================================="
echo ""

# Check for existing session from another machine
if [ -f .session_start ]; then
    LAST_SESSION_START=$(cat .session_start)
    LAST_SESSION_MACHINE=$(cat .session_machine 2>/dev/null || echo "unknown")
    LAST_SESSION_USER=$(cat .session_user 2>/dev/null || echo "unknown")
    
    if [ "$LAST_SESSION_MACHINE" != "$(hostname)" ]; then
        echo "⚠️  Previous session detected from different machine:"
        echo "   Started: $LAST_SESSION_START on $LAST_SESSION_USER"
        echo "   Continuing on: $(whoami)@$(hostname)"
    else
        echo "🔄 Continuing previous session from $LAST_SESSION_START"
    fi
    echo ""
fi

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

# Save session start info for dev-stop.sh and multi-machine continuity
echo "$(date '+%Y-%m-%d %H:%M:%S')" > .session_start
echo "$(hostname)" > .session_machine
echo "$(whoami)@$(hostname)" > .session_user

echo "🎯 Development Environment Ready!"
echo "===================================="
echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Quick commands:"
echo "  dotnet test                         # Run all tests"
echo "  dotnet run --project src/LogisticsSystem.Api  # Start API (https://localhost:7158)"
echo "  ./update-progress.sh               # Generate session report for AI"
echo "  ./dev-stop.sh                      # Save work and end session (AI tracks progress)"
echo ""
echo "Documentation:"
echo "  cat docs/DEVELOPMENT_GUIDE.md      # Development workflow"
echo "  cat PROGRESS_LOG.md                # Current progress and next steps"
echo "  cat docs/LOGISTICS_IMPLEMENTATION.md  # Complete system design"
