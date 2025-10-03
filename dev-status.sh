#!/bin/bash

# Logistics System - Development Session Status Check
# Run this at the start of any session: ./dev-status.sh

echo "🚀 Logistics System - Session Status Check"
echo "=========================================="
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

# Check if TigerBeetle is running
echo "🐅 TigerBeetle Status:"
if docker ps | grep -q tigerbeetle; then
    echo "✅ TigerBeetle container is running"
else
    echo "⚠️  TigerBeetle container is not running (run: docker start tigerbeetle)"
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

echo "🎯 Ready for development!"
echo ""
echo "Quick commands:"
echo "  dotnet test                    # Run all tests"
echo "  dotnet run --project src/LogisticsSystem.Api  # Start API"
echo "  cat docs/DEVELOPMENT_GUIDE.md # View development guide"
echo "  cat PROGRESS_LOG.md           # View full progress log"