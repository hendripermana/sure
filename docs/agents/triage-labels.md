# Triage Labels

The engineering skills use five canonical triage roles. Their tracker labels are
mapped directly:

| Canonical role | GitHub label | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | A maintainer must evaluate the issue |
| `needs-info` | `needs-info` | More information is required from the reporter |
| `ready-for-agent` | `ready-for-agent` | Fully specified and safe for an AFK agent |
| `ready-for-human` | `ready-for-human` | Requires human judgment or implementation |
| `wontfix` | `wontfix` | Will not be actioned |

When a skill refers to a triage role, apply the corresponding GitHub label from
this table. An issue may only be marked `ready-for-agent` when its domain terms,
acceptance behavior, testing boundaries, and safety constraints are explicit.
