<!-- skills-user/meta-skill-maintenance/SKILL.md -->
---
name: skill-maintenance
tier: advanced
tags: [meta, maintenance]
---

# Skill Maintenance

You are now in skill maintenance mode. Your task is to help maintain the skill library.

## Available Operations

### Merge Upstream Updates
When upstream skill changes conflict with local modifications:

1. Read three versions:
   - BASE: `.skillsync/merge-temp/{skill-id}/base.md`
   - UPSTREAM: `.skillsync/merge-temp/{skill-id}/upstream.md`
   - LOCAL: `.skillsync/merge-temp/{skill-id}/local.md`

2. Analyze changes:
   - What did upstream improve?
   - What did local modifications add?
   - Are there semantic conflicts?

3. Generate merged version that:
   - Preserves all local customizations
   - Integrates upstream improvements
   - Maintains skill structure (YAML header + sections)
   - Flags unresolvable conflicts with `<!-- CONFLICT: reason -->`

4. Write to `.skillsync/merge-temp/{skill-id}/merged.md`
5. Write confidence score (0-1) to `.skillsync/merge-temp/{skill-id}/confidence.txt`
6. Write summary to `.skillsync/merge-temp/{skill-id}/summary.md`

### Validate Skill Format
Check that skill files follow conventions:
- Valid YAML frontmatter
- Required fields: name, description
- Proper markdown structure
- No broken internal links

### Suggest Skill Improvements
When asked, analyze a skill and suggest:
- Missing examples
- Unclear instructions
- Opportunities to split/merge skills
- Dependencies that should be declared
