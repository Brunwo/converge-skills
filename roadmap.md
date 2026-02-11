No Upstream Contribution Workflow
usecases.md
 envisions pushing changes back upstream via PRs, but the tool doesn't assist with this.

Proposed: skillsync push <repo-name> or skillsync pr <repo-name> that:

Detects local changes in a submodule
Creates a branch
Pushes to a fork
Opens a PR via gh pr create