# Contributing to Kortix OCX Registry

## Overview

This registry contains skills and tools that extend Kortix AI Agent capabilities. Contributions are welcome!

## How to Contribute

### Adding a New Skill

1. **Fork** this repository
2. **Create** a new skill directory: `skills/skill-<name>/`
3. **Add** `SKILL.md` with the skill definition (see format below)
4. **Update** `registry.json` with the new skill entry
5. **Submit** a Pull Request

### Skill Format

Each skill needs a `SKILL.md` file with frontmatter:

```markdown
---
name: skill-name
description: "Clear description of when to trigger this skill..."
allowed-tools: Tool(tool-name:*)
---

# Skill Name

Your skill documentation here...
```

### Adding a New Tool

1. **Add** your tool file to `tools/<tool-name>.ts`
2. **Update** `registry.json` with the tool entry
3. **Submit** a Pull Request

### Tool Format

Tools should follow the OpenCode tool specification with proper TypeScript types.

## Registry Index

When adding new skills or tools, update `registry.json`:

```json
{
  "skills": [
    {
      "name": "skill-<name>",
      "displayName": "Display Name",
      "description": "Brief description",
      "author": "your-username",
      "tags": ["tag1", "tag2"],
      "path": "skills/skill-<name>"
    }
  ],
  "tools": [
    {
      "name": "tool-name",
      "description": "Tool description",
      "path": "tools/tool-name.ts"
    }
  ]
}
```

## Review Process

1. PR submitted
2. Automated checks run
3. Maintainer reviews
4. Feedback/approvals
5. Merge & publish

## Future: Namespace Ownership

Coming soon: Contributors will be able to own namespaces (e.g., `@username/skill-xyz`) for self-maintained skills.

---

For questions, open an issue or join our community.
