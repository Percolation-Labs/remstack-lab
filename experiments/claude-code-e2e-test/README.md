# Claude Code E2E Test

This experiment demonstrates an AI assistant (Claude Code) reading the Phoenix experiments documentation and following it end-to-end to create and run an evaluation.

## Quick Start

```bash
# 1. Start Phoenix with docker-compose (includes everything you need)
docker compose -f docker-compose.prebuilt.yml up -d phoenix

# 2. Set your OpenAI API key
export OPENAI_API_KEY='your-key-here'

# 3. Run the experiment (uses gpt-4.1-mini for both agent and evaluator)
EVALUATOR_MODEL='openai:gpt-4.1-mini' \
LLM__DEFAULT_MODEL='openai:gpt-4.1-mini' \
rem experiments run claude-code-e2e-test

# 4. View results in Phoenix dashboard
open http://localhost:6006
```

## What This Demonstrates

An AI assistant can:
1. Read the experiments documentation (`PHOENIX_QUICKSTART.md`)
2. Create a new experiment with `rem experiments create`
3. Add ground truth data in JSONL format
4. Create an evaluator schema
5. Run the experiment with Phoenix integration
6. View results in the Phoenix dashboard

## How It Was Created

```bash
# Created the experiment
rem experiments create claude-code-e2e-test \
    --agent qa_assistant \
    --evaluator simple-qa \
    --description "End-to-end Phoenix evaluation test created by Claude Code"

# Created evaluator schema (evaluators/simple-qa.yaml)
# Added ground truth dataset (ground-truth/dataset.jsonl)
```

## Using a Custom LLM Model

Set environment variables to override the default models:

```bash
# Use gpt-4.1-mini for both agent and evaluator (cheaper/faster)
EVALUATOR_MODEL='openai:gpt-4.1-mini' \
LLM__DEFAULT_MODEL='openai:gpt-4.1-mini' \
rem experiments run claude-code-e2e-test

# Or use Claude for evaluator, GPT for agent
EVALUATOR_MODEL='anthropic:claude-sonnet-4-5-20250929' \
LLM__DEFAULT_MODEL='openai:gpt-4.1' \
rem experiments run claude-code-e2e-test
```

## Phoenix Dashboard

After running, view results at: http://localhost:6006

Navigate to Datasets > Experiments to see:
- All experiment runs with scores
- Side-by-side comparison of outputs
- Evaluation explanations

## Experiment Details

| Field | Value |
|-------|-------|
| **Agent** | `qa_assistant` |
| **Evaluator** | `simple-qa` |
| **Dataset** | 5 Q&A pairs (JSONL) |
| **Topics** | ML, APIs, Python vs JS, Version Control, Databases |

## Dataset Sample

```json
{"id": "1", "input": "What is machine learning?", "expected_output": "Machine learning is a subset of AI..."}
{"id": "2", "input": "Explain what an API is in simple terms", "expected_output": "An API is like a waiter..."}
```

## Evaluator Schema

The `simple-qa` evaluator scores responses on:
- Factual accuracy (vs expected output)
- Completeness
- Clarity

Pass threshold: score >= 0.6

## Screenshot

<!-- Add screenshot of Phoenix dashboard here -->

## Notes

- This experiment was created entirely by Claude Code following the documentation
- Phoenix is included in `docker-compose.prebuilt.yml` - no manual setup needed
- Evaluator credentials are validated before running expensive agent tasks
- Uses OpenAI gpt-4.1 by default (single API key for LLM + embeddings)
