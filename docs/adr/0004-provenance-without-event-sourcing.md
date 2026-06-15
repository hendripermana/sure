# Add financial provenance without adopting full event sourcing

Sure will make provenance, idempotency, reconciliation, and material financial
audits explicit at its highest-value financial boundaries, while retaining the
current relational model. Full event sourcing is rejected during foundation
stabilization because its migration cost and operational complexity would delay
correctness work; rebuildable snapshots and targeted versioning provide the
needed integrity without a wholesale rewrite.
