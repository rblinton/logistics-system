#!/bin/bash

# Quick Progress Update Script
# Use during development sessions to quickly log accomplishments
# without ending the session

echo "📝 Quick Progress Update"
echo "======================="
echo ""
echo "What did you just accomplish? (Enter items, press Enter twice when done):"
echo "Examples:"
echo "  - Implemented LoadLifecycleService interface"
echo "  - Added 5 unit tests for ID generation"
echo "  - Fixed build issue with TigerBeetle integration"
echo ""

ACCOMPLISHMENTS=""
while true; do
    read -r ITEM
    if [ -z "$ITEM" ]; then
        break
    fi
    if [ -n "$ACCOMPLISHMENTS" ]; then
        ACCOMPLISHMENTS="$ACCOMPLISHMENTS\n- $ITEM"
    else
        ACCOMPLISHMENTS="- $ITEM"
    fi
done

if [ -n "$ACCOMPLISHMENTS" ]; then
    # Update the timestamp in PROGRESS_LOG.md
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M')
    sed -i "s/Updated: [0-9\\-]* [0-9:]*/Updated: $CURRENT_DATE/g" PROGRESS_LOG.md
    
    # Add to session notes section
    SESSION_DATE=$(date '+%Y-%m-%d')
    SESSION_ENTRY="\n**$SESSION_DATE**: Progress update $(date '+%H:%M')\n$ACCOMPLISHMENTS"
    
    # Find the line with "Recent Session Notes" and add after it
    awk -v entry="$SESSION_ENTRY" '
    /### 📅 \*\*Recent Session Notes\*\*/ {
        print
        getline
        print
        print entry
        next
    }
    {print}
    ' PROGRESS_LOG.md > PROGRESS_LOG.md.tmp && mv PROGRESS_LOG.md.tmp PROGRESS_LOG.md
    
    echo "✅ Progress updated in PROGRESS_LOG.md"
    echo "📊 Current session accomplishments:"
    echo -e "$ACCOMPLISHMENTS"
    echo ""
    echo "💡 Continue developing, or run './dev-stop.sh' when ready to end session"
else
    echo "ℹ️  No progress items entered"
fi