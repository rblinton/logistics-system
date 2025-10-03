#!/bin/bash

# AI Session Report Generator
# Generates technical session summary for AI assistant to process

echo "📝 Generating AI Session Report"
echo "=============================="
echo ""

# Generate timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Analyze git changes
echo "## Session Analysis Report - $TIMESTAMP" > .ai_session_report.md
echo "" >> .ai_session_report.md

# Check for uncommitted changes
if git status --porcelain | grep -q .; then
    echo "### Uncommitted Changes:" >> .ai_session_report.md
    git status --short >> .ai_session_report.md
    echo "" >> .ai_session_report.md
fi

# Check recent commits if any
if git log --oneline -5 > /dev/null 2>&1; then
    echo "### Recent Commits:" >> .ai_session_report.md
    git log --oneline -3 >> .ai_session_report.md
    echo "" >> .ai_session_report.md
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
