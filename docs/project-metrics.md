# Project metrics — a reusable rubric

A five-row table for the top of a project README, so a reader knows in ten
seconds what they are looking at. Portable: copy this file into any repo and
fill in the blank at the bottom.

The point is **calibration**. The same words have to mean the same thing in
every project, or the numbers are decoration. Two rules make that work:

1. **Rate the artifact, not the effort.** A thing that took you three weeks
   is not "advanced" if the result is three services on a happy path.
2. **Never round up.** A reader who finds the project weaker than the badge
   claimed stops trusting the rest of the README. Understating costs nothing.

---

## Difficulty — how hard this was to get right

| | Level | Means |
|---|---|---|
| **1/5** | Beginner | One service. Guided path, no integration. |
| **2/5** | Easy | Two or three services, a single integration point. |
| **3/5** | Intermediate | Many services wired together. The difficulty is integration, IAM and ordering — not algorithms. |
| **4/5** | Advanced | Non-obvious design decisions. Concurrency, consistency, latency or scale constraints that shape the architecture. |
| **5/5** | Expert | Novel architecture or genuine algorithmic depth. Few references exist; you worked it out. |

> Most cloud integration projects are a **3**. That is not a weak score — it
> is the honest centre of the scale.

## Depth — how far past the happy path it goes

| | Level | Means |
|---|---|---|
| **1/5** | Demo | One path, one example input. Breaks if you look at it oddly. |
| **2/5** | Broad, shallow | Touches a lot. Each piece is the happy path only. |
| **3/5** | Moderate | Input validation and the main edge cases on the critical path. |
| **4/5** | Deep | Failure modes handled — retries, idempotency, partial failure — **and tests that prove it**. |
| **5/5** | Exhaustive | Load and failure tested. Documented limits, SLOs and known breaking points. |

> Depth and Difficulty move independently. Broad-and-shallow (3/5 difficulty,
> 2/5 depth) is the normal shape for an integration showcase, and saying so
> is more credible than claiming both are high.

## Maturity — how close to production

Pick the **highest row where every box above it is also true**.

| Level | Requires |
|---|---|
| **Prototype** | Works on your machine. Manual steps, no tests. |
| **Dev / demo** | Reproducible deploy (IaC), scoped IAM, some automated tests, documented teardown. |
| **Hardened demo** | + observability and alarms, retries/DLQ, remote state, CI on every push. |
| **Pre-production** | + multiple environments, managed secrets, runbook, load tested. |
| **Production** | + SLOs, on-call, disaster recovery, cost controls, access review. |

Checklist to score it honestly — tick what is genuinely true:

```
[ ] Infrastructure as code          [ ] Observability / alarms
[ ] Least-privilege IAM             [ ] Retries + DLQ
[ ] Automated tests                 [ ] Remote, locked state
[ ] Documented teardown             [ ] CI on every push
[ ] Managed secrets                 [ ] Multiple environments
```

## Scope — the size, stated as facts

No scale here. Just counts, so the reader can calibrate the rows above:
services used, deployable components, managed resources, lines of code.

> Separate application code from infrastructure code. "1.5k lines" reads very
> differently if it is 1.3k of Terraform and 230 of Python.

## Cost & build time — what it costs to run and to rebuild

Two numbers people actually want: money to run it, and time to stand it up.
State deploy time and from-scratch build time separately — they differ by an
order of magnitude once the project is automated.

---

## Optional rows

Add only when they say something:

| Metric | Use it when |
|---|---|
| **Reusability** | Parts genuinely lift into another project — modules, a library |
| **Ops burden** | It runs continuously and someone has to care for it |
| **Data sensitivity** | It touches PII, payments or regulated data |

---

## Blank template

```markdown
| Metric | Value | Why |
|---|---|---|
| **Difficulty** | <Level> (<n>/5) | <what makes it that, in one clause> |
| **Depth** | <Level> (<n>/5) | <how far past the happy path> |
| **Maturity** | <Level> | <the gaps that stop it being the next level up> |
| **Scope** | <n services, n components, ~n resources, ~n LoC> | <what kind of project this is> |
| **Cost & build time** | <$n to run> · <n to deploy> | <what drives the cost> |
```

Two habits worth keeping:

- **Leave "Maturity: dev / demo" visible rather than hiding it.** Someone who
  labels their own demo accurately reads stronger than someone who oversells.
- **Pair the table with a "Hardening backlog"** listing the gaps the Maturity
  row implies. That turns a project into evidence you can *review* a system,
  which is the scarcer skill.
