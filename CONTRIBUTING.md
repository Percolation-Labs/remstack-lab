# Contributing to REM Stack Lab

We welcome contributions of new datasets, scenarios, and experiments!

## Dataset Contributions

### Structure

All datasets should follow this structure:

```
datasets/
├── domains/{domain_name}/
│   ├── README.md                    # Domain overview and use cases
│   └── scenarios/{scenario_name}/
│       ├── README.md                # Scenario-specific guide
│       ├── data.yaml                # Main dataset file
│       └── files/                   # Optional binary files
└── formats/{format_name}/
    ├── README.md                    # Format guide
    └── scenarios/{scenario_name}/
        ├── README.md
        └── example.yaml
```

### Dataset Guidelines

1. **Anonymize Data**: Use fictional names, companies, and content
2. **Clear Documentation**: Include comprehensive READMEs with:
   - Use case description
   - Sample queries
   - Expected outcomes
   - Data model explanation
3. **Consistent Naming**: Use kebab-case for files and directories
4. **Valid YAML**: Ensure all YAML files parse correctly
5. **User ID Scoping**: All entities should use `user_id` for data scoping
6. **Metadata**: Include `_metadata` section with version, description, counts

### Required Fields

**Metadata** (in all dataset YAML files):
```yaml
_metadata:
  version: "1.0.0"
  schema_version: "1.0.0"
  created_at: "2025-11-24"
  updated_at: "2025-11-24"
  description: "Brief description of dataset"
  user_id: "demo-user-or-domain-specific"
  entity_counts:
    users: 0
    resources: 0
    moments: 0
    messages: 0
    files: 0
    schemas: 0
```

**Entities** (all REM entities):
- `id`: UUID or string identifier
- `user_id`: Data scoping identifier
- `name` or `content`: Human-readable label or content
- `tags`: List of classification tags
- `metadata`: Dict of additional properties
- `graph_edges`: List of InlineEdge objects (optional but recommended)

### README Template

Each scenario should have a README with:

```markdown
# {Scenario Name}

## Overview
Brief description of the scenario and use case.

## What's Included
- X Users: [description]
- X Resources: [description]
- X Moments: [description]

## Loading the Dataset
```bash
rem db load --file path/to/data.yaml --user-id your-user-id
```

## Sample Queries
```bash
# Query 1
rem ask --user-id your-user-id "Question here"

# Query 2
rem ask --user-id your-user-id "Another question"
```

## Data Model
Explanation of entities, relationships, and graph structure.

## Next Steps
What users should try after loading the dataset.
```

## Testing Your Dataset

Before submitting:

1. **Validate YAML**:
   ```bash
   python -c "import yaml; yaml.safe_load(open('data.yaml'))"
   ```

2. **Load into REM**:
   ```bash
   rem db load --file data.yaml --user-id test-user
   ```

3. **Test Queries**:
   ```bash
   rem ask --user-id test-user "List all resources"
   rem ask --user-id test-user "Show me recent moments"
   ```

4. **Check Graph Edges**:
   ```bash
   rem db query "SELECT * FROM resources WHERE user_id = 'test-user' AND jsonb_array_length(graph_edges) > 0"
   ```

## Experiment Contributions

Experiments should be Jupyter notebooks demonstrating:

- Agent evaluation workflows
- Custom REM query patterns
- Integration with external tools
- Performance benchmarking
- Visualization examples

Place notebooks in `experiments/{category}/{name}.ipynb` with:
- Clear markdown documentation
- Inline code comments
- Expected outputs included
- Requirements listed at top

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-dataset`)
3. Add your dataset/experiment following structure above
4. Test thoroughly (see "Testing Your Dataset")
5. Commit with clear messages (`git commit -m "Add recruitment candidate pipeline dataset"`)
6. Push to your fork (`git push origin feature/my-dataset`)
7. Open a Pull Request with:
   - Description of dataset/experiment
   - Use case and target audience
   - Testing performed
   - Example queries and outputs

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and contribute
- Follow the established patterns and conventions

## Questions?

- Open an issue for questions or suggestions
- Tag as `question`, `dataset-request`, or `bug`
- Provide context and examples

## Recognition

Contributors will be listed in the README with their contributions. Thank you for helping make REM better!
