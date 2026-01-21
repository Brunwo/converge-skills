<!-- skills-user/meta-skill-maintenance/SKILL.md -->
---
# Skill Maintenance

You are now in skill maintenance mode. Your task is to help maintain the skill library.

## Available Operations

### Merge Upstream Updates
When upstream skill changes conflict with local modifications:

rely on native Git commands to verify current local git state of submodules (behind / ahead / diverged ) 

warn user about local commits without a remote branch

if user modified a skill, evaluate if user should create his own fork or if the user should create a pull request to the upstream repository

if relevant, propose to split personal changes into a specific branch

if the user centralizes his skills in a single repo he owns, if this repo uses submodules, when this user's changes drift from the upstream and pull requests are not the users wish, propose to create a fork of the skill original repo, then update the user's skill repo submodule to use this fork instead of the original repo.

Analyze changes:
   - What did upstream improve?
   - What did local modifications add?
   - Are there semantic conflicts?

is the user the owner of the remote repository?
are there multiple remotes?

this meta skill relies on agent / user interactions : 

if the agent has a subagent / possibility to launch in a sandbox , or separated cli for context isolation, identify this function and propose to use it by default to run those maintenance workflows.

those workflows use subagent to scan the active skillset. 

possible recommandations : 
 - warn the user about possible duplicates of skills : 
   in this case, using either a separate repo, or one of the skill repo / branch ,depending on who owns the original repo aand any other consideration : amount of changes etc.. manage merging skills via git merchanics , merging / forking etc.. to keep tracability and future merging updates possible.  
   for example if user rely on two similar skillsets, none of them (remote repo) owned by the user, a poposition could be to create a new repo / skill fork of one of the skillset
 - warn the user about contradictions in current active skillset
 
 - git exploration : checking for other forks of certains skills, git subtrees existence,  more up-to-date versions if github / web tools are available

 any other advice is also possible

