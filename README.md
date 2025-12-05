# REM Stack Lab

Example datasets, experiments, and tutorials for [remdb](https://pypi.org/project/remdb/) - the unified memory infrastructure for AI agents.

## What's Inside

- **datasets/** - Curated example datasets organized by domain and format
- **experiments/** - Jupyter notebooks, evaluation experiments, and tutorials

## Quick Start

### Prerequisites

**System Dependencies:**

```bash
# macOS
brew install tesseract
```

**Docker:**

Docker is required to run PostgreSQL. Make sure Docker is installed and running.

### Step 1: Start PostgreSQL

```bash
# Clone this repository
git clone https://github.com/Percolation-Labs/remstack-lab.git
cd remstack-lab

# Download and start PostgreSQL (port 5051)
curl -O https://gist.githubusercontent.com/percolating-sirsh/d117b673bc0edfdef1a5068ccd3cf3e5/raw/docker-compose.prebuilt.yml
docker compose -f docker-compose.prebuilt.yml up -d postgres

# To reset and start fresh (removes all data):
# docker compose -f docker-compose.prebuilt.yml down -v
```

### Step 2: Install REM

```bash
# Create and activate a virtual environment
# Use Python 3.11 or 3.12 matching your platform architecture (arm64/x86_64)
# macOS ARM: /opt/homebrew/Cellar/python@3.12/*/bin/python3.12 -m venv .venv
# macOS x86: /usr/local/bin/python3 -m venv .venv
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install remdb (note: quotes required for zsh)
pip install "remdb[all]" -U

# Configure and install database schema (non-interactive)
rem configure --yes --install
```

### Step 3: Load Data and Query

```bash
# Load quickstart dataset
rem db load datasets/quickstart/sample_data.yaml

# Ask questions
rem ask "What documents exist in the system?"

# Optional: Set default LLM provider via environment variable
# export LLM__DEFAULT_MODEL="openai:gpt-4.1-nano"  # Fast and cheap
# export LLM__DEFAULT_MODEL="anthropic:claude-sonnet-4-5-20250929"  # High quality (default)
```

## Repository Structure

```
remstack-lab/
├── datasets/
│   ├── quickstart/          # Minimal datasets for getting started
│   ├── domains/             # Domain-specific datasets
│   │   ├── recruitment/     # CV parsing, candidate tracking
│   │   ├── legal/          # Contract analysis, NDA processing
│   │   ├── enterprise/     # Team collaboration, knowledge bases
│   │   └── misc/           # General examples
│   ├── formats/            # Format-specific examples
│   │   ├── engrams/        # Voice memos, personal reflections
│   │   ├── documents/      # Markdown, PDF, text documents
│   │   ├── conversations/  # Chat logs, meeting transcripts
│   │   └── files/          # Binary file examples
│   └── evaluation/         # Golden datasets for Phoenix evaluations
└── experiments/            # Notebooks and tutorials
```

## Datasets

### Quickstart
Minimal datasets to get started with REM in under 5 minutes. Includes sample users, resources, moments, and agent schemas.

**Use case**: First-time users learning REM concepts.

### Domains

#### Recruitment
CV parsing, candidate tracking, interview notes, and hiring pipeline data.

**Use case**: Recruitment agencies, HR departments, talent acquisition teams.

**Schemas**: `cv-parser-v1.yaml` for structured candidate extraction.

#### Legal
Contract analysis, NDA processing, legal document classification, and risk assessment.

**Use case**: Law firms, legal departments, contract management systems.

**Schemas**: `contract-analyzer-v1.yaml` for extracting parties, obligations, and risks.

#### Enterprise
Team collaboration data including meeting notes, project documentation, sprint retrospectives, and design reviews.

**Use case**: Software teams, product organizations, knowledge management systems.

**Schemas**: `rem-assistant.yaml` for general knowledge retrieval.

#### Misc
General-purpose examples not tied to specific domains. Great for learning REM query patterns.

**Use case**: Developers exploring REM capabilities.

### Formats

#### Engrams
Personal memory units: voice memos, reflections, ideas, quick notes.

**Structure**: Time-stamped, speaker-attributed, emotion-tagged.

**Format**: YAML with audio transcripts or standalone text.

#### Documents
Structured documents: API specs, meeting notes, design docs, research papers.

**Formats**: Markdown, PDF, TXT.

#### Conversations
Multi-turn dialogues: chat logs, meeting transcripts, support tickets.

**Structure**: Speaker-attributed, chronologically ordered messages.

#### Files
Binary file examples with metadata: images, audio, video, PDFs.

**Use case**: Testing file processing pipeline and content extraction.

### Evaluation
Golden datasets for systematic agent testing with Arize Phoenix.

**Contents**:
- `rem_lookup_golden.csv` - Test LOOKUP query correctness
- `rem_search_golden.csv` - Test SEARCH semantic retrieval
- `rem_traverse_golden.csv` - Test graph traversal

See [Evaluation Framework](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/services/phoenix/README.md) for usage.

## Using Datasets

### Load a Dataset

```bash
# Load domain-specific dataset
rem db load datasets/domains/recruitment/scenarios/candidate_pipeline/data.yaml

# Verify data loaded
rem ask "List all candidates"
```

### Work from This Directory

We recommend cloning this repository and running REM commands from here:

```bash
# Clone the lab
git clone https://github.com/Percolation-Labs/remstack-lab.git
cd remstack-lab

# Start PostgreSQL (if not already running)
docker compose -f docker-compose.prebuilt.yml up -d postgres

# Set up virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install "remdb[all]"

# Initialize database
rem configure --yes --install

# Load multiple datasets
rem db load datasets/quickstart/sample_data.yaml
rem db load datasets/domains/enterprise/scenarios/team_collaboration/data.yaml

# Run experiments
jupyter notebook experiments/
```

### Create Your Own Dataset

Each domain has a template and README. Copy a scenario and customize:

```bash
# Copy a scenario template
cp -r datasets/domains/misc/scenarios/template datasets/domains/misc/scenarios/my_scenario

# Edit the data
vim datasets/domains/misc/scenarios/my_scenario/data.yaml

# Load and test
rem db load datasets/domains/misc/scenarios/my_scenario/data.yaml
```

## Contributing

We welcome dataset contributions! Please:

1. Follow the existing structure (domains → scenarios → data.yaml + README.md)
2. Include a comprehensive README explaining the use case
3. Anonymize any real data (use fictional names, companies, content)
4. Add sample queries demonstrating the dataset
5. Tag with appropriate metadata

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Custom Agents

REM supports custom agents that use `search_rem` to query your knowledge base. Agents are defined in YAML and can be used via the CLI.

### Agent Structure

```
remstack-lab/
├── agents/
│   └── team-assistant.yaml    # Custom agent definition
├── datasets/
└── ...
```

### Example: Team Knowledge Assistant

The included `agents/team-assistant.yaml` is a custom agent for the quickstart dataset:

```yaml
# agents/team-assistant.yaml
type: object
description: |
  # Team Knowledge Assistant

  You are a helpful team assistant that helps engineers find information across
  team documentation, design docs, retrospectives, and project artifacts.

  ## When to Use Tools

  **Use search_rem** when the user asks about:
  - Team documents, design docs, or technical specifications
  - Past decisions, retrospectives, or meeting notes
  - Who worked on what, team members, or expertise areas
  ...

json_schema_extra:
  kind: agent
  name: team-assistant
  version: "1.0.0"
  structured_output: false
  mcp_servers:
    - type: local
      module: rem.mcp_server
      id: rem-local
  tools:
    - name: search_rem
      description: Search team knowledge base
```

### Using Custom Agents

```bash
# Register your agents directory
export SCHEMA__PATHS="./agents"

# Or add to ~/.rem/config.yaml:
# schema:
#   paths:
#     - ./agents

# Use the custom agent (first arg is agent name, second is query)
rem ask team-assistant "What did we decide about API design?"

# The agent will use search_rem to find relevant documents
rem ask team-assistant "Who worked on the frontend refactor?"

# Compare with the default rem agent
rem ask "What documents exist?"
```

### Creating Your Own Agent

1. Copy an existing agent as a template:
```bash
cp agents/team-assistant.yaml agents/my-agent.yaml
```

2. Edit the description to define your agent's personality and behavior:
   - When to use `search_rem` vs general knowledge
   - Which tables to search (resources, moments, users, messages)
   - Query strategies and examples
   - Response style guidelines

3. Configure the tools and resources:
```yaml
json_schema_extra:
  kind: agent
  name: my-agent
  tools:
    - name: search_rem
      description: Your tool description
  resources:
    - uri: rem://resources?category=your-category
      name: Your Resources
```

4. Test your agent:
```bash
export SCHEMA__PATHS="./agents"
rem ask my-agent "Test query"
```

## Data Format

All datasets use YAML with the following structure:

```yaml
users:
  - id: user-001
    user_id: acme-corp
    email: alice@example.com
    # ... more fields

resources:
  - id: resource-001
    user_id: acme-corp
    label: api-design-v2
    content: "# API Design Document..."
    # ... more fields

moments:
  - id: moment-001
    user_id: acme-corp
    label: q4-retrospective
    starts_timestamp: "2024-10-15T14:00:00"
    # ... more fields
```

See [REM Data Model](https://github.com/Percolation-Labs/remstack/blob/main/rem/README.md#data-model) for complete schema documentation.

## Learn More

- **Main Repository**: [Percolation-Labs/remstack](https://github.com/Percolation-Labs/remstack)
- **PyPI Package**: [remdb](https://pypi.org/project/remdb/)
- **Documentation**: [rem/README.md](https://github.com/Percolation-Labs/remstack/blob/main/rem/README.md)
- **REM Query Language**: [Query Guide](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/models/core/README.md)

## Arize Phoenix Integration

[Arize Phoenix](https://github.com/Arize-ai/phoenix) provides LLM observability, tracing, and experiment evaluation. Phoenix is **included by default** in `docker-compose.prebuilt.yml`.

### Quick Start

```bash
# Start everything (postgres, phoenix, api)
docker compose -f docker-compose.prebuilt.yml up -d

# Or start just Phoenix for experiments
docker compose -f docker-compose.prebuilt.yml up -d phoenix
```

Access the Phoenix UI at: http://localhost:6006

### Running Experiments

See [experiments/PHOENIX_QUICKSTART.md](experiments/PHOENIX_QUICKSTART.md) for the full guide.

```bash
# Set your OpenAI API key
export OPENAI_API_KEY='your-key'

# Run an experiment with gpt-4.1-mini (cheaper/faster)
EVALUATOR_MODEL='openai:gpt-4.1-mini' \
LLM__DEFAULT_MODEL='openai:gpt-4.1-mini' \
rem experiments run my-experiment
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EVALUATOR_MODEL` | LLM model for evaluations | `claude-sonnet-4-5-20250929` |
| `LLM__DEFAULT_MODEL` | Default LLM for agents | `openai:gpt-4.1` |
| `OTEL__ENABLED` | Enable OpenTelemetry tracing | `true` |
| `OTEL__COLLECTOR_ENDPOINT` | Phoenix OTLP endpoint | `http://phoenix:6006` |

### Features

- Real-time trace visualization
- LLM call inspection (inputs, outputs, latency)
- Experiment tracking and comparison
- LLM-as-Judge evaluations

For cloud deployment, consider [Arize Phoenix Cloud](https://phoenix.arize.com/)

## License

MIT License - see [LICENSE](LICENSE) for details.

All example data is fictional and for demonstration purposes only.
