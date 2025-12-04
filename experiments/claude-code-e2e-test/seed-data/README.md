# Seed Data

This directory contains REM data to load before running the experiment.

## Format

Use standard REM YAML format:

```yaml
users:
  - id: test-user-001
    user_id: experiment-test
    email: test@example.com

resources:
  - id: resource-001
    user_id: experiment-test
    label: example-document
    content: "Document content here..."

moments:
  - id: moment-001
    user_id: experiment-test
    label: example-meeting
    starts_timestamp: "2024-01-15T14:00:00"
```

## Generating Seed Data

### Using AI Assistants

AI coding assistants can help generate realistic seed data for your experiments:

1. **From existing datasets**: Reference examples from the `datasets/` directory
2. **Domain-specific scenarios**: Describe your use case and ask for appropriate test data
3. **Anonymized versions**: Ask to create fictional data based on real patterns

Example prompt:
```
Based on the recruitment dataset examples in datasets/domains/recruitment/,
generate seed data for testing a CV parser agent. Include:
- 3 test users
- 5 CV documents (resources) with varied experience levels
- 2 interview moment entries
Use fictional names and anonymize all content.
```

### Best Practices

1. **Minimal**: Only include data necessary for the ground-truth questions to be answerable
2. **Anonymized**: Always use fictional names, companies, and content
3. **Relevant**: Seed data should provide context for evaluation questions
4. **Versioned**: Track changes to seed data in Git for reproducibility

## Usage

Load this data before running experiments:
```bash
rem db load --file seed-data/data.yaml --user-id experiment-test
```

This ensures your agent has the necessary context for evaluation.
