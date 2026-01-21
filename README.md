# Converge Skills - Bash Implementation

A bash-based tool for managing modular skills in software projects using git submodules and sparse checkout.

## Overview

Converge Skills allows you to selectively inject skills (reusable components) from multiple repositories into your project, maintaining the ability to contribute changes upstream while keeping a clean, version-controlled skill tree.

## Why SkillSync?

This approach offers several unique technical advantages:
- **Full Git Traceability**: Every skill is linked to its original source repository. This preserves the full history and allows you to commit changes directly back to the upstream source.
- **Interactive Workflow**: Unlike passive "download and copy" approaches, SkillSync uses native Git submodules. You can **propose Pull Requests**, track your own local modifications, and **pull for upstream updates** directly from the skill's source repository.
- **Partial/Sparse Loading**: Using `git sparse-checkout`, the tool materializes only the specific skill files you need. This keeps your project lightweight even when referencing massive multi-skill repositories.
- **Unified Skill Tree**: Combines remote skills (reusable), community skills (shared), and local user skills (private) into a single, clean directory structure.

## Installation

```bash
# Clone this repository
git clone https://github.com/your-org/converge-skills
cd converge-skills

# Make the tool executable
chmod +x skillsync

# Optional: Install git hooks for auto-restoration
chmod +x .git/hooks/post-*
```

## Quick Start (Automatic)

The easiest way to get started is using a GitHub URL:

```bash
# Initialize a new project
mkdir my-agent-project && cd my-agent-project
git init

# Copy skillsync to your root
cp ../converge-skills/skillsync .

# Add a repo via URL - it auto-detects skills and activates them!
./skillsync add https://github.com/vercel-labs/agent-skills

# Add the Anthropic skills repo
./skillsync add https://github.com/anthropics/skills

# Your skills are ready in skills/
ls -la skills/
# ✓ Activated: claude.ai -> ...
# ✓ Activated: react-best-practices -> ...
# ✓ Activated: frontend-design -> ...
```

## Manual Control

For more direct control over naming and paths:

```bash
# Add repo with custom name and specific paths
./skillsync add-repo \
    https://github.com/anthropics/skills \
    anthropics \
    "skills/frontend-design/* skills/algorithmic-art/*"

# Activate specific skills
./skillsync add anthropics frontend-design
./skillsync add vercel react-best-practices

# Add your private skills
mkdir -p skills-user/custom-stripe
echo "# Custom Stripe" > skills-user/custom-stripe/SKILL.md
./skillsync add user custom-stripe

# List active skills
./skillsync list
```

## Directory Structure

After setup, your project will look like:

```
my-agent-project/
├── .gitmodules                    # Submodule config
├── skills-repos/                  # Sparse submodules (pruned)
│   ├── anthropics/                # ONLY materializes used skills
│   │   └── skills/
│   │       └── frontend-design/   # <--- Materialized via sparse-checkout
│   └── vercel-labs/
│       └── skills/
│           └── react-best-practices/
├── skills-user/                   # Your private/custom skills
│   └── my-local-skill/
├── skills/                        # Unified skill tree (symlinks)
│   ├── frontend-design -> ../skills-repos/anthropics/skills/frontend-design/
│   ├── react-best-practices -> ../skills-repos/vercel-labs/skills/react-best-practices/
│   └── my-local-skill -> ../skills-user/my-local-skill/
├── .skillsync/
│   └── active-skills.json         # Tracks which skills are active
└── skillsync                      # The management tool
```

## Commands

### `skillsync add-repo <url> <name> [initial_paths] [branch]`

Add a skill repository as a sparse submodule from a specific branch.

```bash
# Add from default branch (Anthropic)
./skillsync add-repo https://github.com/anthropics/skills anthropic "skills/frontend-design/*"

# Add from specific branch (Vercel)
./skillsync add-repo https://github.com/vercel-labs/agent-skills vercel "skills/react-best-practices/" main

# Add entire skills directory
./skillsync add-repo https://github.com/community/agent-skills community "skills/"
```

### `skillsync remove-repo <name>`

Remove an entire repository and all its associated skills.

```bash
./skillsync remove-repo vercel
```

### `skillsync add <source> <path> [id]`

Activate a skill from a repository or user directory.

```bash
./skillsync add anthropic frontend-design
./skillsync add vercel react-best-practices
./skillsync add user custom-stripe my-stripe-skill
```

### `skillsync remove <id>`

Deactivate a skill.

```bash
./skillsync remove saas-multitenancy
```

### `skillsync list`

List all active skills.

```bash
./skillsync list
```

### `skillsync restore`

Restore symlinks from saved configuration (useful after cloning).

```bash
./skillsync restore
```

## Contributing Changes Upstream

The sparse checkout approach allows you to contribute changes back to upstream repositories:

```bash
# Make changes to a skill
cd skills/saas-multitenancy
nano SKILL.md

# Commit from the submodule
cd ../../skills-repos/base
git add skills/saas-multitenancy/SKILL.md
git commit -m "feat: add connection pooling example"
git push fork HEAD:feature/pooling
```

## Team Collaboration

When teammates clone your project:

```bash
git clone <your-repo>
cd <your-repo>

# Initialize sparse submodules
git submodule update --init --recursive

# Restore skill symlinks
./skillsync restore
```

The included git hooks automatically restore symlinks after checkout or merge operations, ensuring your `skills/` directory stays in sync.

## Dependencies

- `git` (with sparse checkout support)
- `jq` (for JSON processing)
- `bash`

## Benefits

- **Maximum storage efficiency**: Downloads only specific skills, not entire repositories
- **Branch support**: Track skills from any git branch (main, develop, install, etc.)
- **Upstream contribution**: Full git workflow for contributing back
- **Version control**: Everything tracked in git
- **Team collaboration**: Configuration shared via git
- **Clean separation**: Skills injected via symlinks, not copied
- **Repository lifecycle management**: Add and remove entire skill repositories

## Advanced Usage

### Custom Skill Sources

You can add any git repository as a skill source:

```bash
./skillsync add-repo https://github.com/your-org/private-skills private
./skillsync add private custom-skill
```

### Sparse Checkout Management

The tool automatically manages sparse checkout patterns as you add/remove skills. You can manually adjust them if needed:

```bash
cd skills-repos/base
git sparse-checkout add "skills/new-skill/*"
git checkout HEAD
```

### Configuration File

Skills configuration is stored in `.skillsync/active-skills.json`:

```json
[
  {
    "id": "postgres-patterns",
    "source": "base",
    "path": "postgres-patterns"
  },
  {
    "id": "custom-stripe",
    "source": "user",
    "path": "custom-stripe"
  }
]
