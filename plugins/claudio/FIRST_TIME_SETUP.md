# First-Time Setup Issue & Solution

## The Problem

When users run `/claudio:up` for the first time, voice conversations don't work immediately. This document explains why and how we've improved the experience.

## Root Cause

The issue stems from how Claude Code loads MCP servers:

1. **MCP servers load only at startup** - They cannot be loaded dynamically while Claude Code is running
2. **Configuration != Loading** - The `/claudio:up` script configures the voice-mode MCP server, but this doesn't make it available in the current session
3. **Silent failure** - Users try to use voice features immediately after setup, but the tools aren't available yet because the MCP server isn't loaded

## The User Experience Problem

### What happened:
1. User runs `/claudio:up` (first time)
2. Script installs Whisper and Chatterbox
3. Script configures voice-mode MCP server
4. Script says "Voice services ready!"
5. User asks: "let's have a voice conversation"
6. **ERROR**: `No such tool available: mcp__voice-mode__converse`
7. User is confused - services are running but voice doesn't work

### Why it happened:
- The voice services (Whisper/Chatterbox) ARE running ✅
- The voice-mode MCP server IS configured ✅
- But the MCP server IS NOT loaded in the current session ❌
- MCP servers only load when Claude Code starts

## The Solution

### Improved UX (This PR)

1. **Clear restart notification** - Prominent message when MCP is first configured:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ⚠️  IMPORTANT: RESTART REQUIRED
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Voice-mode MCP server was just configured.
      You MUST restart Claude Code for it to load.

      Steps:
      1. Exit Claude Code (type /exit or close the application)
      2. Restart Claude Code
      3. Ask Claude: "Let's have a voice conversation"
   ```

2. **New `/claudio:check` command** - Validates complete setup:
   - Checks if STT service is running
   - Checks if TTS service is running
   - Checks if MCP is configured
   - Warns about restart requirement
   - Provides troubleshooting steps

3. **Better ongoing messaging** - Even after first config, reminds about restart:
   ```
   💡 To start a voice conversation, just ask Claude naturally:
      "Let's have a voice conversation"

      Note: If voice tools aren't available, you may need to restart
      Claude Code. MCP servers only load on startup.
   ```

## Technical Details

### Why Can't We Auto-Detect If MCP Is Loaded?

The plugin scripts run in a separate shell process from Claude Code. They have no direct way to:
- Query Claude Code's internal state
- Check if MCP servers are loaded in the current session
- Detect if voice tools are available

The best we can do is:
1. Check if MCP is *configured* (via `claude mcp get voice-mode`)
2. Infer if restart is needed based on whether we just configured it
3. Always remind users about the restart requirement

### Alternative Solutions Considered

1. **Auto-restart Claude Code** - Not possible from plugin scripts
2. **Dynamic MCP loading** - Not supported by Claude Code architecture
3. **Keep polling until tools available** - Can't detect tool availability from shell
4. **Skip MCP entirely** - Would require rewriting entire voice-mode integration

### The Best Solution

**Clear communication** is the only reliable approach:
- Make restart requirement impossible to miss
- Provide easy verification command
- Always remind about restart in status messages

## Testing Verification

To verify the fix works:

1. Clean install:
   ```bash
   /claudio:clean all
   /claudio:up
   ```
   Expected: Clear "RESTART REQUIRED" message

2. Check status:
   ```bash
   /claudio:check
   ```
   Expected: Shows all services running, warns about restart

3. Restart Claude Code and verify:
   ```bash
   # After restart
   "let's have a voice conversation"
   ```
   Expected: Voice conversation starts successfully

## For Future Improvements

If Claude Code adds the ability to:
- Dynamically load MCP servers
- Query MCP server status from plugins
- Provide restart hooks

Then we could improve this further. But for now, clear communication is the best solution.
