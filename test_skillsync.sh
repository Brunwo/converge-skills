#!/bin/bash
set -euo pipefail

# Unit test for skillsync functionality
# Tests adding vercel/react-best-practices skill

TEST_DIR="/tmp/skillsync_test_$(date +%s)"
SKILLSYNC="./skillsync"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${YELLOW}INFO:${NC} $1"
}

echo_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

echo_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    exit 1
}

# Setup test environment
setup_test() {
    echo_info "Setting up test environment in $TEST_DIR"

    # Get the directory where this script is located
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # Initialize git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Copy skillsync script from the script's directory
    cp "$SCRIPT_DIR/skillsync" .

    # Make it executable
    chmod +x skillsync

    echo_success "Test environment setup complete"
}

# Test adding vercel repo with react-best-practices skill
test_add_vercel_skill() {
    echo_info "Testing addition of vercel/react-best-practices skill"

    # Add the vercel repo with specific skill (using specific commit for test stability)
    ./skillsync add-repo https://github.com/vercel-labs/agent-skills vercel "skills/react-best-practices/" 772252060741749696ce2abcb060c9efed6a5737

    # Check that the repo directory exists
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "skills-repos/vercel directory not created"
    fi

    # Check that it's a git repository
    if [ ! -e "skills-repos/vercel/.git" ]; then
        echo_failure "skills-repos/vercel is not a git repository"
    fi

    # Check that the skills directory exists
    if [ ! -d "skills-repos/vercel/skills" ]; then
        echo_failure "skills-repos/vercel/skills directory not found"
    fi

    # Check that ONLY react-best-practices skill is checked out
    if [ ! -d "skills-repos/vercel/skills/react-best-practices" ]; then
        echo_failure "react-best-practices skill not checked out"
    fi

    # Check that other skills are NOT checked out
    if [ -d "skills-repos/vercel/skills/claude.ai" ]; then
        echo_failure "claude.ai skill should not be checked out (sparse checkout failed)"
    fi

    if [ -d "skills-repos/vercel/skills/web-design-guidelines" ]; then
        echo_failure "web-design-guidelines skill should not be checked out (sparse checkout failed)"
    fi

    # Check that root files are NOT checked out (sparse checkout working)
    if [ -f "skills-repos/vercel/README.md" ]; then
        echo_failure "Root README.md should not be checked out (sparse checkout failed)"
    fi

    if [ -f "skills-repos/vercel/AGENTS.md" ]; then
        echo_failure "Root AGENTS.md should not be checked out (sparse checkout failed)"
    fi

    # Verify the submodule is checked out to the correct commit
    local current_commit=$(cd "skills-repos/vercel" && git rev-parse HEAD)
    if [ "$current_commit" != "772252060741749696ce2abcb060c9efed6a5737" ]; then
        echo_failure "Submodule not checked out to correct commit. Expected: 772252060741749696ce2abcb060c9efed6a5737, Got: $current_commit"
    fi

    echo_success "Vercel repository added with correct sparse checkout and commit"
}

# Test activating the skill
test_activate_skill() {
    echo_info "Testing skill activation"

    # Add the skill
    ./skillsync add vercel react-best-practices

    # Check that skills directory exists
    if [ ! -d "skills" ]; then
        echo_failure "skills directory not created"
    fi

    # Check that the symlink exists
    if [ ! -L "skills/react-best-practices" ]; then
        echo_failure "react-best-practices symlink not created"
    fi

    # Check that the symlink points to the correct location
    local symlink_target=$(readlink "skills/react-best-practices")
    if [ "$symlink_target" != "../skills-repos/vercel/skills/react-best-practices" ]; then
        echo_failure "Symlink points to wrong location: $symlink_target"
    fi

    echo_success "Skill activation working correctly"
}

# Test active skills configuration
test_active_skills_config() {
    echo_info "Testing active skills configuration"

    # Check that config file exists
    if [ ! -f ".skillsync/active-skills.json" ]; then
        echo_failure ".skillsync/active-skills.json not created"
    fi

    # Check the content of the config file
    local config_content=$(cat ".skillsync/active-skills.json")
    local expected='[
  {
    "id": "react-best-practices",
    "source": "vercel",
    "path": "react-best-practices"
  }
]'

    # Normalize JSON for comparison (remove extra whitespace)
    local normalized_config=$(echo "$config_content" | jq -c .)
    local normalized_expected=$(echo "$expected" | jq -c .)

    if [ "$normalized_config" != "$normalized_expected" ]; then
        echo_failure "Active skills config does not match expected content"
        echo "Expected: $normalized_expected"
        echo "Got: $normalized_config"
    fi

    echo_success "Active skills configuration correct"
}

# Test list command
test_list_command() {
    echo_info "Testing skills list command"

    local list_output=$(./skillsync list)
    local expected="react-best-practices	(vercel:react-best-practices)"

    if [ "$list_output" != "$expected" ]; then
        echo_failure "List command output does not match expected"
        echo "Expected: '$expected'"
        echo "Got: '$list_output'"
    fi

    echo_success "Skills list command working correctly"
}

# Test that only vercel repo exists
test_only_vercel_repo() {
    echo_info "Testing that only vercel repository exists"

    # Count subdirectories in skills-repos
    local repo_count=$(find skills-repos -maxdepth 1 -type d | wc -l)

    # Should be 2: skills-repos/ and skills-repos/vercel/
    if [ "$repo_count" -ne 2 ]; then
        echo_failure "Expected exactly 1 repository, found $((repo_count - 1))"
    fi

    # Check that it's the vercel repo
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "vercel repository not found"
    fi

    echo_success "Only vercel repository exists as expected"
}

# Test cleanup using skillsync commands
test_cleanup_with_skillsync() {
    echo_info "Testing cleanup using skillsync commands"

    # Remove the skill
    ./skillsync remove react-best-practices

    # Verify skill is removed from list
    local list_output=$(./skillsync list)
    if [ -n "$list_output" ]; then
        echo_failure "Skills list should be empty after removal"
    fi

    # Verify symlink is removed
    if [ -L "skills/react-best-practices" ]; then
        echo_failure "Symlink should be removed after skill deactivation"
    fi

    # Remove the repository (soft removal to keep files but unregister)
    ./skillsync remove-repo --soft vercel

    # Verify repository directory is preserved (soft removal keeps files)
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "Repository directory should be preserved after soft removal"
    fi

    # Verify it's no longer a git submodule (but files remain)
    if [ -e "skills-repos/vercel/.git" ]; then
        echo_failure "Repository should no longer be a git submodule after soft removal"
    fi

    # Verify .gitmodules is clean
    local gitmodules_content=$(cat .gitmodules)
    if echo "$gitmodules_content" | grep -q "vercel"; then
        echo_failure ".gitmodules should not contain vercel references after removal"
    fi

    echo_success "Soft removal cleanup successful"
}

# Test repository re-adding after soft removal (no manual rm needed)
test_readd_after_soft_removal() {
    echo_info "Testing repository re-adding after soft removal (no manual rm)"

    # First clean up any existing repository
    ./skillsync remove-repo --soft vercel 2>/dev/null || true

    # Verify no vercel repository exists in git
    if git ls-files --stage | grep -q vercel; then
        echo_failure "Vercel repository should not exist in git index"
    fi

    # Try to re-add the repository (should work without manual rm commands)
    ./skillsync add-repo https://github.com/vercel-labs/agent-skills vercel "skills/react-best-practices/" 772252060741749696ce2abcb060c9efed6a5737

    # Verify repository was re-added successfully
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "Repository should be re-added successfully"
    fi

    # Verify it's a git repository
    if [ ! -e "skills-repos/vercel/.git" ]; then
        echo_failure "Re-added repository should be a valid git repo"
    fi

    # Check that react-best-practices skill is checked out
    if [ ! -d "skills-repos/vercel/skills/react-best-practices" ]; then
        echo_failure "react-best-practices skill should be checked out"
    fi

    # Verify commit is correct
    local current_commit=$(cd "skills-repos/vercel" && git rev-parse HEAD)
    if [ "$current_commit" != "772252060741749696ce2abcb060c9efed6a5737" ]; then
        echo_failure "Repository should be at correct commit after re-adding"
    fi

    # Final cleanup: ensure workspace is completely clean via hard removal
    echo_info "Performing final workspace cleanup"
    ./skillsync remove-repo --hard vercel

    # Verify no skills remain
    local remaining_skills=$(./skillsync list)
    if [ -n "$remaining_skills" ]; then
        echo_failure "No skills should remain after hard removal"
    fi

    # Verify no repositories remain
    if [ -d "skills-repos/vercel" ]; then
        echo_failure "Repository directory should be completely removed"
    fi

    # Verify git index is clean
    if git ls-files --stage | grep -q vercel; then
        echo_failure "No vercel entries should remain in git index"
    fi

    # Verify .gitmodules is clean
    local gitmodules_content=$(cat .gitmodules)
    if echo "$gitmodules_content" | grep -q "vercel"; then
        echo_failure ".gitmodules should be clean after hard removal"
    fi

    echo_success "Repository re-adding works without manual rm commands, workspace completely clean"
}

# Test commit ID sparse checkout works without manual intervention
test_commit_sparse_checkout() {
    echo_info "Testing commit ID sparse checkout works automatically"

    # Clean up any existing repository
    ./skillsync remove-repo --force --hard vercel 2>/dev/null || true

    # Add repository with commit ID
    ./skillsync add-repo https://github.com/vercel-labs/agent-skills vercel "skills/react-best-practices/" 772252060741749696ce2abcb060c9efed6a5737

    # Verify sparse checkout worked correctly (no manual commands needed)
    if [ ! -d "skills-repos/vercel/skills/react-best-practices" ]; then
        echo_failure "Sparse checkout did not work with commit ID"
    fi

    # Verify we're on the correct commit
    local current_commit=$(cd "skills-repos/vercel" && git rev-parse HEAD)
    if [ "$current_commit" != "772252060741749696ce2abcb060c9efed6a5737" ]; then
        echo_failure "Repository not checked out to correct commit"
    fi

    # Verify sparse checkout is active
    local sparse_status=$(cd "skills-repos/vercel" && git sparse-checkout list)
    if [ "$sparse_status" != "skills/react-best-practices/" ]; then
        echo_failure "Sparse checkout patterns not applied correctly"
    fi

    echo_success "Commit ID sparse checkout works without manual intervention"
}

# Test soft removal handles .gitmodules staging correctly
test_soft_removal_gitmodules() {
    echo_info "Testing soft removal handles .gitmodules staging correctly"

    # Ensure repository exists first
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "Repository should exist for this test"
    fi

    # Check .gitmodules has entries
    local gitmodules_before=$(cat .gitmodules | wc -l)
    if [ "$gitmodules_before" -eq 0 ]; then
        echo_failure ".gitmodules should have entries before removal"
    fi

    # Perform soft removal
    ./skillsync remove-repo --soft vercel

    # Verify repository directory is preserved but .git is removed
    if [ ! -d "skills-repos/vercel" ]; then
        echo_failure "Repository directory should be preserved after soft removal"
    fi

    # Verify it's no longer a git submodule
    if [ -e "skills-repos/vercel/.git" ]; then
        echo_failure "Repository should no longer be a git submodule after soft removal"
    fi

    # Verify .gitmodules is clean (no vercel entries)
    local gitmodules_content=$(cat .gitmodules)
    if echo "$gitmodules_content" | grep -q "vercel"; then
        echo_failure ".gitmodules should not contain vercel entries after soft removal"
    fi

    echo_success "Soft removal handles .gitmodules staging correctly"
}

# Test default behavior: add-repo with just URL adds all skills automatically
test_add_repo_default_all_skills() {
    echo_info "Testing default behavior: add-repo with URL only adds all skills"

    # Clean up any existing repositories that might conflict
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true
    ./skillsync remove-repo --force --hard vercel 2>/dev/null || true

    # Add repository with just URL (no patterns specified) - should create vercel-labs-agent-skills
    ./skillsync add-repo https://github.com/vercel-labs/agent-skills

    # Verify correct directory name was created
    if [ ! -d "skills-repos/vercel-labs-agent-skills" ]; then
        echo_failure "Directory vercel-labs-agent-skills not created"
    fi

    # Verify it's a git repository
    if [ ! -e "skills-repos/vercel-labs-agent-skills/.git" ]; then
        echo_failure "Repository should be a valid git repo"
    fi

    # Verify all skills from the repo were added (at least react-best-practices should be there)
    if [ ! -d "skills-repos/vercel-labs-agent-skills/skills" ]; then
        echo_failure "Skills directory should exist"
    fi

    # Check that at least one skill was checked out
    local skill_count=$(find "skills-repos/vercel-labs-agent-skills/skills" -maxdepth 1 -type d -not -name skills | wc -l)
    if [ "$skill_count" -eq 0 ]; then
        echo_failure "At least one skill should be checked out by default"
    fi

    # Verify sparse checkout is configured for all skills
    local sparse_config=$(cd "skills-repos/vercel-labs-agent-skills" && git sparse-checkout list)
    if [ -z "$sparse_config" ]; then
        echo_failure "Sparse checkout should be configured for all skills"
    fi

    # Clean up this test's repository
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true

    echo_success "Default behavior adds all skills from repository automatically"
}

# Test adding repository via URL and verify automatic activation
test_add_url_and_activation() {
    echo_info "Testing automatic activation when adding via URL"

    # Clean up any existing repositories that might conflict
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true

    # Add repository with just URL via 'add' command
    ./skillsync add https://github.com/vercel-labs/agent-skills

    # Verify repository exists
    if [ ! -d "skills-repos/vercel-labs-agent-skills" ]; then
        echo_failure "Repository directory not created"
    fi

    # Verify skills directory exists and is populated with symlinks
    if [ ! -d "skills" ]; then
        echo_failure "Active skills directory 'skills' not created"
    fi

    # Check for specific symlink (react-best-practices)
    if [ ! -L "skills/react-best-practices" ]; then
        echo_failure "Skill symlink 'react-best-practices' not created automatically"
    fi

    # Verify symlink target
    local symlink_target=$(readlink "skills/react-best-practices")
    if [ "$symlink_target" != "../skills-repos/vercel-labs-agent-skills/skills/react-best-practices" ]; then
        echo_failure "Symlink points to wrong location: $symlink_target"
    fi

    echo_success "Automatic skill activation via URL add working correctly"
}

# Test that removing a repository also removes its skills from the active skills directory
test_remove_repo_removes_skills() {
    echo_info "Testing skill removal from 'skills/' when repository is removed"

    # Clean up any existing repositories that might conflict
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true

    # Add repository via URL (activates skills)
    ./skillsync add https://github.com/vercel-labs/agent-skills

    # Verify skills exist
    if [ ! -L "skills/react-best-practices" ]; then
        echo_failure "Skill symlink should exist before removal"
    fi

    # Remove repository (hard removal)
    ./skillsync remove-repo --hard --force vercel-labs-agent-skills

    # Verify skills are gone from 'skills/'
    if [ -L "skills/react-best-practices" ]; then
        echo_failure "Skill symlink should be removed after repository removal"
    fi

    echo_success "Skills correctly removed from 'skills/' folder upon repository removal"
}

# Test that removing a repository via URL (./skillsync remove <URL>) works
test_remove_url() {
    echo_info "Testing repository removal via URL (./skillsync remove <URL>)"

    # Clean up any existing repositories that might conflict
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true

    # Add repository via URL (activates skills)
    ./skillsync add https://github.com/vercel-labs/agent-skills

    # Verify skills and repo exist
    if [ ! -L "skills/react-best-practices" ]; then
        echo_failure "Skill symlink should exist before removal"
    fi
    if [ ! -d "skills-repos/vercel-labs-agent-skills" ]; then
        echo_failure "Repo directory should exist before removal"
    fi

    # Remove repository via URL
    ./skillsync remove https://github.com/vercel-labs/agent-skills

    # Verify skills are gone but repo directory STILL EXISTS
    if [ -L "skills/react-best-practices" ]; then
        echo_failure "Skill symlink should be removed after URL removal"
    fi
    if [ ! -d "skills-repos/vercel-labs-agent-skills" ]; then
        echo_failure "Repo directory should be PRESERVED after URL removal"
    fi

    echo_success "Skills correctly removed but repository preserved via URL removal"
}

# Test that removing a specific skill via URL (./skillsync remove <URL> <path>) works
test_remove_skill_via_url() {
    echo_info "Testing specific skill removal via URL (./skillsync remove <URL> <path>)"

    # Clean up
    ./skillsync remove-repo --force --hard vercel-labs-agent-skills 2>/dev/null || true

    # Add repo with all skills
    ./skillsync add https://github.com/vercel-labs/agent-skills

    # Verify multiple skills exist
    if [ ! -L "skills/react-best-practices" ] || [ ! -L "skills/claude.ai" ]; then
        echo_failure "Initial skills should exist"
    fi

    # Remove only ONE skill via URL
    ./skillsync remove https://github.com/vercel-labs/agent-skills claude.ai

    # Verify ONLY claude.ai is gone
    if [ -L "skills/claude.ai" ]; then
        echo_failure "claude.ai should be removed"
    fi
    if [ ! -L "skills/react-best-practices" ]; then
        echo_failure "react-best-practices should be preserved"
    fi
    if [ ! -d "skills-repos/vercel-labs-agent-skills" ]; then
        echo_failure "Repo should be preserved"
    fi

    echo_success "Specific skill deactivated via URL correctly"
}

# Cleanup test environment
cleanup_test() {
    echo_info "Cleaning up test environment"

    cd /
    rm -rf "$TEST_DIR"

    echo_success "Test cleanup complete"
}

# Run all tests
run_tests() {
    echo_info "Starting skillsync unit tests"

    setup_test
    test_add_vercel_skill
    test_activate_skill
    test_active_skills_config
    test_list_command
    test_only_vercel_repo
    test_cleanup_with_skillsync
    test_readd_after_soft_removal
    test_commit_sparse_checkout
    test_soft_removal_gitmodules
    test_add_repo_default_all_skills
    test_add_url_and_activation
    test_remove_repo_removes_skills
    test_remove_url
    test_remove_skill_via_url

    echo_success "All tests passed! ✅"

    # Now clean up the test environment automatically
    cleanup_test
}

# Main execution
if [ "${1:-}" = "cleanup" ]; then
    cleanup_test
else
    run_tests
fi
