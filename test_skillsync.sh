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
    if [ ! -d "skills-repos/vercel/.git" ]; then
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

    # Check that skills-active directory exists
    if [ ! -d "skills-active" ]; then
        echo_failure "skills-active directory not created"
    fi

    # Check that the symlink exists
    if [ ! -L "skills-active/react-best-practices" ]; then
        echo_failure "react-best-practices symlink not created"
    fi

    # Check that the symlink points to the correct location
    local symlink_target=$(readlink "skills-active/react-best-practices")
    if [ "$symlink_target" != "../skills-repos/vercel/skills/react-best-practices/" ]; then
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
    if [ -L "skills-active/react-best-practices" ]; then
        echo_failure "Symlink should be removed after skill deactivation"
    fi

    # Remove the repository (soft removal to keep it clean)
    ./skillsync remove-repo --soft vercel

    # Verify repository directory is cleaned up
    if [ -d "skills-repos/vercel" ]; then
        echo_failure "Repository directory should be removed after soft removal"
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
    if [ ! -d "skills-repos/vercel/.git" ]; then
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

    echo_success "Repository re-adding works without manual rm commands"
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
