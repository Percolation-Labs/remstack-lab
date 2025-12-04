# Phoenix Experiments - Quick Start

Run LLM-as-Judge evaluations using the `rem` CLI.

## How It Works

### The Experiment Flow

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Ground Truth   │────▶│  Run Agent      │────▶│  Run Evaluator  │
│  (dataset.jsonl)│     │  (your agent)   │     │  (LLM-as-Judge) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       ▼                       ▼
        │               ┌─────────────────┐     ┌─────────────────┐
        │               │  Agent Output   │────▶│  Scores/Labels  │
        │               │  (response)     │     │  (pass/fail)    │
        └──────────────▶└─────────────────┘     └─────────────────┘
                              reference              comparison
```

**Phase 1 - Agent Run**: For each example in your dataset, the agent receives the `input` and generates a response.

**Phase 2 - Evaluation**: The evaluator (another LLM) compares the agent's response against the `expected_output` and scores it.

### Vibes Mode vs Phoenix Mode

| Mode | What it does | Best for |
|------|-------------|----------|
| **Vibes** (`--only-vibes`) | Runs locally e.g. using Claude Code, saves JSON results to disk | Quick iteration, no server needed |
| **Phoenix** | Sends traces to Phoenix server, enables UI dashboard | Comparing experiments, team visibility |

---

## 1. Create Experiment

```bash
rem experiments create my-eval \
    --agent my-agent \
    --evaluator my-evaluator \
    --description "Evaluate my agent"
```

This creates:

```text
experiments/my-eval/
├── experiment.yaml          # Config: agent, evaluator, settings
├── ground-truth/
│   └── dataset.jsonl        # Your Q&A pairs (input → expected_output)
└── results/                 # Vibes mode saves results here
```

## 2. Add Ground Truth

Edit `experiments/my-eval/ground-truth/dataset.jsonl`:

```json
{"id": "1", "input": "What is photosynthesis?", "expected_output": "Plants convert sunlight to energy"}
{"id": "2", "input": "When did WW2 end?", "expected_output": "1945"}
```

Each line is one test case. The evaluator will compare agent output against `expected_output`.

## 3. Run Experiment

**Vibes Mode** (local, no server):

```bash
rem experiments run my-eval --only-vibes
```

**Phoenix Mode** (with dashboard):

```bash
# Start Phoenix with docker-compose (from repo root)
docker compose -f docker-compose.prebuilt.yml up -d phoenix

# Set your API key and run
export OPENAI_API_KEY='your-key'
EVALUATOR_MODEL='openai:gpt-4.1-mini' \
LLM__DEFAULT_MODEL='openai:gpt-4.1-mini' \
rem experiments run my-eval
```

## 4. View Results

- **Vibes**: Results in `experiments/my-eval/results/{timestamp}/`
- **Phoenix**: Open <http://localhost:6006> → Datasets → Compare

---

## How Evaluator Schemas Become Prompts

The evaluator YAML schema is converted into a structured LLM prompt:

```text
┌─────────────────────────────────────────────────────────────────┐
│ SYSTEM PROMPT (from schema "description" field)                 │
│                                                                 │
│   "You are THE JUDGE evaluating QA assistant responses..."     │
│                                                                 │
│   + JSON Schema requirement:                                    │
│   "You MUST respond with valid JSON matching this schema:       │
│    { overall_score: number, pass: boolean, notes: string }"    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ USER MESSAGE (constructed from dataset example)                 │
│                                                                 │
│   Question/Input: What is photosynthesis?                       │
│                                                                 │
│   Agent's Answer:                                               │
│   {"response": "Photosynthesis is how plants make food..."}    │
│                                                                 │
│   Expected Answer (Reference):                                  │
│   Plants convert sunlight to energy                             │
│                                                                 │
│   Please evaluate the agent's answer.                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LLM RESPONSE (structured JSON)                                  │
│                                                                 │
│   { "overall_score": 0.85, "pass": true, "notes": "Good..." } │
└─────────────────────────────────────────────────────────────────┘
```

### Schema → Phoenix Columns

The `phoenix_config` section maps evaluator output fields to Phoenix UI columns:

```yaml
phoenix_config:
  evaluations:
    - name: overall           # Column name in Phoenix UI
      score_field: overall_score  # Which JSON field has the score
      label_field: pass           # Which field has the label
      label_transform:            # Convert boolean to string
        "true": "pass"
        "false": "fail"
```

Each evaluation in the list becomes a separate column in Phoenix's experiment comparison view.

---

## Evaluator Schema Reference

Place in `evaluators/my-evaluator.yaml`:

```yaml
title: MyEvaluator
type: object
description: |
  Score accuracy 0.0-1.0. Set pass=true if score >= 0.7.

  Consider:
  - Factual correctness
  - Completeness of answer
  - Appropriate tone

properties:
  overall_score:
    type: number
    minimum: 0
    maximum: 1
    description: Overall quality score
  pass:
    type: boolean
    description: Did the answer meet the bar?
  notes:
    type: string
    description: Explanation of the score

required: [overall_score, pass]

# Maps output fields to Phoenix UI columns
phoenix_config:
  evaluations:
    - name: overall
      score_field: overall_score
      label_field: pass
      label_transform:
        "true": "pass"
        "false": "fail"
      explanation_field: notes
```

**Key Points**:

- `description`: Becomes the system prompt for the evaluator LLM
- `properties`: Defines the JSON schema the evaluator must return
- `phoenix_config.evaluations`: Each entry becomes a Phoenix UI column
- `name: overall`: Required - this is the primary metric Phoenix displays

---

## Commands Reference

```bash
rem experiments list                    # List all experiments
rem experiments show my-eval            # Show experiment details
rem experiments run my-eval --limit 5   # Run on 5 examples only
rem experiments run my-eval --dry-run   # Preview without running
```

## Advanced: Dual Evaluators

For agents that return both a response AND call metadata tools, use a dual evaluator that scores both aspects:

```yaml
# Scores text quality (40% factual, 25% completeness, 20% tone, 15% clarity)
text_response_score:
  type: number

# Scores metadata tool call (40% compliance, 30% confidence calibration, ...)
metadata_score:
  type: number

# Combined: 60% text + 40% metadata
overall_score:
  type: number
```

See `evaluators/qa-assistant-dual.yaml` for a complete example.
