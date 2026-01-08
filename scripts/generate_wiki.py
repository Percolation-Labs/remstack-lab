#!/usr/bin/env python3
"""
Wiki Generation Utility

Transforms PDF page chunks into a structured wiki with:
- Hierarchical entity keys
- Cross-references and links
- Proper frontmatter for REM integration

Usage:
    python scripts/generate_wiki.py wiki/cbt-manual/chunks/ --output wiki/cbt-manual/
"""

import argparse
import re
import yaml
from pathlib import Path
from dataclasses import dataclass, field


@dataclass
class WikiPage:
    """Represents a wiki page with metadata and content."""
    entity_key: str
    title: str
    content: str
    page_start: int
    page_end: int
    parent: str | None = None
    children: list[str] = field(default_factory=list)
    related: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    source_pages: list[int] = field(default_factory=list)


def slugify(text: str) -> str:
    """Convert text to URL-friendly slug."""
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text.strip('-')


def extract_title_from_content(content: str) -> str | None:
    """Try to extract a title from page content."""
    lines = content.strip().split('\n')
    for line in lines:
        line = line.strip()
        # Skip empty lines and frontmatter
        if not line or line.startswith('---') or line.startswith('page:') or line.startswith('source:'):
            continue
        # Skip page numbers
        if re.match(r'^\d+\s*$', line):
            continue
        # Skip short lines that are likely headers
        if len(line) > 5 and len(line) < 200:
            return line
    return None


def parse_toc_structure(toc_content: str) -> list[dict]:
    """Parse table of contents into structured format."""
    structure = []
    lines = toc_content.strip().split('\n')

    for line in lines:
        if not line.strip() or line.startswith('#') or line.startswith('Source:'):
            continue

        # Count indent level (2 spaces = 1 level)
        indent = len(line) - len(line.lstrip())
        level = indent // 2

        # Extract link: [Title](page_XXXX.md)
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


def build_wiki_structure(toc_structure: list[dict], wiki_root: str) -> list[WikiPage]:
    """Build wiki pages from TOC structure."""
    pages = []
    parent_stack = [wiki_root]  # Stack to track parent at each level

    # Group TOC entries by their sections
    sections = {
        'essential-psychotherapy-skills': {
            'title': 'Essential Psychotherapy Skills',
            'modules': [1, 2, 3, 4],
            'page_range': (6, 25)
        },
        'essential-cbt-skills': {
            'title': 'Essential CBT Skills',
            'modules': [5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            'page_range': (26, 84)
        },
        'references': {
            'title': 'References',
            'page_range': (85, 86)
        },
        'appendix-a': {
            'title': 'Patient Handouts',
            'page_range': (87, 106)
        },
        'appendix-b': {
            'title': 'Sample Treatment Outlines',
            'page_range': (107, 111)
        }
    }

    for entry in toc_structure:
        title = entry['title']
        page = entry['page']
        level = entry['level']

        # Determine entity key
        slug = slugify(title)

        # Skip certain entries
        if title in ['Cover', 'Acknowledgements', 'Table of Contents']:
            continue

        # Handle section pages
        if 'Module' in title:
            # Extract module number
            module_match = re.search(r'Module\s+(\d+)', title)
            if module_match:
                module_num = int(module_match.group(1))
                # Determine parent section
                if module_num <= 4:
                    parent = f"{wiki_root}/essential-psychotherapy-skills"
                else:
                    parent = f"{wiki_root}/essential-cbt-skills"

                entity_key = f"{parent}/module-{module_num:02d}-{slug.replace(f'module-{module_num}-', '')}"
        elif 'Essential Psychotherapy' in title:
            entity_key = f"{wiki_root}/essential-psychotherapy-skills"
            parent = wiki_root
        elif 'Essential Brief CBT' in title or 'Essential CBT' in title:
            entity_key = f"{wiki_root}/essential-cbt-skills"
            parent = wiki_root
        elif 'References' in title:
            entity_key = f"{wiki_root}/references"
            parent = wiki_root
        elif 'Appendix A' in title:
            entity_key = f"{wiki_root}/appendix-a-patient-handouts"
            parent = wiki_root
        elif 'Appendix B' in title:
            entity_key = f"{wiki_root}/appendix-b-treatment-outlines"
            parent = wiki_root
        elif 'Suggested' in title:
            entity_key = f"{wiki_root}/references/suggested-readings"
            parent = f"{wiki_root}/references"
        else:
            entity_key = f"{wiki_root}/{slug}"
            parent = wiki_root

        # Assign tags based on content
        tags = []
        if 'Module' in title:
            tags.append('module')
        if any(kw in title.lower() for kw in ['thought', 'belief', 'cognitive']):
            tags.append('cognitive')
        if any(kw in title.lower() for kw in ['behavioral', 'activation', 'relaxation']):
            tags.append('behavioral')
        if any(kw in title.lower() for kw in ['problem', 'solving']):
            tags.append('problem-solving')
        if 'supervision' in title.lower():
            tags.append('supervision')
        if 'homework' in title.lower():
            tags.append('homework')
        if 'goal' in title.lower():
            tags.append('goals')
        if 'handout' in title.lower() or 'appendix a' in title.lower():
            tags.append('handout')

        wiki_page = WikiPage(
            entity_key=entity_key,
            title=title,
            content='',  # Will be filled later
            page_start=page,
            page_end=page,  # Will be updated
            parent=parent if parent != wiki_root else wiki_root,
            tags=tags
        )
        pages.append(wiki_page)

    return pages


def calculate_page_ranges(pages: list[WikiPage]) -> list[WikiPage]:
    """Calculate page ranges for each wiki page."""
    # Sort by page_start
    sorted_pages = sorted(pages, key=lambda p: p.page_start)

    for i, page in enumerate(sorted_pages):
        if i < len(sorted_pages) - 1:
            # End at the page before the next section starts
            page.page_end = sorted_pages[i + 1].page_start - 1
        else:
            # Last section goes to end of document
            page.page_end = 111  # Total pages in CBT manual

        page.source_pages = list(range(page.page_start, page.page_end + 1))

    return sorted_pages


def load_page_content(chunks_dir: Path, page_num: int) -> str:
    """Load content from a page chunk file."""
    chunk_file = chunks_dir / f"page_{page_num:04d}.md"
    if chunk_file.exists():
        content = chunk_file.read_text()
        # Remove frontmatter
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

    # Keywords that might indicate references to other modules
    reference_patterns = [
        (r'see Module (\d+)', 'module'),
        (r'Module (\d+)', 'module'),
        (r'see p\. (\d+)', 'page'),
        (r'page (\d+)', 'page'),
    ]

    for pattern, ref_type in reference_patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            num = int(match)
            if ref_type == 'module':
                # Find the wiki page for this module
                for page in all_pages:
                    if f'module-{num:02d}' in page.entity_key:
                        if page.entity_key not in related:
                            related.append(page.entity_key)
                        break

    return related


def add_wiki_links(content: str, all_pages: list[WikiPage], current_page: WikiPage) -> str:
    """Add wiki-style links to content."""
    # Create a mapping of titles to entity keys
    title_map = {p.title.lower(): p.entity_key for p in all_pages}

    # Also map module numbers
    for p in all_pages:
        module_match = re.search(r'Module\s+(\d+)', p.title)
        if module_match:
            title_map[f"module {module_match.group(1)}"] = p.entity_key

    # Replace references with wiki links
    def replace_module_ref(match):
        module_num = match.group(1)
        key = f"module {module_num}"
        if key in title_map and title_map[key] != current_page.entity_key:
            return f"[[{title_map[key]}|Module {module_num}]]"
        return match.group(0)

    content = re.sub(r'Module\s+(\d+)', replace_module_ref, content)

    return content


def generate_frontmatter(page: WikiPage) -> str:
    """Generate YAML frontmatter for a wiki page."""
    fm = {
        'entity_key': page.entity_key,
        'title': page.title,
        'parent': page.parent,
    }

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


def write_wiki_page(output_dir: Path, page: WikiPage):
    """Write a wiki page to disk."""
    # Determine output path from entity key
    key_parts = page.entity_key.split('/')
    if len(key_parts) > 1:
        # Create subdirectory structure
        subdir = output_dir / '/'.join(key_parts[1:-1]) if len(key_parts) > 2 else output_dir
        subdir.mkdir(parents=True, exist_ok=True)
        filename = f"{key_parts[-1]}.md"
        output_path = subdir / filename
    else:
        output_path = output_dir / f"{key_parts[0]}.md"

    # Build page content
    frontmatter = generate_frontmatter(page)
    full_content = f"---\n{frontmatter}---\n\n# {page.title}\n\n{page.content}"

    output_path.write_text(full_content)
    return output_path


def build_parent_child_relationships(pages: list[WikiPage]):
    """Build parent-child relationships between pages."""
    # Create a map of entity_key to page
    page_map = {p.entity_key: p for p in pages}

    for page in pages:
        if page.parent and page.parent in page_map:
            parent_page = page_map[page.parent]
            if page.entity_key not in parent_page.children:
                parent_page.children.append(page.entity_key)


def generate_index_page(wiki_root: str, pages: list[WikiPage], output_dir: Path):
    """Generate the root index page."""
    # Group pages by section
    sections = {}
    for page in pages:
        if page.parent == wiki_root:
            sections[page.entity_key] = {
                'page': page,
                'children': []
            }

    # Add children to sections
    for page in pages:
        if page.parent in sections:
            sections[page.parent]['children'].append(page)

    # Build index content
    content_parts = [
        "A comprehensive guide to Brief Cognitive Behavioral Therapy, adapted for clinical use.",
        "",
        "## Overview",
        "",
        "This manual provides practical guidance for therapists implementing Brief CBT in clinical settings.",
        "Brief CBT compresses traditional CBT (12-20 sessions) into 4-8 sessions while maintaining effectiveness.",
        "",
        "## Contents",
        ""
    ]

    for entity_key, section in sections.items():
        page = section['page']
        content_parts.append(f"### [[{page.entity_key}|{page.title}]]")
        content_parts.append("")

        for child in sorted(section['children'], key=lambda c: c.page_start):
            content_parts.append(f"- [[{child.entity_key}|{child.title}]]")

        content_parts.append("")

    index_page = WikiPage(
        entity_key=wiki_root,
        title="A Therapist's Guide to Brief CBT",
        content='\n'.join(content_parts),
        page_start=1,
        page_end=111,
        parent=None,
        children=[p.entity_key for p in pages if p.parent == wiki_root],
        tags=['index', 'cbt', 'manual']
    )

    write_wiki_page(output_dir, index_page)
    return index_page


def main():
    parser = argparse.ArgumentParser(
        description='Generate wiki from PDF chunks',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('chunks_dir', type=Path, help='Directory containing PDF chunks')
    parser.add_argument('--output', '-o', type=Path, default=None,
                        help='Output directory for wiki (default: parent of chunks_dir)')
    parser.add_argument('--wiki-root', '-r', type=str, default='cbt-manual',
                        help='Root entity key for the wiki (default: cbt-manual)')

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
    print("Building wiki structure...")
    pages = build_wiki_structure(toc_structure, args.wiki_root)
    pages = calculate_page_ranges(pages)
    print(f"Created {len(pages)} wiki pages")

    # Build relationships
    build_parent_child_relationships(pages)

    # Load and merge content for each page
    print("Loading content from chunks...")
    for page in pages:
        page.content = merge_page_contents(args.chunks_dir, page.page_start, page.page_end)
        # Extract cross-references
        page.related = extract_cross_references(page.content, pages)
        # Add wiki links
        page.content = add_wiki_links(page.content, pages, page)

    # Write pages
    print(f"Writing wiki pages to {output_dir}")
    written = []
    for page in pages:
        path = write_wiki_page(output_dir, page)
        written.append(path)
        print(f"  Created: {path.relative_to(output_dir)}")

    # Generate index
    index_page = generate_index_page(args.wiki_root, pages, output_dir)
    print(f"  Created: _index.md")

    # Generate concepts index (extracted key concepts)
    concepts_dir = output_dir / 'concepts'
    concepts_dir.mkdir(exist_ok=True)

    print(f"\nWiki generated successfully!")
    print(f"  Total pages: {len(written) + 1}")
    print(f"  Output directory: {output_dir}")


if __name__ == '__main__':
    main()
