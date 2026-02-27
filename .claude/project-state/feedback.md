# Feedback Log

## Next ID: FB-001

<!--
Append-only log of user feedback signals. Do not edit or delete existing entries.
The PM updates "Next ID" above each time a new entry is appended.

Entry format (append below the "---" separator):

### FB-XXX: <short title>
- **Date**: YYYY-MM-DD
- **Session**: <session-id>
- **Signal**: positive | negative | removal
- **Domain**: <specialist domain prefix, e.g. "model-architecture", or "general">
- **Raw feedback**: <what the user said, verbatim or close paraphrase>
- **Extracted preference**: <actionable preference distilled from feedback, or "REMOVE" if signal is removal>
- **Supersedes**: FB-YYY | none

Notes:
- "Signal: removal" means the user wants to delete a preference without replacement.
  Set Extracted preference to "REMOVE" and Supersedes to the FB-ID being removed.
- Domain must exactly match a specialist name prefix (strip "-specialist") or be "general".
- The PM must update "Next ID" above after every append.
-->

---
