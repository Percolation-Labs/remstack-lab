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

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install tesseract-ocr

# Fedora/RHEL
sudo dnf install tesseract

# Windows (using Chocolatey)
choco install tesseract
```

**Python Package:**

```bash
# Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install remdb (note: quotes required for zsh)
pip install "remdb[all]"

# Configure (interactive wizard)
rem configure --install

# Or non-interactive with defaults
rem configure --yes --install
```

### Load Your First Dataset

```bash
# Clone this repository
git clone https://github.com/Percolation-Labs/remstack-lab.git
cd remstack-lab

# Activate your virtual environment (if not already active)
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Start PostgreSQL with docker-compose
curl -O https://gist.githubusercontent.com/percolating-sirsh/d117b673bc0edfdef1a5068ccd3cf3e5/raw/docker-compose.prebuilt.yml
docker compose -f docker-compose.prebuilt.yml up -d postgres

# Load quickstart dataset
rem db load datasets/quickstart/sample_data.yaml --user-id default

# Optional: Set default LLM provider via environment variable
# export LLM__DEFAULT_MODEL="openai:gpt-4.1-nano"  # Fast and cheap
# export LLM__DEFAULT_MODEL="anthropic:claude-sonnet-4-5-20250929"  # High quality (default)

# Ask questions
rem ask --user-id default "What documents exist in the system?"
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
rem db load \
  --file datasets/domains/recruitment/scenarios/candidate_pipeline/data.yaml \
  --user-id acme-corp

# Verify data loaded
rem ask --user-id acme-corp "List all candidates"
```

### Work from This Directory

We recommend cloning this repository and running REM commands from here:

```bash
# Clone the lab
git clone https://github.com/Percolation-Labs/remstack-lab.git
cd remstack-lab

# Set up virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install "remdb[all]"

# Set up your environment
export USER_ID="your-company-id"

# Load multiple datasets
rem db load --file datasets/quickstart/sample_data.yaml --user-id $USER_ID
rem db load --file datasets/domains/enterprise/scenarios/team_collaboration/data.yaml --user-id $USER_ID

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
rem db load --file datasets/domains/misc/scenarios/my_scenario/data.yaml --user-id test-user
```

## Contributing

We welcome dataset contributions! Please:

1. Follow the existing structure (domains → scenarios → data.yaml + README.md)
2. Include a comprehensive README explaining the use case
3. Anonymize any real data (use fictional names, companies, content)
4. Add sample queries demonstrating the dataset
5. Tag with appropriate metadata

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

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

## License

MIT License - see [LICENSE](LICENSE) for details.

All example data is fictional and for demonstration purposes only.
