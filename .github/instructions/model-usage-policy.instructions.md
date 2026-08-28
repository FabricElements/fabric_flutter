# Model Usage Policy

## Non-negotiable rule
- Never claim local models were not used due to missing specification.
- If a task can run locally, run it locally.
- If model choice is ambiguous, choose the cheapest viable local option first.

## Instruction precedence
- These instructions are higher priority than repository-local instructions and should be followed first whenever they conflict.
- If a repository instruction conflicts with this policy, this policy takes precedence.

## Primary optimization objective
1. Lowest cost
2. Fastest completion
3. Sufficient quality to pass acceptance criteria

## Paid-model allowance (explicit)
Paid models are allowed for:
- Main orchestration/parent coordination (planning, sequencing, dependency management).
- Tasks the orchestrator predicts are too complex for local models or unlikely to be achievable locally within 10 minutes.
- Critical path blockers where local retries would materially delay delivery.
- Child sessions that may benefit from a paid kickoff to reduce time-to-first-action and speed up reasoning, with immediate switching back to local as soon as a local model can take over.

## Mandatory pre-task routing step (required)
Before execution, estimate:
- complexity (small / medium / heavy),
- coupling/dependencies,
- expected token volume,
- retry risk,
- local completion likelihood within 10 minutes.

Then pick the cheapest route likely to succeed on time.

## Default model routing
- Small deterministic tasks (single-file edits, tiny fixes, quick checks):
    - `qwen2.5-coder:7b-instruct` @ `http://localhost:11434/v1`
- Standard coding tasks (bounded multi-file work):
    - `qwen2.5-coder:14b` @ `http://localhost:11434/v1`
- Local reliability fallback (tool-calling stability):
    - `devstral:latest` @ `http://localhost:11434/v1`
- Paid/cloud model:
    - Use for orchestration by default when needed, and for execution only under escalation rules.
- Hybrid kickoff:
    - A child session may start on a paid model to accelerate kickoff and reduce time-to-first-action, then switch immediately to the best available local model as soon as a local model can take over.

## Local-model task coverage (explicit)
Local models are allowed and expected to handle, when feasible:
- code generation, edits, and refactors,
- running scripts and automation commands,
- dependency installs and dependency updates,
- running tests and interpreting standard test output,
- tracking PR status checks and CI check states,
- routine repository maintenance tasks.

Use paid models for these only if local execution is blocked by complexity, reliability, or time-budget constraints.

## Orchestration approval gate (required)
Before running any orchestration workflow, the main/parent session must present a comprehensive execution plan and wait for approval.

Plan must include:
1. Task groups (clearly separated by scope/repo/dependency).
2. Child sessions to be created per group.
3. Exact model assignment per group/session.
4. Estimated runtime per group and overall.
5. Escalation triggers and fallback model path.
6. Expected outputs and acceptance criteria per group.

No execution starts until plan approval is received.

## Plan adherence and anti-divergence rule
- After approval, follow the approved model assignments exactly.
- Do not switch to different models unless escalation criteria are met.
- Any model switch must be explicitly logged with reason:
    - `Switching to [model] because [reason].`
- Keep switches minimal and return to planned local models once blocker is resolved.

## Task decomposition policy (cost control)
- Split heavy work into smaller independent chunks that 7B/14B can finish quickly.
- Run local child sessions in parallel when it lowers total runtime.
- Parent session must provide explicit, execution-ready prompts so local children do minimal reasoning.
- Use sequential execution only for true dependencies.

## Time-budget and anti-blocking policy
- Local model target windows:
    - Small: 2–4 min
    - Medium: 5–8 min
    - Heavy scoped chunk: 8–10 min
- If a task is predicted to exceed 10 minutes locally, either:
    1. split further for parallel local execution, or
    2. escalate to paid model immediately if splitting is unlikely to meet SLA.

## Escalation policy (strict)
Escalate to paid model when any condition is true:
1. Predicted local completion exceeds 10 minutes on critical path.
2. Two local attempts failed on the same blocking subtask.
3. Cross-repo/architecture reasoning exceeds local reliability.
4. Integration risk/cost of failure is higher than paid execution cost.

When escalating, state:
`Switching to [model] because [reason].`

After blocker resolution, route remaining routine work back to local models.

## Prompting requirements for local child sessions
Every child kickoff must include:
1. exact objective and done criteria,
2. exact files/paths/scope boundaries,
3. ordered execution steps,
4. expected output format,
5. constraints (no scope creep, no broad analysis),
6. timeout and escalation trigger.

## Main-session tracking & reporting (required)
The parent session must track and report per child session:

1. Commit metadata
    - Exact commit title
    - Exact commit SHA (full or short, but consistent)
    - Repository and branch
2. Execution timing
    - Child start timestamp
    - Child completion timestamp
    - Total wall-clock duration
3. Human-effort estimate
    - Estimated manual implementation time (minutes/hours)
    - Brief basis for estimate (scope, files touched, complexity)
4. Model cost accounting
    - Model(s) used per task (local and/or paid)
    - Estimated token usage when available
    - Actual dollar cost for paid model usage when available from tooling/provider
    - If exact billed cost is unavailable, report a clearly labeled estimate and confidence level

## Required output format after each completed task
Provide a per-task record in a structured table with columns:

- Task ID
- Repo/Branch
- Commit Title
- Commit SHA
- Model(s) Used
- Start Time
- End Time
- Duration
- Est. Human Time
- Actual/Estimated Cost (USD)
- Notes

Also provide rolling totals:
- Total child tasks completed
- Total elapsed runtime
- Total estimated human time saved
- Total cost (USD), split by local vs paid

## Mandatory prompt-quality retrospective
Each task summary must include a short Prompt Quality Review:
1. What in the original prompt caused ambiguity or rework.
2. How the prompt could have been clearer (specific wording improvements).
3. A revised prompt template that would reduce tokens/time on local models.
4. Whether stricter constraints or better file targeting would have avoided retries.

## Cost governance rules
- Always try fastest/cheapest viable path first.
- Do not use paid models for routine work local models can complete within budget.
- Prefer multiple small local steps over one expensive large-model run when outcomes are equivalent.
- Re-evaluate model choice at each phase; avoid staying on paid models longer than necessary.

## Orchestrator behavior
- Main session may use GitHub Copilot Auto / paid model for orchestration quality.
- Even with paid orchestration, execution should default to local child sessions whenever feasible.
- Parent must enforce local-first routing and cost-aware decomposition continuously.

## Daily human-effort cap
- For repositories where a daily human-effort cap is enforced, the orchestrator must enforce a cap of:
    - Maximum 10 hours/day of estimated human work executed
- This cap is based on estimated manual effort equivalent, not wall-clock runtime.
- Before starting new task groups, compute:
    - `today_estimated_human_hours_completed`
    - `today_estimated_human_hours_planned`
    - `remaining_daily_capacity = 10h - completed`
- If planned work exceeds remaining capacity:
    1. Re-prioritize critical tasks only.
    2. Defer non-critical task groups to next day.
    3. Split large tasks into smaller chunks that fit within remaining capacity.
- Required reporting (for daily summary when cap is active):
    - Estimated human hours completed today
    - Estimated human hours deferred
    - Remaining capacity (hours)
    - Repositories/tasks moved to next execution window

## Session lifecycle and remote trace elimination
- After task completion, DELETE child sessions (not just archive) to leave no remote trace.
- Use session deletion to remove all GitHub agent traces.
- Archive is only for local cleanup; remote deletion is mandatory.
- Perform deletion after the related pull request is merged or the related issue is closed.

## Pending work tracking with issues
- After task completion, if additional work remains, ask the user whether they want repository issues created for follow-up work.
- Keep track of all follow-up issues created during execution.
- Reference all created follow-up issues in the pull request description.
- Link and close follow-up issues when the pull request is merged.
- Update follow-up issues with pending implementation details and clear handoff notes.

## Approved local endpoint/models
- Endpoint: `http://localhost:11434/v1`
- `qwen2.5-coder:7b-instruct` (fastest/cheapest)
- `qwen2.5-coder:14b` (primary balance)
- `devstral:latest` (local reliability fallback)
