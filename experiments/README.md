# REM Experiments

This directory contains experiment configurations for evaluating REM agents systematically.

## Overview

Experiments in REM provide a structured way to:
- Evaluate agent performance with ground-truth Q&A datasets
- Track evaluation metrics over time
- Seed REM with test data for reproducible experiments
- Integrate with evaluation frameworks (Arize Phoenix, etc.)

## Directory Structure

Each experiment follows this structure:

```
experiments/{experiment-name}/
├── experiment.yaml          # ExperimentConfig (metadata, agent ref, evaluator ref)
├── README.md                # Auto-generated documentation
├── ground-truth/            # Evaluation datasets (Q&A pairs)
│   ├── dataset.csv          # Input/output pairs for evaluation
│   ├── dataset.yaml         # Alternative YAML format
│   └── README.md            # Format documentation
├── seed-data/              # Data to seed REM before running experiments
│   ├── data.yaml           # Users, resources, moments in REM format
│   └── README.md           # Format documentation
└── results/                # Experiment results and metrics
    └── {run-timestamp}/    # Each run gets its own timestamped folder
        ├── metrics.json    # Summary metrics
        └── run_info.json   # Run metadata (eval framework URLs, etc)
```

## Quick Start

### 1. Create an Experiment

```bash
# Navigate to your experiments directory
cd remstack-lab

# Create a new experiment
rem experiments create my-agent-eval \
    --agent my-agent \
    --evaluator default \
    --description "Evaluation of my-agent on Q&A task"
```

This creates the complete directory structure in `experiments/my-agent-eval/`.

### 2. Add Ground Truth Data

Create your Q&A dataset in `experiments/my-agent-eval/ground-truth/dataset.csv`:

```csv
input,expected_output,metadata
"What documents are available?","There are 3 documents: design.md, api_spec.md, and notes.txt","{\"difficulty\": \"easy\", \"category\": \"lookup\"}"
"Summarize the API spec","The API provides REST endpoints for...","{\"difficulty\": \"medium\", \"category\": \"summarization\"}"
```

Or use YAML format (`dataset.yaml`):

```yaml
- input: "What documents are available?"
  expected_output: "There are 3 documents: design.md, api_spec.md, and notes.txt"
  metadata:
    difficulty: easy
    category: lookup

- input: "Summarize the API spec"
  expected_output: "The API provides REST endpoints for..."
  metadata:
    difficulty: medium
    category: summarization
```

**Using AI Assistants to Generate Ground Truth**:

AI coding assistants can help generate comprehensive evaluation datasets:

```
Prompt: "Based on the examples in datasets/domains/recruitment/, generate 20 Q&A
pairs for evaluating a CV parser agent. Include 5 easy factual questions,
10 medium reasoning questions, and 5 hard edge cases. Format as CSV with
difficulty and category metadata."
```

The AI assistant can act as a **judge** to create challenging questions that test edge cases. Keep ground-truth data **separate** from the agent being tested - the agent should only see the `input` field during evaluation.

### 3. Add Seed Data (Optional)

If your agent needs pre-loaded REM data, add it to `experiments/my-agent-eval/seed-data/data.yaml`:

```yaml
users:
  - id: test-user-001
    user_id: experiment-test
    email: test@example.com

resources:
  - id: resource-001
    user_id: experiment-test
    label: design-doc
    content: "# Design Document\n\nThis is our system design..."
    tags: [design, architecture]

  - id: resource-002
    user_id: experiment-test
    label: api-spec
    content: "# API Specification\n\nREST endpoints..."
    tags: [api, documentation]

moments:
  - id: moment-001
    user_id: experiment-test
    label: design-review-meeting
    content: "Team discussed the new architecture..."
    starts_timestamp: "2024-01-15T14:00:00"
```

**Using AI Assistants to Generate Seed Data**:

```
Prompt: "Based on datasets/domains/recruitment/ examples, generate seed data
for testing a CV parser. Include 3 users, 5 CV resources with varied experience,
and 2 interview moments. Use fictional names and anonymize all content."
```

Load this data before running the experiment:

```bash
rem db load --file experiments/my-agent-eval/seed-data/data.yaml --user-id experiment-test
```

### 4. Run the Experiment

```bash
rem experiments run my-agent-eval
```

Results will be saved to `experiments/my-agent-eval/results/{timestamp}/`.

## Environment Configuration

### EXPERIMENTS_HOME

By default, REM looks for experiments in the `experiments/` directory. You can override this:

```bash
# Use a custom location
export EXPERIMENTS_HOME=/path/to/my/experiments
rem experiments create my-test --agent my-agent

# Or specify per-command
rem experiments create my-test --agent my-agent --base-path /custom/path
```

**Recommended Setup for remstack-lab**:
When working in this repository, REM commands will automatically use the `experiments/` directory, making it easy to run experiments alongside the example datasets.

## Integration with Evaluation Frameworks

### Arize Phoenix

The ground-truth datasets can be loaded into Phoenix for evaluation:

```bash
# Create Phoenix dataset from ground-truth CSV
rem experiments dataset create my-agent-eval-dataset \
    --from-csv experiments/my-agent-eval/ground-truth/dataset.csv \
    --input-keys input \
    --output-keys expected_output \
    --metadata-keys metadata
```

Then run experiments through Phoenix:

```bash
# Set Phoenix connection (optional, defaults to localhost:6006)
export PHOENIX_BASE_URL=http://phoenix.example.com:6006
export PHOENIX_API_KEY=your-api-key

# Run experiment (will automatically create Phoenix experiment)
rem experiments run my-agent-eval
```

After the run completes, you'll get a Phoenix URL to view detailed results.

### Other Frameworks

The ground-truth format (CSV/YAML with input/expected_output) is framework-agnostic. You can:

1. **Custom Evaluation**: Write your own evaluation scripts that read `ground-truth/dataset.csv`
2. **Convert Formats**: Transform the data for other eval frameworks
3. **Regression Testing**: Use ground-truth as test cases in CI/CD

Example custom evaluation:

```python
import pandas as pd
from rem.agentic import Agent

# Load ground truth
df = pd.read_csv("experiments/my-agent-eval/ground-truth/dataset.csv")

# Run agent on each input
agent = Agent.from_schema("my-agent")
results = []

for _, row in df.iterrows():
    output = agent.run(row["input"])
    results.append({
        "input": row["input"],
        "expected": row["expected_output"],
        "actual": output,
        "match": output == row["expected_output"]
    })

# Calculate metrics
accuracy = sum(r["match"] for r in results) / len(results)
print(f"Accuracy: {accuracy:.2%}")
```

## Experiment Lifecycle

### 1. Draft Phase

When created, experiments start in `DRAFT` status. This is the time to:
- Finalize ground-truth datasets
- Review seed data
- Test the experiment setup

### 2. Running Experiments

```bash
# Run experiment
rem experiments run my-agent-eval

# Dry run (test without saving to eval framework)
rem experiments run my-agent-eval --dry-run

# Run specific version (from Git)
rem experiments run my-agent-eval --version experiments/my-agent-eval/v1.0.0
```

### 3. Reviewing Results

Results are stored in timestamped directories:

```bash
experiments/my-agent-eval/results/
├── 20250124-143022/
│   ├── metrics.json      # Accuracy, latency, cost, etc.
│   └── run_info.json     # Phoenix URL, experiment ID, etc.
└── 20250124-150815/
    ├── metrics.json
    └── run_info.json
```

Example `metrics.json`:

```json
{
  "experiment_id": "exp_abc123",
  "experiment_name": "my-agent-eval-20250124-143022",
  "agent": "my-agent",
  "evaluator": "default",
  "dataset_size": 50,
  "completed_at": "2025-01-24T14:32:15",
  "task_runs": 50,
  "accuracy": 0.94,
  "avg_latency_ms": 850,
  "total_cost_usd": 0.42
}
```

### 4. Versioning and Git

Commit experiments to Git for reproducibility:

```bash
# Add experiment
git add experiments/my-agent-eval/

# Commit
git commit -m "Add my-agent-eval experiment with 50 Q&A pairs"

# Tag for versioning
git tag -a experiments/my-agent-eval/v1.0.0 -m "Initial eval dataset"
git push origin experiments/my-agent-eval/v1.0.0
```

Later, you can run specific versions:

```bash
rem experiments run my-agent-eval --version experiments/my-agent-eval/v1.0.0
```

## Managing Experiments

### List Experiments

```bash
# List all experiments
rem experiments list

# Filter by status
rem experiments list --status completed

# Filter by tags
rem experiments list --tags production,cv-parser
```

### Show Experiment Details

```bash
rem experiments show my-agent-eval
```

Output:

```
Experiment: my-agent-eval
============================================================

Description: Evaluation of my-agent on Q&A task
Status: completed
Tags: evaluation, qa

Agent Schema:
  Name: my-agent
  Version: latest

Evaluator Schema:
  Name: default

Datasets:
  ground_truth:
    Location: git
    Path: ground-truth/dataset.csv
    Format: csv

Results:
  Location: git
  Base Path: results/
  Save Traces: false
  Metrics File: metrics.json

Timestamps:
  Created: 2025-01-24T14:00:00
  Updated: 2025-01-24T14:32:15
  Last Run: 2025-01-24T14:32:15
```

## Using AI Assistants for Experiment Generation

### AI as a Judge

AI coding assistants (Claude, GPT-4, etc.) can serve as **judges** to create rigorous evaluation datasets:

**Generate Hard Questions**:
```
Prompt: "Act as an expert evaluator. Generate 10 HARD edge case questions
for testing a [domain] agent. Include scenarios that would trip up most agents:
ambiguous inputs, contradictory information, missing context, etc."
```

**Create Varied Difficulty Levels**:
```
Prompt: "Create a comprehensive evaluation dataset with:
- 5 trivial questions (baseline sanity check)
- 10 easy questions (basic functionality)
- 15 medium questions (typical use cases)
- 10 hard questions (edge cases and ambiguity)
Format as CSV with difficulty tags."
```

**Generate Domain-Specific Scenarios**:
```
Prompt: "Based on the examples in datasets/domains/[domain]/, generate
realistic evaluation scenarios. Include both positive and negative cases.
Add metadata for difficulty, scenario type, and expected failure modes."
```

### Key Principle: Separation of Concerns

**Ground truth must be hidden from the agent being evaluated**:
- ✅ Agent sees: `input` field only
- ❌ Agent should NOT see: `expected_output` or ground-truth metadata
- ✅ Evaluator compares: agent output vs `expected_output`

This ensures unbiased evaluation and prevents data leakage.

### Generating Seed Data with AI

AI assistants can create realistic context data:

```
Prompt: "Generate anonymized seed data for [use case]. Include:
- Realistic but fictional names and organizations
- Varied content complexity (simple to complex)
- Appropriate metadata and tags
- Graph relationships between entities
Format as REM YAML with users, resources, and moments."
```

## Best Practices

### Ground Truth Quality

1. **Diverse Coverage**: Include easy, medium, and hard examples
2. **Metadata Tags**: Add difficulty, category, and other useful tags
3. **Regular Updates**: Expand ground-truth as you find edge cases
4. **SME Review**: Have subject matter experts validate expected outputs
5. **AI-Assisted Generation**: Use AI to create challenging edge cases

Example metadata usage:

```csv
input,expected_output,metadata
"Easy question","Simple answer","{\"difficulty\": \"easy\", \"category\": \"factual\", \"priority\": \"high\"}"
"Complex question requiring reasoning","Detailed answer","{\"difficulty\": \"hard\", \"category\": \"reasoning\", \"priority\": \"medium\"}"
```

### Seed Data Management

1. **Minimal Data**: Only include data necessary for the experiment
2. **Anonymize**: Use fictional names, emails, and content
3. **Version Control**: Track changes to seed data in Git
4. **Reproducibility**: Ensure experiments can be re-run with same seed data

### Results Organization

1. **Never Delete Results**: Keep all timestamped runs for comparison
2. **Regular Cleanup**: Archive very old results to separate storage
3. **Document Changes**: When updating ground-truth, note it in Git commit
4. **Metrics Tracking**: Plot metrics over time to track improvements

### Git Workflow

```bash
# Standard workflow
git checkout -b experiment/my-agent-eval
rem experiments create my-agent-eval --agent my-agent
# ... add ground-truth and seed-data ...
rem experiments run my-agent-eval
git add experiments/my-agent-eval/
git commit -m "Add my-agent-eval experiment"
git push origin experiment/my-agent-eval
# Create PR for review
```

## Advanced: Hybrid Storage (Git + S3)

For large datasets or trace storage, use hybrid mode:

```bash
rem experiments create large-eval \
    --agent my-agent \
    --dataset-location s3 \
    --results-location hybrid \
    --description "Large-scale evaluation with trace storage"
```

This stores:
- **In Git**: Configuration, READMEs, small metadata
- **In S3**: Large datasets, full traces, detailed results

Configuration is managed via `experiment.yaml` and REM's FS provider.

## Troubleshooting

### Experiment Not Found

```bash
rem experiments list
# Verify your experiment is listed

# Check EXPERIMENTS_HOME
echo $EXPERIMENTS_HOME

# Use explicit path
rem experiments show my-agent-eval --base-path /path/to/experiments
```

### Dataset Loading Errors

```bash
# Validate CSV format
python -c "import pandas as pd; df = pd.read_csv('experiments/my-agent-eval/ground-truth/dataset.csv'); print(df.head())"

# Validate YAML format
python -c "import yaml; print(yaml.safe_load(open('experiments/my-agent-eval/seed-data/data.yaml')))"
```

### Phoenix Connection Issues

```bash
# Test Phoenix connection
curl http://localhost:6006/graphql

# Check environment variables
echo $PHOENIX_BASE_URL
echo $PHOENIX_API_KEY

# Use explicit connection
rem experiments run my-agent-eval \
    --phoenix-url http://phoenix.example.com:6006 \
    --phoenix-api-key your-key
```

## Examples

This repository includes example experiments in the `experiments/` directory:

- **hello-world-validation**: Simple smoke test for basic agents
- **cv-parser-eval**: Recruitment domain CV parsing evaluation
- **contract-analyzer-eval**: Legal domain contract analysis evaluation

Browse these examples to understand the structure and best practices.

## Contributing

When adding experiments to remstack-lab:

1. Follow the standard directory structure
2. Include comprehensive ground-truth datasets (minimum 20 examples)
3. Add README.md explaining the experiment purpose
4. Anonymize all data (use fictional content)
5. Test the experiment before committing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed guidelines.

## Learn More

- **REM Documentation**: [remstack/rem/README.md](https://github.com/Percolation-Labs/remstack/blob/main/rem/README.md)
- **Agent Schemas**: [remstack/rem/schemas/agents/](https://github.com/Percolation-Labs/remstack/tree/main/rem/schemas/agents)
- **Evaluator Schemas**: [remstack/rem/schemas/evaluators/](https://github.com/Percolation-Labs/remstack/tree/main/rem/schemas/evaluators)
- **Arize Phoenix**: [docs.arize.com/phoenix](https://docs.arize.com/phoenix)

## Questions?

Open an issue at [github.com/Percolation-Labs/remstack-lab/issues](https://github.com/Percolation-Labs/remstack-lab/issues)
