# Ground Truth Dataset

This directory contains Q&A pairs for evaluating the agent.

## Format

**CSV format** (`dataset.csv`):
```csv
input,expected_output,metadata
"What is the capital of France?","Paris","{"difficulty": "easy"}"
```

**YAML format** (`dataset.yaml`):
```yaml
- input: "What is the capital of France?"
  expected_output: "Paris"
  metadata:
    difficulty: easy
```

## Generating Ground Truth

### Using AI Assistants

AI coding assistants (like Claude, GPT-4, etc.) can help generate comprehensive ground-truth datasets:

1. **Generate from existing examples**: Show the assistant examples from your domain and ask it to create similar Q&A pairs
2. **Create challenging questions**: Ask the assistant to act as a judge and generate HARD questions that test edge cases
3. **Vary difficulty levels**: Request a mix of easy, medium, and hard questions with appropriate metadata tags

Example prompt:
```
Based on these example documents about [your domain], generate 20 Q&A pairs
for evaluating an agent. Include:
- 5 easy factual questions
- 10 medium questions requiring reasoning
- 5 hard questions with edge cases
Format as CSV with difficulty and category metadata.
```

### Ground Truth as Judge

**Important**: Keep ground-truth data **separate** from the agent being tested:
- Ground truth should be hidden from the agent during evaluation
- The agent should only see the `input` field
- The evaluator compares agent output against `expected_output`
- This ensures unbiased evaluation

### Quality Guidelines

1. **Diverse Coverage**: Include various question types and difficulty levels
2. **Domain-Specific**: Use terminology and scenarios from your actual use case
3. **Metadata Tags**: Add difficulty, category, priority for analysis
4. **SME Review**: Have domain experts validate expected outputs

## Usage

These datasets can be:
- Loaded into evaluation frameworks (Arize Phoenix, etc.)
- Used for regression testing
- Converted to different formats as needed

The experiment runner will automatically use this data for evaluation.
