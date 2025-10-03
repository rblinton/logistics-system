#!/bin/bash

# AI Session Report Generator
# Generates technical session summary for AI assistant to process

echo "📝 Generating AI Session Report"
echo "=============================="
echo ""

# Generate timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create or update session report (incremental)
if [ ! -f .ai_session_report.md ]; then
    # First call - create new report
    echo "## Session Analysis Report - Started $TIMESTAMP" > .ai_session_report.md
    echo "" >> .ai_session_report.md
    echo "### Session Progress:" >> .ai_session_report.md
fi

# Add timestamped progress entry
echo "" >> .ai_session_report.md
echo "#### Progress Check - $TIMESTAMP" >> .ai_session_report.md

# Check for NEW uncommitted changes since last check
CURRENT_CHANGES=$(git status --porcelain | sort)
if [ -f .ai_last_changes ]; then
    LAST_CHANGES=$(cat .ai_last_changes)
else
    LAST_CHANGES=""
fi

if [ "$CURRENT_CHANGES" != "$LAST_CHANGES" ]; then
    if [ -n "$CURRENT_CHANGES" ]; then
        echo "**New/Modified Files:**" >> .ai_session_report.md
        echo '```' >> .ai_session_report.md
        echo "$CURRENT_CHANGES" >> .ai_session_report.md
        echo '```' >> .ai_session_report.md
    fi
    # Save current state for next comparison
    echo "$CURRENT_CHANGES" > .ai_last_changes
else
    echo "**Files:** No new changes since last check" >> .ai_session_report.md
fi

# Check for NEW commits since last check
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")
if [ -f .ai_last_commit ]; then
    LAST_COMMIT=$(cat .ai_last_commit)
else
    LAST_COMMIT="none"
fi

if [ "$CURRENT_COMMIT" != "$LAST_COMMIT" ] && [ "$CURRENT_COMMIT" != "none" ]; then
    echo "**New Commits:**" >> .ai_session_report.md
    echo '```' >> .ai_session_report.md
    git log --oneline "$LAST_COMMIT"..HEAD 2>/dev/null || git log --oneline -1 >> .ai_session_report.md
    echo '```' >> .ai_session_report.md
    echo "$CURRENT_COMMIT" > .ai_last_commit
elif [ "$CURRENT_COMMIT" = "none" ]; then
    echo "**Commits:** No repository found" >> .ai_session_report.md
else
    echo "**Commits:** No new commits since last check" >> .ai_session_report.md
fi

# Test status
echo "### Test Status:" >> .ai_session_report.md
if dotnet test --no-build --verbosity quiet > /dev/null 2>&1; then
    TEST_COUNT=$(dotnet test --no-build --verbosity quiet 2>&1 | grep -o "total: [0-9]*" | grep -o "[0-9]*" | head -1)
    echo "- Tests passing: $TEST_COUNT" >> .ai_session_report.md
else
    echo "- Tests: FAILING" >> .ai_session_report.md
fi

# Build status
if dotnet build --no-restore > /dev/null 2>&1; then
    echo "- Build: SUCCESS" >> .ai_session_report.md
else
    echo "- Build: FAILED" >> .ai_session_report.md
fi
echo "" >> .ai_session_report.md

# Service status
echo "### Service Status:" >> .ai_session_report.md
if docker ps | grep -q tigerbeetle; then
    echo "- TigerBeetle: Running" >> .ai_session_report.md
else
    echo "- TigerBeetle: Stopped" >> .ai_session_report.md
fi
echo "" >> .ai_session_report.md

echo "✅ Session report generated in .ai_session_report.md"
echo "💡 AI assistant can now provide intelligent progress updates"
echo "    based on technical analysis rather than manual input"
