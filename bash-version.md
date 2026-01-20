Absolutely yes - a bash implementation would be significantly easier for this use case, especially on Linux-only. Here's why:
Why Bash is Better Here

1. Zero runtime dependencies: Git + bash + jq are already on every Linux system

2. Native git operations: No subprocess overhead - you're just calling git directly

3. Symlink handling is trivial: ln -sf vs managing async filesystem APIs

4. Simpler mental model: Shell scripts are designed exactly for this kind of file/git orchestration
Concrete Implementation
Core Tool: skillsync (single bash script)

bash
#!/bin/bash
set -euo pipefail

SKILLS_ACTIVE="skills-active"
SKILLS_REPOS="skills-repos"
SKILLS_USER="skills-user"
CONFIG=".skillsync/active-skills.json"

# Initialize config directory
mkdir -p .skillsync

# Add sparse submodule
add_sparse_submodule() {
    local url=$1
    local name=$2
    local initial_paths=${3:-}
    
    echo "Adding sparse submodule: $name"
    
    # Add as submodule with no checkout
    git submodule add --depth=1 --no-checkout "$url" "$SKILLS_REPOS/$name"
    
    # Configure sparse checkout
    cd "$SKILLS_REPOS/$name"
    git sparse-checkout init --cone
    git config core.sparseCheckout true
    
    if [ -n "$initial_paths" ]; then
        git sparse-checkout set $initial_paths
    fi
    
    git checkout
    cd ../..
    
    # Save to .gitmodules metadata
    git config -f .gitmodules "submodule.$SKILLS_REPOS/$name.sparse" "true"
    git config -f .gitmodules "submodule.$SKILLS_REPOS/$name.sparse-checkout" "$initial_paths"
}

# Activate skills (create symlinks)
activate_skills() {
    local skills_json=$1
    
    # Create/clear active directory
    mkdir -p "$SKILLS_ACTIVE"
    
    # Remove old symlinks
    find "$SKILLS_ACTIVE" -type l -delete
    
    # Parse JSON and create symlinks
    echo "$skills_json" | jq -r '.[] | "\(.id)|\(.source)|\(.path)"' | while IFS='|' read -r id source path; do
        local target
        case "$source" in
            user)
                target="../$SKILLS_USER/$path"
                ;;
            *)
                target="../$SKILLS_REPOS/$source/skills/$path"
                ;;
        esac
        
        if [ -d "${target#../}" ]; then
            ln -sf "$target" "$SKILLS_ACTIVE/$id"
            echo "✓ Activated: $id → $target"
        else
            echo "⚠ Warning: $target not found, skipping $id"
        fi
    done
    
    # Save config
    echo "$skills_json" | jq '.' > "$CONFIG"
}

# Add skill to sparse checkout and activate
add_skill() {
    local source=$1
    local skill_path=$2
    local skill_id=${3:-$(basename "$skill_path")}
    
    # Update sparse checkout
    if [ "$source" != "user" ]; then
        cd "$SKILLS_REPOS/$source"
        git sparse-checkout add "skills/$skill_path/*"
        git checkout HEAD  # materialize files
        cd ../..
        
        # Update .gitmodules
        local current=$(git config -f .gitmodules "submodule.$SKILLS_REPOS/$source.sparse-checkout" || echo "")
        git config -f .gitmodules "submodule.$SKILLS_REPOS/$source.sparse-checkout" "$current skills/$skill_path/*"
    fi
    
    # Add to config
    local new_skill=$(jq -n \
        --arg id "$skill_id" \
        --arg source "$source" \
        --arg path "$skill_path" \
        '{id: $id, source: $source, path: $path}')
    
    if [ -f "$CONFIG" ]; then
        local updated=$(jq --argjson new "$new_skill" '. + [$new]' "$CONFIG")
    else
        local updated="[$new_skill]"
    fi
    
    activate_skills "$updated"
}

# Remove skill
remove_skill() {
    local skill_id=$1
    
    # Remove from config
    local updated=$(jq --arg id "$skill_id" 'map(select(.id != $id))' "$CONFIG")
    
    # Remove symlink
    rm -f "$SKILLS_ACTIVE/$skill_id"
    
    echo "$updated" | jq '.' > "$CONFIG"
    echo "✗ Deactivated: $skill_id"
}

# List active skills
list_skills() {
    if [ -f "$CONFIG" ]; then
        jq -r '.[] | "\(.id)\t(\(.source):\(.path))"' "$CONFIG"
    else
        echo "No skills activated yet"
    fi
}

# Restore from config (for post-clone/post-checkout)
restore() {
    if [ ! -f "$CONFIG" ]; then
        echo "No saved configuration found"
        exit 1
    fi
    
    local skills=$(cat "$CONFIG")
    activate_skills "$skills"
}

# Main command dispatcher
case "${1:-}" in
    add-repo)
        add_sparse_submodule "$2" "$3" "${4:-}"
        ;;
    add)
        add_skill "$2" "$3" "${4:-}"
        ;;
    remove)
        remove_skill "$2"
        ;;
    list)
        list_skills
        ;;
    restore)
        restore
        ;;
    *)
        cat << 'EOF'
Usage: skillsync <command> [args]

Commands:
  add-repo <url> <name> [initial_paths]   Add sparse submodule
  add <source> <path> [id]                Activate skill
  remove <id>                             Deactivate skill
  list                                    List active skills
  restore                                 Restore symlinks from config

Examples:
  skillsync add-repo https://github.com/base-org/skills base "skills/postgres-patterns/*"
  skillsync add base saas-multitenancy
  skillsync add user custom-stripe
  skillsync list
  skillsync remove saas-multitenancy
  skillsync restore
EOF
        ;;
esac

Git Hooks (auto-restore symlinks)

bash
#!/bin/bash
# .git/hooks/post-checkout

# Restore symlinks after checkout/submodule update
if [ -f .skillsync/active-skills.json ]; then
    ./skillsync restore
fi

bash
#!/bin/bash
# .git/hooks/post-merge

# Restore after merge (in case config changed)
if [ -f .skillsync/active-skills.json ]; then
    ./skillsync restore
fi

Make hooks executable:

bash
chmod +x .git/hooks/post-{checkout,merge}

Usage Examples

bash
# Setup new project
git init my-agent-project
cd my-agent-project
curl -o skillsync https://raw.githubusercontent.com/you/skillsync/main/skillsync
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

# List active
./skillsync list
# Output:
# postgres-patterns     (base:postgres-patterns)
# saas-multitenancy     (base:saas-multitenancy)
# auth-flows            (community:auth-flows)
# custom-stripe         (user:custom-stripe)

# Your agent loads from skills-active/
ls -la skills-active/
# postgres-patterns -> ../skills-repos/base/skills/postgres-patterns
# saas-multitenancy -> ../skills-repos/base/skills/saas-multitenancy
# auth-flows -> ../skills-repos/community/skills/auth-flows
# custom-stripe -> ../skills-user/custom-stripe

# Make changes to upstream skill
cd skills-repos/base
git checkout -b feature/improve-multitenancy
nano skills/saas-multitenancy/SKILL.md
git add skills/saas-multitenancy/SKILL.md
git commit -m "feat: add RLS examples"
git push fork feature/improve-multitenancy
cd ../..

# Teammate clones
git clone <your-repo>
git submodule update --init --recursive
./skillsync restore  # recreates symlinks

# Or make it automatic with post-checkout hook