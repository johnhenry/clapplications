# Clapplications - Claude Code Plugin Marketplace

A marketplace for Claude Code plugins focused on voice communications and utilities.

## Available Plugins

### Claudio

Voice mode for Claude Code with Whisper STT and Chatterbox TTS.

**Commands:**
- `/claudio:up` - Start voice services
- `/claudio:down` - Stop voice services
- `/claudio:status` - Check service status
- `/claudio:clean` - Clean up voice service data

**MCP Configurations:**
- voice-mode MCP server integration

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
/plugin install claudio@clapplications
```

### Local Development

For testing locally before publishing:

```bash
/plugin marketplace add /Users/johnhenry/Projects/clapplications
/plugin install claudio@clapplications
```

## For Plugin Developers

### Directory Structure

```
clapplications/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
└── plugins/
    └── claudio/
        ├── .claude-plugin/
        │   └── plugin.json     # Plugin manifest
        ├── commands/           # Plugin commands
        ├── scripts/            # Plugin scripts
        └── mcp.json           # MCP configuration
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
    "claudio@clapplications": true
  }
}
```

## License

See individual plugin directories for license information.
