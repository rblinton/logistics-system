#!/bin/bash

# Logistics System - Development Session Starter
# Run this at the start of any session: ./dev-start.sh
# This script verifies environment, starts services, and prepares for development
# 
# Options:
#   --force-pull    Force git pull even with uncommitted changes (stashes first)

# Parse command line options
FORCE_PULL=false
if [ "$1" = "--force-pull" ]; then
    FORCE_PULL=true
fi

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

# Smart sync with GitHub - check for uncommitted changes first
echo "🔄 Syncing with GitHub:"
if git diff --quiet && git diff --cached --quiet; then
    # No uncommitted changes, safe to pull
    PULL_OUTPUT=$(git pull 2>&1)
    if [ $? -eq 0 ]; then
        if echo "$PULL_OUTPUT" | grep -q "Already up to date"; then
            echo "✅ Repository up to date"
        else
            echo "✅ Repository synchronized - new changes pulled"
        fi
    else
        echo "⚠️  Could not sync with remote (continuing with local)"
    fi
elif [ "$FORCE_PULL" = true ]; then
    # Force pull requested - stash changes first
    echo "💾 Force pull requested - stashing uncommitted changes..."
    git stash push -m "dev-start.sh auto-stash $(date '+%Y-%m-%d %H:%M:%S')"
    PULL_OUTPUT=$(git pull 2>&1)
    if [ $? -eq 0 ]; then
        echo "✅ Repository synchronized - changes stashed"
        echo "   Use 'git stash pop' to restore your changes"
    else
        echo "⚠️  Pull failed even after stashing"
    fi
else
    echo "⚠️  Uncommitted changes detected - skipping pull to avoid conflicts"
    echo "   Options: commit changes, or run './dev-start.sh --force-pull' to stash & pull"
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

# Initialize AI session tracking (clean working files, preserve context)
rm -f .ai_session_report.md .ai_last_changes .ai_last_commit
if [ -f .ai_session_context.md ]; then
    echo "🤖 AI session context preserved from previous machine"
else
    echo "🤖 AI session tracking initialized (fresh start)"
fi

echo "🎯 Development Environment Ready!"
echo "===================================="
echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Quick commands:"
echo "  dotnet test                         # Run all tests"
echo "  # API project will be developed in future phases"
echo "  ./update-progress.sh               # Generate session report for AI"
echo "  ./dev-stop.sh                      # Save work and end session (AI tracks progress)"
echo ""
echo "Documentation:"
echo "  cat docs/DEVELOPMENT_GUIDE.md      # Development workflow"
echo "  cat PROGRESS_LOG.md                # Current progress and next steps"
echo "  cat docs/LOGISTICS_IMPLEMENTATION.md  # Complete system design"
