#!/bin/bash

# Logistics System - Development Session Stopper
# Run this at the end of any session: ./dev-stop.sh
# This script saves work, commits changes, and prepares for next session

echo "🛑 Logistics System - Development Session Stopper"
echo "=================================================="
echo ""

# Check if we have a session start time
if [ -f .session_start ]; then
    SESSION_START=$(cat .session_start)
    echo "📅 Session started: $SESSION_START"
    echo "📅 Session ending:  $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
fi

# Check current git status
echo "📝 Checking for changes to save:"
if git status --porcelain | grep -q .; then
    echo "✅ Changes found - preparing to commit"
    
    # Show what will be committed
    echo ""
    echo "📋 Files to be committed:"
    git status --short
    echo ""
    
    # Ask for commit message or provide default
    echo "💬 Please provide a commit message (or press Enter for auto-generated):"
    read -r COMMIT_MSG
    
    if [ -z "$COMMIT_MSG" ]; then
        # Generate auto commit message based on changes
        MODIFIED_FILES=$(git status --porcelain | wc -l)
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
        COMMIT_MSG="dev: Development session $TIMESTAMP - $MODIFIED_FILES files modified"
    fi
    
    # Stage and commit all changes
    git add .
    if git commit -m "$COMMIT_MSG"; then
        echo "✅ Changes committed successfully"
    else
        echo "❌ Commit failed"
        exit 1
    fi
else
    echo "ℹ️  No changes to commit"
fi
echo ""

# Push to GitHub
echo "🔄 Pushing to GitHub:"
if git push; then
    echo "✅ Changes pushed to GitHub successfully"
else
    echo "⚠️  Failed to push to GitHub (check connection/permissions)"
fi
echo ""

# Run final build and test to ensure everything still works
echo "🔧 Final verification:"
echo "Building..."
if dotnet build --no-restore > /dev/null 2>&1; then
    echo "✅ Build: SUCCESS"
else
    echo "❌ Build: FAILED - please check before ending session"
    exit 1
fi

echo "Running tests..."
if dotnet test --no-build --verbosity quiet > /dev/null 2>&1; then
    TEST_COUNT=$(dotnet test --no-build --verbosity quiet 2>&1 | grep -o "total: [0-9]*" | grep -o "[0-9]*")
    echo "✅ Tests: $TEST_COUNT passing"
else
    echo "❌ Tests: FAILED - please check before ending session"
fi
echo ""

# Optionally stop TigerBeetle (ask user)
echo "🐅 TigerBeetle Management:"
if docker ps | grep -q tigerbeetle; then
    echo "TigerBeetle container is currently running."
    echo "Stop TigerBeetle container? (y/N):"
    read -r STOP_TIGER
    if [[ $STOP_TIGER =~ ^[Yy]$ ]]; then
        if docker stop tigerbeetle > /dev/null 2>&1; then
            echo "✅ TigerBeetle container stopped"
        else
            echo "⚠️  Failed to stop TigerBeetle container"
        fi
    else
        echo "ℹ️  TigerBeetle container left running"
    fi
else
    echo "ℹ️  TigerBeetle container is not running"
fi
echo ""

# Session summary
echo "📊 Session Summary:"
echo "=================="
if [ -f .session_start ]; then
    echo "Duration: $SESSION_START to $(date '+%Y-%m-%d %H:%M:%S')"
fi
echo "Repository: $(git remote get-url origin 2>/dev/null || echo 'Local only')"
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log --oneline -1)"
echo ""

# Clean up session tracking
rm -f .session_start

echo "🎯 Session completed successfully!"
echo "Next session: Run './dev-start.sh' to resume development"
echo ""

# Optional: Show next development priorities
if [ -f PROGRESS_LOG.md ]; then
    echo "🚧 Next Development Priorities:"
    echo "=============================="
    grep -A 5 "Next Development Phase" PROGRESS_LOG.md | tail -5
fi