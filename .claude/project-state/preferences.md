# User Preferences

<!--
Compact style guide distilled from feedback. Organized by domain sections.
Only the PM writes to this file. Specialists and reviewers read but never modify.

How agents receive preferences:
- The PM includes relevant preferences in every Task prompt (specialists AND reviewers).
- Specialists should also Read this file directly as their first step.
- The SessionStart hook injects this file into the PM's context (not subagent context).

Format: Each domain has a ### header that exactly matches a specialist name prefix
(the specialist filename minus "-specialist.md"). For example:
- model-architecture-specialist.md -> ### model-architecture
- data-pipeline-specialist.md -> ### data-pipeline

### general applies to all agents regardless of domain.

Entries are concise, one-line directives with the source FB-ID in parentheses. Example:
- Prefer seaborn over matplotlib for all plots (FB-003)
- Keep architectures simple; avoid unnecessary complexity (FB-007)

To remove a preference, delete its line. The PM logs removals in feedback.md with signal "removal".
-->

### general
