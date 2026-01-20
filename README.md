# Converge Skills - Bash Implementation

A bash-based tool for managing modular skills in software projects using git submodules and sparse checkout.

## Overview

Converge Skills allows you to selectively inject skills (reusable components) from multiple repositories into your project, maintaining the ability to contribute changes upstream while keeping a clean, version-controlled skill tree.

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

## Quick Start

```bash
# Setup new project
mkdir my-agent-project
cd my-agent-project
git init

# Copy the skillsync tool
cp ../converge-skills/skillsync .
chmod +x skillsync

# Add skill repositories as sparse submodules
./skillsync add-repo \
    https://github.com/base-org/agent-skills \
    base \
    "skills/postgres-patterns/* skills/saas-multitenancy/*"

./skillsync add-repo \
    https://github.com/community/agent-skills \
    community \
    "skills/auth-flows/*"

# Activate specific skills
./skillsync add base postgres-patterns
./skillsync add base saas-multitenancy
./skillsync add community auth-flows

# Add user-specific skill
mkdir -p skills-user/custom-stripe
echo "# Custom Stripe Skill" > skills-user/custom-stripe/SKILL.md
./skillsync add user custom-stripe

# List active skills
./skillsync list

# Your agent loads from skills-active/
ls -la skills-active/
```

## Directory Structure

After setup, your project will look like:

```
my-agent-project/
├── .gitmodules                    # submodule config
├── skills-repos/                  # sparse submodules (pruned)
│   ├── base/                      # submodule, sparse checkout
│   │   └── skills/
│   │       ├── saas-multitenancy/
│   │       └── postgres-patterns/
│   └── community/                 # submodule, sparse checkout
│       └── skills/
│           └── auth-flows/
├── skills-user/                   # your custom skills
│   └── custom-stripe/
├── skills-active/                 # working directory with symlinks
│   ├── saas-multitenancy -> ../skills-repos/base/skills/saas-multitenancy/
│   ├── postgres-patterns -> ../skills-repos/base/skills/postgres-patterns/
│   ├── auth-flows -> ../community/skills/auth-flows/
│   └── custom-stripe -> ../skills-user/custom-stripe/
├── .skillsync/
│   └── active-skills.json         # tracks which skills are active
└── skillsync                      # the management tool
```

## Commands

### `skillsync add-repo <url> <name> [initial_paths] [branch]`

Add a skill repository as a sparse submodule from a specific branch.

```bash
# Add from default branch
./skillsync add-repo https://github.com/base-org/skills base "skills/postgres-patterns/*"

# Add from specific branch
./skillsync add-repo https://github.com/vercel-labs/agent-skills vercel "skills/react-best-practices/" install

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
./skillsync add base saas-multitenancy
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
cd skills-active/saas-multitenancy
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

## Git Hooks

The included git hooks automatically restore symlinks after checkout or merge operations, ensuring your `skills-active/` directory stays in sync.

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
