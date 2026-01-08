#!/usr/bin/env python3
"""
Wiki Generation Utility v2

Transforms PDF page chunks into a structured wiki with:
- Single kebab-case entity keys (e.g., 'brief-cbt-introduction', 'automatic-thoughts')
- Qualified names to avoid collisions
- Cross-references and links
- Proper frontmatter for REM integration

Entity Key Strategy:
- Keys are single kebab-case terms (no paths)
- Qualify with source prefix when needed (e.g., 'cbt-automatic-thoughts' vs just 'automatic-thoughts')
- Use descriptive, unique names

Usage:
    python scripts/generate_wiki_v2.py wiki/cbt-manual/chunks/ --output wiki/cbt-manual/
"""

import argparse
import re
import yaml
from pathlib import Path
from dataclasses import dataclass, field


@dataclass
class WikiPage:
    """Represents a wiki page with metadata and content."""
    entity_key: str  # Single kebab-case key like 'automatic-thoughts'
    title: str
    content: str
    page_start: int
    page_end: int
    parent: str | None = None  # Parent entity key
    children: list[str] = field(default_factory=list)
    related: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    source_pages: list[int] = field(default_factory=list)
    filename: str = ""  # Where to save the file


def slugify(text: str) -> str:
    """Convert text to kebab-case slug."""
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text.strip('-')


def make_entity_key(title: str, prefix: str = "", module_num: int | None = None) -> str:
    """
    Create a single kebab-case entity key.

    Examples:
        'Introduction to Brief CBT' -> 'brief-cbt-introduction'
        'Automatic Thoughts' -> 'automatic-thoughts'
        'Module 9: Identifying...' -> 'cbt-identifying-maladaptive-thoughts'
    """
    # Clean and slugify the title
    slug = slugify(title)

    # Remove common prefixes
    slug = re.sub(r'^module-\d+-', '', slug)
    slug = re.sub(r'^appendix-[ab]-', '', slug)

    # Shorten overly long keys
    if len(slug) > 50:
        # Keep first few meaningful words
        words = slug.split('-')
        slug = '-'.join(words[:5])

    # Add prefix if provided (for disambiguation)
    if prefix:
        slug = f"{prefix}-{slug}"

    return slug


def parse_toc_structure(toc_content: str) -> list[dict]:
    """Parse table of contents into structured format."""
    structure = []
    lines = toc_content.strip().split('\n')

    for line in lines:
        if not line.strip() or line.startswith('#') or line.startswith('Source:'):
            continue

        indent = len(line) - len(line.lstrip())
        level = indent // 2

        match = re.search(r'\[([^\]]+)\]\(page_(\d+)\.md\)', line)
        if match:
            title = match.group(1)
            page = int(match.group(2))
            structure.append({
                'title': title,
                'page': page,
                'level': level
            })

    return structure


def build_wiki_structure(toc_structure: list[dict], source_prefix: str = "cbt") -> list[WikiPage]:
    """Build wiki pages from TOC structure with single kebab-case keys."""
    pages = []

    # Define the structure with entity keys
    # Format: (title_pattern, entity_key, parent_key, tags, subdir)
    structure_map = {
        # Section pages
        'Essential Psychotherapy Skills': ('cbt-psychotherapy-skills', None, ['section', 'foundational'], 'sections'),
        'Essential Brief CBT Skills': ('cbt-essential-skills', None, ['section', 'techniques'], 'sections'),
        'Essential CBT Skills': ('cbt-essential-skills', None, ['section', 'techniques'], 'sections'),

        # Module 1-4: Psychotherapy Skills (use exact match with colon)
        'Module 1:': ('brief-cbt-introduction', 'cbt-psychotherapy-skills', ['module', 'introduction'], 'modules'),
        'Module 2:': ('cbt-supervision', 'cbt-psychotherapy-skills', ['module', 'supervision'], 'modules'),
        'Module 3:': ('cbt-nonspecific-factors', 'cbt-psychotherapy-skills', ['module', 'therapeutic-alliance'], 'modules'),
        'Module 4:': ('cbt-case-conceptualization', 'cbt-psychotherapy-skills', ['module', 'treatment-planning'], 'modules'),

        # Module 5-14: CBT Skills
        'Module 5:': ('cbt-patient-orientation', 'cbt-essential-skills', ['module', 'orientation'], 'modules'),
        'Module 6:': ('cbt-goal-setting', 'cbt-essential-skills', ['module', 'goals'], 'modules'),
        'Module 7:': ('cbt-agenda-setting', 'cbt-essential-skills', ['module', 'session-structure'], 'modules'),
        'Module 8:': ('cbt-homework', 'cbt-essential-skills', ['module', 'homework'], 'modules'),
        'Module 9:': ('identifying-maladaptive-thoughts', 'cbt-essential-skills', ['module', 'cognitive', 'thoughts'], 'modules'),
        'Module 10:': ('challenging-maladaptive-thoughts', 'cbt-essential-skills', ['module', 'cognitive', 'restructuring'], 'modules'),
        'Module 11:': ('cbt-behavioral-activation', 'cbt-essential-skills', ['module', 'behavioral', 'activation'], 'modules'),
        'Module 12:': ('cbt-problem-solving', 'cbt-essential-skills', ['module', 'behavioral', 'problem-solving'], 'modules'),
        'Module 13:': ('cbt-relaxation', 'cbt-essential-skills', ['module', 'behavioral', 'relaxation'], 'modules'),
        'Module 14:': ('cbt-ending-treatment', 'cbt-essential-skills', ['module', 'termination', 'relapse-prevention'], 'modules'),

        # References
        'References': ('cbt-references', None, ['references'], 'references'),
        'Suggested': ('cbt-suggested-readings', 'cbt-references', ['references', 'readings'], 'references'),

        # Appendices
        'Appendix A': ('cbt-patient-handouts', None, ['appendix', 'handouts'], 'appendices'),
        'Appendix B': ('cbt-treatment-outlines', None, ['appendix', 'treatment-plans'], 'appendices'),
    }

    for entry in toc_structure:
        title = entry['title']
        page = entry['page']

        # Skip certain entries
        if title in ['Cover', 'Acknowledgements', 'Table of Contents', 'The Brief CBT Manual']:
            continue

        # Find matching structure
        entity_key = None
        parent = None
        tags = []
        subdir = 'modules'

        for pattern, (key, parent_key, tag_list, directory) in structure_map.items():
            if pattern in title:
                entity_key = key
                parent = parent_key
                tags = tag_list.copy()
                subdir = directory
                break

        if not entity_key:
            # Fallback: generate from title
            entity_key = make_entity_key(title, prefix=source_prefix)
            tags = ['other']
            subdir = 'other'

        wiki_page = WikiPage(
            entity_key=entity_key,
            title=title,
            content='',
            page_start=page,
            page_end=page,
            parent=parent,
            tags=tags,
            filename=f"{subdir}/{entity_key}.md"
        )
        pages.append(wiki_page)

    return pages


def calculate_page_ranges(pages: list[WikiPage], total_pages: int = 111) -> list[WikiPage]:
    """Calculate page ranges for each wiki page."""
    sorted_pages = sorted(pages, key=lambda p: p.page_start)

    for i, page in enumerate(sorted_pages):
        if i < len(sorted_pages) - 1:
            page.page_end = sorted_pages[i + 1].page_start - 1
        else:
            page.page_end = total_pages

        page.source_pages = list(range(page.page_start, page.page_end + 1))

    return sorted_pages


def load_page_content(chunks_dir: Path, page_num: int) -> str:
    """Load content from a page chunk file."""
    chunk_file = chunks_dir / f"page_{page_num:04d}.md"
    if chunk_file.exists():
        content = chunk_file.read_text()
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                return parts[2].strip()
        return content
    return ''


def merge_page_contents(chunks_dir: Path, page_start: int, page_end: int) -> str:
    """Merge content from multiple page chunks."""
    contents = []
    for page_num in range(page_start, page_end + 1):
        content = load_page_content(chunks_dir, page_num)
        if content:
            contents.append(f"<!-- Page {page_num} -->\n{content}")
    return '\n\n'.join(contents)


def extract_cross_references(content: str, all_pages: list[WikiPage]) -> list[str]:
    """Extract potential cross-references from content."""
    related = []

    # Map module numbers to entity keys
    module_map = {p.entity_key: p for p in all_pages if 'module' in p.tags}

    # Find module references
    for match in re.finditer(r'Module\s+(\d+)', content, re.IGNORECASE):
        module_num = int(match.group(1))
        # Find the page for this module
        for page in all_pages:
            if f'Module {module_num}' in page.title:
                if page.entity_key not in related:
                    related.append(page.entity_key)
                break

    return related


def add_wiki_links(content: str, all_pages: list[WikiPage], current_page: WikiPage) -> str:
    """Add wiki-style links to content using entity keys."""

    def replace_module_ref(match):
        module_num = match.group(1)
        for page in all_pages:
            if f'Module {module_num}' in page.title and page.entity_key != current_page.entity_key:
                return f"[[{page.entity_key}|Module {module_num}]]"
        return match.group(0)

    content = re.sub(r'Module\s+(\d+)', replace_module_ref, content)
    return content


def generate_frontmatter(page: WikiPage) -> str:
    """Generate YAML frontmatter for a wiki page."""
    fm = {
        'entity_key': page.entity_key,
        'title': page.title,
    }

    if page.parent:
        fm['parent'] = page.parent

    if page.children:
        fm['children'] = page.children

    if page.related:
        fm['related'] = page.related

    if page.tags:
        fm['tags'] = page.tags

    fm['source'] = {
        'document': 'therapists_guide_to_brief_cbtmanual.pdf',
        'pages': f"{page.page_start}-{page.page_end}" if page.page_start != page.page_end else str(page.page_start)
    }

    return yaml.dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True)


def write_wiki_page(output_dir: Path, page: WikiPage) -> Path:
    """Write a wiki page to disk."""
    # Use the filename from the page
    output_path = output_dir / page.filename
    output_path.parent.mkdir(parents=True, exist_ok=True)

    frontmatter = generate_frontmatter(page)
    full_content = f"---\n{frontmatter}---\n\n# {page.title}\n\n{page.content}"

    output_path.write_text(full_content)
    return output_path


def build_parent_child_relationships(pages: list[WikiPage]):
    """Build parent-child relationships between pages."""
    page_map = {p.entity_key: p for p in pages}

    for page in pages:
        if page.parent and page.parent in page_map:
            parent_page = page_map[page.parent]
            if page.entity_key not in parent_page.children:
                parent_page.children.append(page.entity_key)


def generate_index_page(pages: list[WikiPage], output_dir: Path):
    """Generate the root index page."""

    content_parts = [
        "A comprehensive guide to Brief Cognitive Behavioral Therapy.",
        "",
        "Brief CBT compresses traditional CBT (12-20 sessions) into 4-8 focused sessions.",
        "",
        "## Navigation",
        "",
        "Entity keys are single kebab-case terms for direct lookup:",
        "",
        "```python",
        "# Direct lookup",
        'page = rem.lookup("automatic-thoughts")',
        "",
        "# Semantic search",
        'results = rem.search("how to challenge negative thinking")',
        "```",
        "",
        "## Essential Psychotherapy Skills",
        "",
    ]

    # Group by parent
    psych_skills = [p for p in pages if p.parent == 'cbt-psychotherapy-skills']
    cbt_skills = [p for p in pages if p.parent == 'cbt-essential-skills']

    for page in sorted(psych_skills, key=lambda p: p.page_start):
        content_parts.append(f"- [[{page.entity_key}|{page.title}]]")

    content_parts.extend([
        "",
        "## Essential CBT Skills",
        "",
    ])

    for page in sorted(cbt_skills, key=lambda p: p.page_start):
        content_parts.append(f"- [[{page.entity_key}|{page.title}]]")

    content_parts.extend([
        "",
        "## Key Concepts",
        "",
        "- [[automatic-thoughts]] - Spontaneous evaluative thoughts",
        "- [[cognitive-distortions]] - Systematic thinking errors",
        "- [[core-beliefs]] - Deep beliefs about self and world",
        "- [[thought-records]] - Structured worksheets for cognitive work",
        "- [[socratic-questioning]] - Guided discovery technique",
        "- [[behavioral-activation]] - Activity-based mood improvement",
        "",
        "## References & Appendices",
        "",
        "- [[cbt-references|References]]",
        "- [[cbt-patient-handouts|Patient Handouts]]",
        "- [[cbt-treatment-outlines|Sample Treatment Outlines]]",
    ])

    index_page = WikiPage(
        entity_key='brief-cbt-manual',
        title="A Therapist's Guide to Brief CBT",
        content='\n'.join(content_parts),
        page_start=1,
        page_end=111,
        parent=None,
        children=[p.entity_key for p in pages],
        tags=['index', 'cbt', 'manual'],
        filename='_index.md'
    )

    write_wiki_page(output_dir, index_page)
    return index_page


def generate_concept_pages(output_dir: Path):
    """Generate concept pages with proper single-term entity keys."""

    concepts = [
        {
            'entity_key': 'automatic-thoughts',
            'title': 'Automatic Thoughts',
            'related': ['cognitive-distortions', 'core-beliefs', 'thought-records', 'identifying-maladaptive-thoughts'],
            'tags': ['concept', 'cognitive', 'foundational'],
            'content': """
Automatic thoughts are brief streams of thought about ourselves and others that occur spontaneously throughout the day.

## Definition

An **automatic thought** is a quick, evaluative thought that occurs in response to a situation:

- Occurs rapidly and often outside awareness
- Feels believable in the moment
- Is situation-specific
- Directly influences emotions and behaviors

## The Cognitive Model

```
Core Beliefs (deepest)
    ↓
Intermediate Beliefs (rules)
    ↓
Automatic Thoughts (surface) ← Target in Brief CBT
    ↓
Emotions & Behaviors
```

## Identifying Automatic Thoughts

Ask: "What was going through your mind just then?"

## See Also

- [[cognitive-distortions]] - Patterns in maladaptive thoughts
- [[thought-records]] - Tool for capturing thoughts
- [[identifying-maladaptive-thoughts]] - Full module
"""
        },
        {
            'entity_key': 'cognitive-distortions',
            'title': 'Cognitive Distortions',
            'related': ['automatic-thoughts', 'thought-records', 'challenging-maladaptive-thoughts'],
            'tags': ['concept', 'cognitive', 'distortions'],
            'content': """
Cognitive distortions are systematic errors in thinking that maintain negative automatic thoughts.

## Common Distortions

| Distortion | Example |
|------------|---------|
| **All-or-Nothing** | "If I'm not perfect, I'm a failure" |
| **Catastrophizing** | "This will ruin everything" |
| **Mind Reading** | "She thinks I'm stupid" |
| **Fortune Telling** | "I know it will go badly" |
| **Emotional Reasoning** | "I feel it, so it must be true" |
| **Overgeneralization** | "I always mess up" |
| **Mental Filter** | Focusing only on negatives |
| **Should Statements** | "I should be able to handle this" |
| **Labeling** | "I'm a loser" |
| **Personalization** | "It's all my fault" |

## See Also

- [[automatic-thoughts]] - The thoughts containing distortions
- [[thought-records]] - Tool for documenting distortions
- [[challenging-maladaptive-thoughts]] - How to challenge them
"""
        },
        {
            'entity_key': 'core-beliefs',
            'title': 'Core Beliefs',
            'related': ['automatic-thoughts', 'cognitive-distortions', 'cbt-case-conceptualization'],
            'tags': ['concept', 'cognitive', 'beliefs'],
            'content': """
Core beliefs are deep, fundamental beliefs about oneself, others, and the world formed in childhood.

## Categories

### Interpersonal
- "I am unlovable"
- "I am unworthy"
- "I will be abandoned"

### Achievement
- "I am incompetent"
- "I am a failure"
- "I am helpless"

## In Brief CBT

Core beliefs are typically **not** the primary target because:
- They're deeply ingrained and change slowly
- Limited sessions are better spent on automatic thoughts
- Changing thoughts can indirectly influence beliefs

## The Downward Arrow

To identify core beliefs, keep asking "What does that mean about you?" until reaching a global statement.

## See Also

- [[automatic-thoughts]] - Surface-level thoughts
- [[cbt-case-conceptualization]] - Using beliefs in treatment planning
"""
        },
        {
            'entity_key': 'thought-records',
            'title': 'Thought Records',
            'related': ['automatic-thoughts', 'cognitive-distortions', 'socratic-questioning', 'challenging-maladaptive-thoughts'],
            'tags': ['concept', 'technique', 'worksheet'],
            'content': """
The Dysfunctional Thought Record (DTR) is the primary tool for cognitive work in Brief CBT.

## 7-Column Format

| Column | Content |
|--------|---------|
| 1. Date/Time | When? |
| 2. Situation | What triggered it? |
| 3. Emotion(s) | What did you feel? (0-100) |
| 4. Automatic Thought | What went through your mind? |
| 5. Evidence For | What supports this thought? |
| 6. Evidence Against | What contradicts it? |
| 7. Alternative | More balanced view? |
| 8. Re-rate | How do you feel now? |

## The Triangle

```
    SITUATION
   /         \\
THOUGHT ——— FEELING
```

## See Also

- [[automatic-thoughts]] - What we're capturing
- [[socratic-questioning]] - Technique for examination
- [[cbt-homework]] - Assigning as between-session work
"""
        },
        {
            'entity_key': 'socratic-questioning',
            'title': 'Socratic Questioning',
            'related': ['thought-records', 'challenging-maladaptive-thoughts', 'automatic-thoughts'],
            'tags': ['concept', 'technique', 'questioning'],
            'content': """
Socratic questioning uses guided discovery through questions to help patients examine their thoughts.

## Key Principles

- **Collaborative** - Working together, not lecturing
- **Curious** - Genuine interest
- **Nonjudgmental** - Exploring, not criticizing
- **Guided** - Moving toward insight

## Question Types

### Evidence Questions
- "What's the evidence for this thought?"
- "What's the evidence against it?"

### Alternative Questions
- "Is there another way to look at this?"
- "What would you tell a friend?"

### Implication Questions
- "What's the worst that could happen?"
- "Could you cope if it did?"

### Usefulness Questions
- "How does thinking this way affect you?"
- "Does this thought help or hurt you?"

## See Also

- [[thought-records]] - Where questioning is applied
- [[challenging-maladaptive-thoughts]] - Full module
"""
        },
        {
            'entity_key': 'behavioral-activation',
            'title': 'Behavioral Activation',
            'related': ['cbt-problem-solving', 'cbt-relaxation', 'cbt-homework'],
            'tags': ['concept', 'behavioral', 'technique'],
            'content': """
Behavioral activation increases patient activity and access to reinforcing situations.

## The Depression Cycle

```
Low Mood → Decreased Activity → Fewer Rewards → Lower Mood → More Avoidance
```

## Breaking the Cycle

1. **Re-introduce** prior pleasant activities
2. **Introduce** new pleasant activities
3. **Active coping** - accomplishment tasks

## Activity Scheduling

| Time | Activity | Mood (0-10) | Pleasure | Mastery |
|------|----------|-------------|----------|---------|
| 9am | Walk | 5 | 4 | 3 |
| 10am | Call friend | 6 | 5 | 4 |

## Key Insight

**Action comes before motivation** - don't wait to "feel like it."

## See Also

- [[cbt-problem-solving]] - For addressing barriers
- [[cbt-homework]] - Assigning activity monitoring
"""
        },
    ]

    concepts_dir = output_dir / 'concepts'
    concepts_dir.mkdir(parents=True, exist_ok=True)

    for concept in concepts:
        page = WikiPage(
            entity_key=concept['entity_key'],
            title=concept['title'],
            content=concept['content'].strip(),
            page_start=0,
            page_end=0,
            related=concept['related'],
            tags=concept['tags'],
            filename=f"concepts/{concept['entity_key']}.md"
        )
        page.source_pages = []
        write_wiki_page(output_dir, page)
        print(f"  Created concept: {concept['entity_key']}")

    return len(concepts)


def main():
    parser = argparse.ArgumentParser(description='Generate wiki with single kebab-case entity keys')
    parser.add_argument('chunks_dir', type=Path, help='Directory containing PDF chunks')
    parser.add_argument('--output', '-o', type=Path, default=None)

    args = parser.parse_args()

    if not args.chunks_dir.exists():
        print(f"Error: Chunks directory not found: {args.chunks_dir}")
        return

    output_dir = args.output or args.chunks_dir.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load TOC
    toc_file = args.chunks_dir / '_toc.md'
    if not toc_file.exists():
        print(f"Error: TOC file not found: {toc_file}")
        return

    print(f"Loading TOC from {toc_file}")
    toc_content = toc_file.read_text()
    toc_structure = parse_toc_structure(toc_content)
    print(f"Found {len(toc_structure)} TOC entries")

    # Build wiki structure
    print("Building wiki structure with single kebab-case keys...")
    pages = build_wiki_structure(toc_structure)
    pages = calculate_page_ranges(pages)
    print(f"Created {len(pages)} wiki pages")

    # Build relationships
    build_parent_child_relationships(pages)

    # Load content
    print("Loading content from chunks...")
    for page in pages:
        page.content = merge_page_contents(args.chunks_dir, page.page_start, page.page_end)
        page.related = extract_cross_references(page.content, pages)
        page.content = add_wiki_links(page.content, pages, page)

    # Write pages
    print(f"Writing wiki pages to {output_dir}")
    for page in pages:
        path = write_wiki_page(output_dir, page)
        print(f"  {page.entity_key} -> {page.filename}")

    # Generate index
    generate_index_page(pages, output_dir)
    print(f"  Created: _index.md")

    # Generate concept pages
    print("Generating concept pages...")
    num_concepts = generate_concept_pages(output_dir)

    print(f"\nWiki generated successfully!")
    print(f"  Module pages: {len(pages)}")
    print(f"  Concept pages: {num_concepts}")
    print(f"  Total: {len(pages) + num_concepts + 1}")
    print(f"\nEntity key examples:")
    for page in pages[:5]:
        print(f"  {page.entity_key}")


if __name__ == '__main__':
    main()
