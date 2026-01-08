# REM Wiki Collections

Generated wiki representations of documents for use with REM's unified lookup and search system.

## Overview

This directory contains wikis generated from source documents. Each wiki transforms a document into a navigable knowledge graph with:

- **Entity Keys** - Single kebab-case identifiers (e.g., `automatic-thoughts`, `cbt-supervision`)
- **Hierarchical Structure** - Parent/child relationships via frontmatter
- **Cross-References** - Related links between conceptually connected pages
- **Semantic Search** - Content indexed for vector similarity search

## Available Wikis

### CBT Manual (`cbt-manual/`)

**Source**: A Therapist's Guide to Brief Cognitive Behavioral Therapy (111 pages)

**Structure**:
```
cbt-manual/
├── _index.md                              # brief-cbt-manual
├── modules/
│   ├── brief-cbt-introduction.md          # Module 1
│   ├── cbt-supervision.md                 # Module 2
│   ├── cbt-nonspecific-factors.md         # Module 3
│   ├── cbt-case-conceptualization.md      # Module 4
│   ├── cbt-patient-orientation.md         # Module 5
│   ├── cbt-goal-setting.md                # Module 6
│   ├── cbt-agenda-setting.md              # Module 7
│   ├── cbt-homework.md                    # Module 8
│   ├── identifying-maladaptive-thoughts.md   # Module 9
│   ├── challenging-maladaptive-thoughts.md   # Module 10
│   ├── cbt-behavioral-activation.md       # Module 11
│   ├── cbt-problem-solving.md             # Module 12
│   ├── cbt-relaxation.md                  # Module 13
│   └── cbt-ending-treatment.md            # Module 14
├── concepts/
│   ├── automatic-thoughts.md
│   ├── cognitive-distortions.md
│   ├── core-beliefs.md
│   ├── thought-records.md
│   ├── socratic-questioning.md
│   └── behavioral-activation.md
├── references/
│   └── cbt-suggested-readings.md
└── chunks/                                # Raw page extractions (111 files)
    ├── _toc.md
    └── page_*.md
```

**Stats**: 22 wiki pages + 111 page chunks

## How to Use

### Load into REM Database

Use `rem process ingest` to load wiki files into the `ontologies` table:

```bash
# Navigate to remstack-lab directory
cd /path/to/remstack-lab

# Load wiki into ontologies table (PUBLIC by default)
# Uses the remstack/rem project for the rem CLI
POSTGRES__CONNECTION_STRING="postgresql://rem:rem@localhost:5050/rem" \
  uv run --project /path/to/remstack/rem \
  rem process ingest wiki/cbt-manual/ --table ontologies --pattern "**/*.md"

# Dry run to preview what would be loaded
POSTGRES__CONNECTION_STRING="postgresql://rem:rem@localhost:5050/rem" \
  uv run --project /path/to/remstack/rem \
  rem process ingest wiki/cbt-manual/ --table ontologies --pattern "**/*.md" --dry-run
```

**Key Points:**
- Data is PUBLIC by default (tenant_id="public") - no user-id needed
- The `--table ontologies` flag writes directly to the ontologies table
- Entity keys are derived from filenames (e.g., `automatic-thoughts.md` → `automatic-thoughts`)
- Embeddings are generated automatically for semantic search

### Verify Loading

```sql
-- Check loaded ontologies
SELECT name, LEFT(content, 80) as preview FROM ontologies
WHERE tenant_id='public' ORDER BY name;

-- Check KV store for LOOKUP access
SELECT entity_key, entity_type FROM kv_store
WHERE entity_type='ontologies' ORDER BY entity_key;
```

### Navigation Methods

#### LOOKUP - Direct Entity Access

```python
# Get a specific page by its entity key
page = rem.lookup("automatic-thoughts")
print(page.content)
```

#### SEARCH - Semantic Discovery

```python
# Find pages semantically related to a query
results = rem.search("how to challenge negative thinking patterns")
for result in results:
    print(f"{result.entity_key}: {result.score}")
```

#### TRAVERSE - Graph Navigation

```python
# Follow relationships
children = rem.traverse("cbt-essential-skills", relation="children")
related = rem.traverse("automatic-thoughts", relation="related")
```

### Link Syntax

Pages use standard markdown links with relative paths:

```markdown
See [Automatic Thoughts](./concepts/automatic-thoughts.md) for details.
```

Format: `[Display Text](./relative/path.md)`

## Generating New Wikis

### Step 1: Split the PDF

```bash
# Get PDF info first
python scripts/split_pdf.py document.pdf --info

# Split into page chunks
python scripts/split_pdf.py document.pdf --output-dir wiki/my-wiki/chunks/
```

### Step 2: Generate Wiki Structure

```bash
# Generate wiki from chunks (v2 uses single kebab-case keys)
python scripts/generate_wiki_v2.py wiki/my-wiki/chunks/ --output wiki/my-wiki/
```

### Step 3: Enhance with Concepts

Manually create concept pages in `wiki/my-wiki/concepts/` to extract and cross-reference key ideas.

### Step 4: Load into REM

```bash
# Load wiki into ontologies table
POSTGRES__CONNECTION_STRING="postgresql://rem:rem@localhost:5050/rem" \
  uv run --project /path/to/remstack/rem \
  rem process ingest wiki/my-wiki/ --table ontologies --pattern "**/*.md"
```

## Frontmatter Schema

Each wiki page includes YAML frontmatter:

```yaml
---
entity_key: automatic-thoughts    # Required: single kebab-case identifier
title: Automatic Thoughts         # Required: display title
parent: cbt-essential-skills      # Optional: parent entity_key
children:                         # Optional: child entity_keys
  - thought-records
related:                          # Optional: related entity_keys
  - cognitive-distortions
  - identifying-maladaptive-thoughts
tags:                             # Optional: categorization
  - concept
  - cognitive
source:                           # Optional: provenance
  document: source.pdf
  pages: 43-45
---
```

## Entity Key Naming Strategy

- **Single terms** - No paths (like Wikipedia article names)
- **Kebab-case** - Lowercase with hyphens
- **Qualified when needed** - Use prefix for source-specific content:
  - `cbt-relaxation` (CBT-specific relaxation module)
  - `ptsd-relaxation` (PTSD-specific relaxation content)
- **Generic for universal concepts** - `automatic-thoughts`, `cognitive-distortions`

## Benefits Over Traditional RAG

| Aspect | Traditional RAG | Wiki System |
|--------|----------------|-------------|
| Retrieval | Chunk similarity only | LOOKUP + SEARCH + TRAVERSE |
| Context | Isolated chunks | Full page + structural context |
| Navigation | None | Explicit hierarchy + links |
| Citations | Chunk IDs | Semantic entity keys |
| Discovery | Query-dependent | Browse + search combined |

## Related Documentation

- [Wiki System Documentation](../docs/wiki-system.md) - Full theory and design
- [PDF Processing Scripts](../scripts/) - Splitting and generation tools
