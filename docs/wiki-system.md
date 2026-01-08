# REM Wiki System

A knowledge representation system that transforms documents into navigable, semantically-connected wikis using REM's unified lookup and search capabilities.

## Overview

The Wiki System bridges **structured entity lookup** with **semantic vector search**, enabling AI agents to navigate knowledge bases the way humans browse Wikipedia—following explicit links while also discovering related concepts through meaning.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WIKI STRUCTURE                               │
│                                                                       │
│  ┌─────────────────┐   entity_key    ┌──────────────────┐           │
│  │ brief-cbt-intro │ ──────────────▶ │ cbt-supervision  │           │
│  └─────────────────┘                 └──────────────────┘           │
│         │                                    │                       │
│         │ semantic                           │ entity_key            │
│         │ similarity                         ▼                       │
│         │                          ┌────────────────────┐           │
│         └─────────────────────▶    │ automatic-thoughts │           │
│                                    └────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Concepts

### 1. Entity Keys

Every wiki page has a **unique entity key** - a single kebab-case term that serves as its canonical identifier:

```
automatic-thoughts
cognitive-distortions
cbt-behavioral-activation
challenging-maladaptive-thoughts
```

Entity keys are:
- **Single terms** - No paths or hierarchies (like Wikipedia article names)
- **Kebab-case** - Lowercase with hyphens
- **Qualified when needed** - Prefix with source/domain to avoid collisions (e.g., `cbt-relaxation` vs `ptsd-relaxation`)
- **Descriptive** - Self-explanatory without context

### 2. Markdown Pages

Each entity key maps to a markdown file containing:

```markdown
---
entity_key: challenging-maladaptive-thoughts
title: Challenging Maladaptive Thoughts and Beliefs
parent: cbt-essential-skills
children:
  - thought-records
  - socratic-questioning
related:
  - automatic-thoughts
  - cognitive-distortions
  - identifying-maladaptive-thoughts
tags: [module, cognitive, restructuring]
source:
  document: therapists_guide_to_brief_cbtmanual.pdf
  pages: 53-58
---

# Challenging Maladaptive Thoughts and Beliefs

Techniques for addressing dysfunctional thoughts and beliefs...

## See Also

- [[automatic-thoughts|Automatic Thoughts]]
- [[cognitive-distortions|Cognitive Distortions]]
```

### 3. Link Types

Wiki pages use two types of connections:

| Link Type | Syntax | Purpose |
|-----------|--------|---------|
| **Entity Link** | `[[entity-key\|Display Text]]` | Explicit navigation (like Wikipedia links) |
| **Semantic Relation** | Stored in vector DB | Implicit similarity (discovered via search) |

## How REM Lookup Works

REM provides a unified query interface that combines:

### LOOKUP: Direct Entity Resolution

```python
# Exact entity retrieval by key
rem lookup "automatic-thoughts"

# Returns the exact page with that entity_key
```

LOOKUP is O(1) - instant retrieval using the entity key as a primary key.

### SEARCH: Semantic Discovery

```python
# Find related content by meaning
rem search "how to identify negative thinking patterns"

# Returns pages semantically similar to the query
# Ranked by vector similarity score
```

SEARCH uses pgvector embeddings to find conceptually related content.

### TRAVERSE: Graph Navigation

```python
# Follow entity relationships
rem traverse "cbt-essential-skills" --depth 2

# Returns parent, children, and related entities
# up to 2 hops away in the knowledge graph
```

TRAVERSE walks the explicit link graph defined in page frontmatter.

## The Power of Combined Lookup + Search

This is where the system becomes beautiful for agents:

```
┌──────────────────────────────────────────────────────────────────┐
│                    AGENT KNOWLEDGE NAVIGATION                     │
│                                                                    │
│   User: "How do I help a patient with catastrophizing?"           │
│                                                                    │
│   1. SEARCH: Find semantically relevant pages                     │
│      ├─▶ cognitive-distortions (score: 0.89)                     │
│      ├─▶ automatic-thoughts (score: 0.82)                        │
│      └─▶ thought-records (score: 0.78)                           │
│                                                                    │
│   2. LOOKUP: Get exact page by key                                │
│      └─▶ entity_key: "thought-records"                           │
│                                                                    │
│   3. TRAVERSE: Follow explicit links                              │
│      ├─▶ parent: cbt-essential-skills                            │
│      ├─▶ related: [cognitive-distortions, socratic-questioning]  │
│      └─▶ related: [challenging-maladaptive-thoughts]             │
│                                                                    │
│   Result: Agent can answer with full context AND provide          │
│           navigation paths for deeper exploration                 │
└──────────────────────────────────────────────────────────────────┘
```

### Why This Matters for Agents

Traditional RAG systems only do semantic search—they return chunks with no structure.

The Wiki System gives agents:

1. **Precise Navigation**: "Go to chapter 2, section 3" → LOOKUP
2. **Conceptual Discovery**: "What relates to anxiety?" → SEARCH
3. **Structural Context**: "What comes before/after this?" → TRAVERSE
4. **Authoritative Sources**: Entity keys are citations, not chunk IDs

## Generating a Wiki from Documents

### Step 1: Document Analysis

Large documents (PDFs, books, manuals) are split into logical chunks:

```python
# Split PDF by pages first (to avoid memory issues)
python scripts/split_pdf.py input.pdf --output-dir chunks/

# Analyze structure via table of contents
# Identify: chapters, sections, concepts, cross-references
```

### Step 2: Entity Key Assignment

Each section gets a single kebab-case entity key:

```
# Module/Section keys (qualified with source prefix)
brief-cbt-introduction      # Module 1
cbt-supervision             # Module 2
cbt-case-conceptualization  # Module 4
identifying-maladaptive-thoughts  # Module 9

# Concept keys (generic, reusable)
automatic-thoughts
cognitive-distortions
thought-records
socratic-questioning
```

**Key naming strategy:**
- Use source prefix (`cbt-`) when the concept is specific to that source
- Use generic names for universal concepts that could apply across sources
- Keep keys descriptive but concise

### Step 3: Link Extraction

Extract explicit links from content:
- Internal references ("see Chapter 3")
- Cross-references ("as discussed in...")
- Concept mentions (terms defined elsewhere)

### Step 4: Wiki Generation

Generate markdown files with proper frontmatter:

```python
# Each page includes:
# - entity_key: unique identifier
# - parent/children: structural hierarchy
# - related: cross-references
# - tags: for filtering/categorization
# - content: the actual text
```

### Step 5: Load into REM

```bash
# Load all wiki pages as resources
rem db load wiki/cbt-manual/ --format wiki

# Pages are indexed for both:
# - LOOKUP by entity_key
# - SEARCH by content embeddings
```

## Wiki Directory Structure

```
wiki/
└── cbt-manual/
    ├── _index.md                              # Root entry point (brief-cbt-manual)
    ├── modules/
    │   ├── brief-cbt-introduction.md          # Module 1
    │   ├── cbt-supervision.md                 # Module 2
    │   ├── cbt-nonspecific-factors.md         # Module 3
    │   ├── cbt-case-conceptualization.md      # Module 4
    │   ├── cbt-patient-orientation.md         # Module 5
    │   ├── identifying-maladaptive-thoughts.md  # Module 9
    │   ├── challenging-maladaptive-thoughts.md  # Module 10
    │   └── cbt-behavioral-activation.md       # Module 11
    ├── concepts/
    │   ├── automatic-thoughts.md
    │   ├── cognitive-distortions.md
    │   ├── core-beliefs.md
    │   ├── thought-records.md
    │   ├── socratic-questioning.md
    │   └── behavioral-activation.md
    ├── references/
    │   └── cbt-suggested-readings.md
    └── chunks/                                # Raw page extractions
        ├── _toc.md
        └── page_*.md
```

Note: File paths are for organization; entity keys are single terms like `automatic-thoughts`, not paths.

## Agent Usage Patterns

### Pattern 1: Question → Search → Context

```python
# Agent receives: "What is cognitive restructuring?"

# Step 1: Search for relevant pages
results = rem.search("cognitive restructuring", limit=3)

# Step 2: Get full context via lookup
for result in results:
    page = rem.lookup(result.entity_key)  # e.g., "challenging-maladaptive-thoughts"
    # page includes parent/children/related links

# Step 3: Optionally traverse for more context
related = rem.traverse(page.entity_key, depth=1)
```

### Pattern 2: Citation → Lookup → Expand

```python
# Agent needs to cite a specific section

# Direct lookup by known key
page = rem.lookup("cbt-homework")

# Include in response with proper citation
response = f"""
According to {page.title} (see [[{page.entity_key}]]):

{page.content[:500]}...

For more details, see:
- {[f"[[{c}]]" for c in page.related]}
"""
```

### Pattern 3: Browse → Traverse → Discover

```python
# User wants to explore a topic

# Start at a known entry point
root = rem.lookup("cbt-essential-skills")

# Get all children (available modules)
modules = rem.traverse(root.entity_key, relation="children")

# Present as browsable list
for module in modules:
    print(f"- [[{module.entity_key}|{module.title}]]")
```

## Benefits Over Traditional RAG

| Aspect | Traditional RAG | Wiki System |
|--------|----------------|-------------|
| **Retrieval** | Chunk similarity only | Lookup + Search + Traverse |
| **Context** | Isolated chunks | Full page + structural context |
| **Navigation** | None | Explicit links + hierarchy |
| **Citations** | Chunk IDs (meaningless) | Entity keys (semantic paths) |
| **Discovery** | Query-dependent | Browse + search combined |
| **Structure** | Flat | Hierarchical graph |

## Implementation Notes

### PDF Processing Strategy

Large PDFs should never be loaded entirely into memory:

1. **Split First**: Break into page-sized chunks
2. **Extract TOC**: Parse table of contents for structure
3. **Process Incrementally**: Handle one section at a time
4. **Link Later**: Add cross-references in a second pass

See `scripts/split_pdf.py` for the splitting utility.

### Frontmatter Schema

```yaml
---
entity_key: string          # Required: single kebab-case identifier
title: string               # Required: display title
parent: string | null       # Optional: parent entity_key
children: string[]          # Optional: child entity_keys
related: string[]           # Optional: related entity_keys
tags: string[]              # Optional: categorization tags
source:                     # Optional: provenance
  document: string
  pages: string             # e.g., "43-52" or "7"
---
```

### Loading Wiki into REM

```bash
# Load a wiki directory
rem db load wiki/cbt-manual/ \
  --format wiki \
  --user-id knowledge-base

# Verify structure
rem ask "What modules cover cognitive techniques?"

# Test navigation
rem lookup "automatic-thoughts"
rem search "how to challenge negative thinking" --limit 5
```

## Next Steps

- See [PDF Processing Guide](./pdf-processing.md) for handling large documents
- See [Wiki Generation Example](../wiki/) for a complete generated wiki
- See [Agent Integration](./agent-wiki-integration.md) for using wikis with agents
