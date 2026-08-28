# Model Usage Policy

## Non-negotiable rule
- Never claim local models were not used due to missing specification.
- Prefer low-cost execution overall; optimize for quality and speed when local models cannot deliver safely.
- Kick off with the cheapest paid model suitable for the task, then switch to local models for fast/routine execution when it makes sense.

## Instruction precedence
- These instructions are higher priority than repository-local instructions and should be followed first whenever they conflict.
- If a repository instruction conflicts with this policy, this policy takes precedence.

## Primary optimization objective
1. Lowest cost
2. Fastest completion
3. Sufficient quality to pass acceptance criteria

## Paid-model allowance (explicit)
Paid models are the DEFAULT starting point. Kick off with the cheapest paid model suitable for the task, then:
- Use paid models for main orchestration/parent coordination (planning, sequencing, dependency management).
- Use paid models for complex reasoning and architectural decisions.
- Switch to local models for child execution tasks when:
   - The task is deterministic and fast (code edits, file operations, running tests)
   - Local models can complete within their target window (2–10 min)
   - The work is well-scoped with clear acceptance criteria (provided by the orchestrator)
- Return to paid model if a local attempt exceeds time budget or fails on a blocking subtask.

## Mandatory pre-task routing step (required)
Before execution, the orchestrator (paid model) estimates:
- complexity (small / medium / heavy),
- coupling/dependencies,
- expected token volume,
- retry risk,
- local completion likelihood within budget windows.

Then:
1. **Orchestrator** (paid) plans the work, breaks it into task groups, and decides which tasks are suitable for local handoff
2. **Execution** routes each task to the cheapest viable model:
    - Paid model for complex decisions, coordination, or reasoning
    - Local model for fast deterministic work (if within time budget)

## Default model routing
**Orchestration (default: PAID model)**
- Start with the cheapest suitable paid model (prioritize: GPT-4 mini, Claude Haiku, other cost-optimized options)
- Orchestrator breaks work into task groups, estimates complexity, and routes each group
- Orchestrator specifies acceptance criteria and constraints for each task

**Execution routing (dynamic: PAID or LOCAL)**
- Small deterministic tasks (2–4 min window): Route to local model (discover available models at runtime)
- Standard coding tasks (5–8 min window): Route to local model if time budget permits; otherwise paid
- Complex tasks requiring reasoning or coordination: Keep on paid model
- Tasks with unclear requirements or high integration risk: Keep on paid model

**Model discovery for local execution:** Query the local LLM service endpoint at the time of execution to discover available models. Select based on:
1. Task complexity and required capabilities (code generation, tool-calling)
2. Available models and their performance characteristics
3. Time budget compatibility

**Fallback to paid model:** If local execution fails or exceeds time budget, immediately escalate to paid model for remediation.

## Local-model task coverage (when to use)
Local models execute tasks when:
- The work is deterministic and well-scoped (provided by paid orchestrator)
- The task completes within time budget (2–10 min depending on complexity)
- The work involves code generation, edits, refactors, script execution, test running
- Tool-calling support is available for the task
- The acceptance criteria are clear and unambiguous

Local execution saves cost on routine, fast work. Escalate to paid model if:
- The task exceeds time budget
- Tool-calling reliability becomes an issue
- The work requires cross-cutting reasoning or decision-making
- Two attempts at local execution have failed

## Orchestration approval gate (required)
Before running any orchestration workflow, the main/parent session must present a comprehensive execution plan and wait for approval.

Plan must include:
1. Task groups (clearly separated by scope/repo/dependency).
2. Child sessions to be created per group.
3. Model selection strategy per group/session (criteria for choosing among available local models, or escalation trigger for paid model use).
4. Estimated runtime per group and overall.
5. Escalation triggers and fallback model path.
6. Expected outputs and acceptance criteria per group.

No execution starts until plan approval is received.

## Plan adherence and anti-divergence rule
- After approval, follow the approved orchestration plan and model allocation strategy.
- Paid model makes the high-level decisions and coordinates; local models execute fast deterministic tasks.
- If a local task exceeds time budget or fails, immediately escalate back to the paid model.
- Any escalation must be explicitly logged with reason and timing.
- Do not retry failed local tasks repeatedly; escalate on the second failure.

## Task decomposition policy (cost control)
- Split heavy work into smaller independent chunks that lighter local models can finish quickly.
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
- Kick off with the **cheapest suitable paid model** for orchestration and planning (not the most powerful).
- Switch execution to local models for fast/deterministic tasks when time budget permits.
- Do not use paid models for routine work if local models can complete within time windows (2–10 min).
- Prefer multiple small local task executions over staying on paid model for the whole work.
- Re-evaluate model choice at each phase; return to paid model immediately if local execution is blocked.

## Orchestrator behavior
- **Main session MUST use a paid model** (cheapest suitable tier) for orchestration, planning, and parent coordination.
- Paid orchestrator breaks work into clear task groups and specifies which are suitable for local execution.
- Paid orchestrator provides execution-ready prompts to local child sessions to minimize reasoning overhead.
- Paid orchestrator monitors execution; escalates immediately if a local task exceeds time budget or fails.
- Paid orchestrator maintains plan coherence and prevents drift across task groups.

## Approved local endpoint
- Endpoint: `http://localhost:11434/v1` (or compatible OpenAI-compatible LLM service)

**Available models:** Discover at runtime by querying the local endpoint. Agents should list available models and select the best fit for the task type, prioritizing:
1. Models with reliable tool-calling support
2. Fastest execution for the task complexity level
3. Lowest resource consumption when multiple viable options exist

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
