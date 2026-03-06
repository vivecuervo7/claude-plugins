#!/bin/bash
# Forces background agent permission requests to surface in the foreground conversation.
# Without this, background agents silently auto-deny all tool permissions.
# See: https://github.com/anthropics/claude-code/issues/18172
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Journal worker requesting tool access"}}'
