# Clapplications - Claude Code Plugin Marketplace

A marketplace for Claude Code plugins focused on voice communications and utilities.

## Available Plugins

### Echo

Voice mode for Claude Code with SenseVoice STT and Qwen3-TTS.

**Commands:**
- `/echo:up` - Start voice services
- `/echo:down` - Stop voice services
- `/echo:status` - Check service status
- `/echo:clean` - Clean up voice service data

**MCP Configurations:**
- voice-mode MCP server integration

### Morpheus

Autonomous skill consolidation modeled on the human sleep cycle. Tracks skill usage, builds pressure over time, and runs N1→N2→N3→REM consolidation cycles that scan past conversations, generate edge-case scenarios, test patches via subagent eval, and propose evidence-backed improvements.

**Commands:**
- `/sleep` - Auto-detect pressure, run appropriate cycle
- `/sleep [skill]` - Target a specific skill
- `/sleep-status` - Pressure gauges for all tracked skills
- `/deep-sleep` - Autonomous overnight mode
- `/nap [skill]` - Quick N1→N2 triage pass
- `/dream [skill]` - Standalone dream session on a skill
- `/snooze` - Defer sleep, accumulate debt

## Using This Marketplace

### Installation

Add this marketplace to your Claude Code configuration:

```bash
/plugin marketplace add <your-github-username>/clapplications
```

Or if using a different Git host:

```bash
/plugin marketplace add https://github.com/<your-github-username>/clapplications.git
```

### Installing Plugins

Once the marketplace is added, install plugins:

```bash
/plugin install echo@clapplications
/plugin install morpheus@clapplications
```

### Local Development

For testing locally before publishing:

```bash
/plugin marketplace add /Users/johnhenry/Projects/clapplications
/plugin install echo@clapplications
```

## For Plugin Developers

### Directory Structure

```
clapplications/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
└── plugins/
    ├── echo/
    │   ├── .claude-plugin/
    │   │   └── plugin.json     # Plugin manifest
    │   ├── commands/           # Plugin commands
    │   ├── scripts/            # Plugin scripts
    │   └── mcp.json           # MCP configuration
    └── morpheus/
        ├── .claude-plugin/
        │   └── plugin.json     # Plugin manifest
        ├── skills/             # Sleep cycle skills
        ├── hooks/              # Hook definitions
        └── scripts/            # State tracker
```

### Adding New Plugins

1. Create a new directory under `plugins/`
2. Add `.claude-plugin/plugin.json` with plugin metadata
3. Add your plugin commands in the `commands/` directory
4. Update `.claude-plugin/marketplace.json` to include your plugin
5. Test with `/plugin validate .`

### Validation

Before committing changes, validate the marketplace:

```bash
/plugin validate .
```

## Distribution

This marketplace can be distributed via:
- **GitHub** (recommended): Users add with `/plugin marketplace add owner/repo`
- **GitLab/Bitbucket**: Users add with full URL
- **Local**: For development and testing

## Team Configuration

Add to `.claude/settings.json` for automatic marketplace configuration:

```json
{
  "extraKnownMarketplaces": {
    "clapplications": {
      "source": {
        "source": "github",
        "repo": "<your-username>/clapplications"
      }
    }
  },
  "enabledPlugins": {
    "echo@clapplications": true,
    "morpheus@clapplications": true
  }
}
```

## License

See individual plugin directories for license information.
