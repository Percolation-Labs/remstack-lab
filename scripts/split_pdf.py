#!/usr/bin/env python3
"""
PDF Splitting Utility for Wiki Generation

Splits large PDFs into page-by-page chunks for incremental processing.
This avoids memory issues with large documents and enables parallel processing.

Usage:
    python scripts/split_pdf.py input.pdf --output-dir chunks/
    python scripts/split_pdf.py input.pdf --output-dir chunks/ --format markdown
    python scripts/split_pdf.py input.pdf --pages 1-10  # Extract specific pages
"""

import argparse
import os
import sys
from pathlib import Path


def check_dependencies():
    """Check and report on available PDF processing libraries."""
    available = {}

    try:
        import pypdf
        available['pypdf'] = True
    except ImportError:
        available['pypdf'] = False

    try:
        import pymupdf  # fitz
        available['pymupdf'] = True
    except ImportError:
        available['pymupdf'] = False

    try:
        import pdfplumber
        available['pdfplumber'] = True
    except ImportError:
        available['pdfplumber'] = False

    return available


def split_with_pypdf(input_path: Path, output_dir: Path, pages: list[int] | None = None):
    """Split PDF using pypdf (pure Python, no dependencies)."""
    from pypdf import PdfReader, PdfWriter

    reader = PdfReader(input_path)
    total_pages = len(reader.pages)

    if pages is None:
        pages = list(range(total_pages))

    results = []
    for i in pages:
        if i >= total_pages:
            print(f"Warning: Page {i+1} does not exist (total: {total_pages})")
            continue

        # Save individual page as PDF
        writer = PdfWriter()
        writer.add_page(reader.pages[i])

        output_path = output_dir / f"page_{i+1:04d}.pdf"
        with open(output_path, 'wb') as f:
            writer.write(f)

        results.append({
            'page': i + 1,
            'path': output_path,
            'format': 'pdf'
        })

    return results, total_pages


def extract_text_with_pypdf(input_path: Path, output_dir: Path, pages: list[int] | None = None):
    """Extract text from PDF pages using pypdf."""
    from pypdf import PdfReader

    reader = PdfReader(input_path)
    total_pages = len(reader.pages)

    if pages is None:
        pages = list(range(total_pages))

    results = []
    for i in pages:
        if i >= total_pages:
            continue

        text = reader.pages[i].extract_text() or ""

        output_path = output_dir / f"page_{i+1:04d}.md"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(f"---\n")
            f.write(f"page: {i + 1}\n")
            f.write(f"source: {input_path.name}\n")
            f.write(f"---\n\n")
            f.write(text)

        results.append({
            'page': i + 1,
            'path': output_path,
            'format': 'markdown',
            'text_length': len(text)
        })

    return results, total_pages


def extract_text_with_pymupdf(input_path: Path, output_dir: Path, pages: list[int] | None = None):
    """Extract text from PDF pages using PyMuPDF (better quality)."""
    import pymupdf

    doc = pymupdf.open(input_path)
    total_pages = len(doc)

    if pages is None:
        pages = list(range(total_pages))

    results = []
    for i in pages:
        if i >= total_pages:
            continue

        page = doc[i]
        text = page.get_text()

        output_path = output_dir / f"page_{i+1:04d}.md"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(f"---\n")
            f.write(f"page: {i + 1}\n")
            f.write(f"source: {input_path.name}\n")
            f.write(f"---\n\n")
            f.write(text)

        results.append({
            'page': i + 1,
            'path': output_path,
            'format': 'markdown',
            'text_length': len(text)
        })

    doc.close()
    return results, total_pages


def extract_text_with_pdfplumber(input_path: Path, output_dir: Path, pages: list[int] | None = None):
    """Extract text from PDF pages using pdfplumber (best for tables)."""
    import pdfplumber

    results = []
    with pdfplumber.open(input_path) as pdf:
        total_pages = len(pdf.pages)

        if pages is None:
            pages = list(range(total_pages))

        for i in pages:
            if i >= total_pages:
                continue

            page = pdf.pages[i]
            text = page.extract_text() or ""

            # Also try to extract tables
            tables = page.extract_tables()

            output_path = output_dir / f"page_{i+1:04d}.md"
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(f"---\n")
                f.write(f"page: {i + 1}\n")
                f.write(f"source: {input_path.name}\n")
                f.write(f"has_tables: {len(tables) > 0}\n")
                f.write(f"---\n\n")
                f.write(text)

                if tables:
                    f.write("\n\n## Tables\n\n")
                    for idx, table in enumerate(tables):
                        f.write(f"### Table {idx + 1}\n\n")
                        for row in table:
                            f.write("| " + " | ".join(str(cell or '') for cell in row) + " |\n")
                        f.write("\n")

            results.append({
                'page': i + 1,
                'path': output_path,
                'format': 'markdown',
                'text_length': len(text),
                'tables': len(tables)
            })

    return results, total_pages


def get_pdf_info(input_path: Path):
    """Get basic PDF info without loading entire document."""
    available = check_dependencies()

    if available.get('pymupdf'):
        import pymupdf
        doc = pymupdf.open(input_path)
        info = {
            'total_pages': len(doc),
            'metadata': doc.metadata,
            'toc': doc.get_toc()  # Table of contents if available
        }
        doc.close()
        return info

    if available.get('pypdf'):
        from pypdf import PdfReader
        reader = PdfReader(input_path)
        info = {
            'total_pages': len(reader.pages),
            'metadata': dict(reader.metadata) if reader.metadata else {},
            'toc': []  # pypdf doesn't easily expose TOC
        }
        return info

    raise RuntimeError("No PDF library available. Install: pip install pypdf")


def parse_page_range(page_str: str, total_pages: int) -> list[int]:
    """Parse page range string like '1-10' or '1,3,5-7'."""
    pages = []
    for part in page_str.split(','):
        if '-' in part:
            start, end = part.split('-')
            start = int(start) - 1  # Convert to 0-indexed
            end = int(end)  # End is inclusive in user terms
            pages.extend(range(start, min(end, total_pages)))
        else:
            page = int(part) - 1
            if page < total_pages:
                pages.append(page)
    return sorted(set(pages))


def main():
    parser = argparse.ArgumentParser(
        description='Split PDF into page chunks for wiki generation',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Get PDF info and table of contents
    python split_pdf.py document.pdf --info

    # Split all pages to markdown
    python split_pdf.py document.pdf --output-dir chunks/ --format markdown

    # Extract only pages 1-10
    python split_pdf.py document.pdf --output-dir chunks/ --pages 1-10

    # Extract specific pages
    python split_pdf.py document.pdf --output-dir chunks/ --pages 1,5,10-15
        """
    )

    parser.add_argument('input', type=Path, help='Input PDF file')
    parser.add_argument('--output-dir', '-o', type=Path, default=Path('chunks'),
                        help='Output directory for chunks (default: chunks/)')
    parser.add_argument('--format', '-f', choices=['pdf', 'markdown', 'md'],
                        default='markdown', help='Output format (default: markdown)')
    parser.add_argument('--pages', '-p', type=str, default=None,
                        help='Page range to extract (e.g., "1-10" or "1,3,5-7")')
    parser.add_argument('--info', '-i', action='store_true',
                        help='Show PDF info and exit')
    parser.add_argument('--library', '-l',
                        choices=['auto', 'pypdf', 'pymupdf', 'pdfplumber'],
                        default='auto', help='PDF library to use (default: auto)')

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: File not found: {args.input}")
        sys.exit(1)

    # Check available libraries
    available = check_dependencies()
    print(f"Available PDF libraries: {[k for k, v in available.items() if v]}")

    if not any(available.values()):
        print("Error: No PDF library installed.")
        print("Install one of: pip install pypdf pymupdf pdfplumber")
        sys.exit(1)

    # Show info only
    if args.info:
        info = get_pdf_info(args.input)
        print(f"\nPDF Info: {args.input}")
        print(f"  Total pages: {info['total_pages']}")
        print(f"  Metadata: {info.get('metadata', {})}")
        if info.get('toc'):
            print(f"\n  Table of Contents:")
            for level, title, page in info['toc']:
                indent = "  " * level
                print(f"    {indent}{title} (page {page})")
        return

    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Get total pages first
    info = get_pdf_info(args.input)
    total_pages = info['total_pages']
    print(f"PDF has {total_pages} pages")

    # Parse page range
    pages = None
    if args.pages:
        pages = parse_page_range(args.pages, total_pages)
        print(f"Processing pages: {[p+1 for p in pages]}")

    # Select library and function
    if args.library == 'auto':
        # Prefer pymupdf > pdfplumber > pypdf for text extraction
        if args.format in ['markdown', 'md']:
            if available.get('pymupdf'):
                lib = 'pymupdf'
            elif available.get('pdfplumber'):
                lib = 'pdfplumber'
            else:
                lib = 'pypdf'
        else:
            lib = 'pypdf'  # For PDF splitting, pypdf is fine
    else:
        lib = args.library
        if not available.get(lib):
            print(f"Error: {lib} not installed")
            sys.exit(1)

    print(f"Using library: {lib}")

    # Process
    if args.format == 'pdf':
        if lib != 'pypdf':
            print("Note: PDF splitting only supported with pypdf, switching...")
        results, total = split_with_pypdf(args.input, args.output_dir, pages)
    else:
        if lib == 'pymupdf':
            results, total = extract_text_with_pymupdf(args.input, args.output_dir, pages)
        elif lib == 'pdfplumber':
            results, total = extract_text_with_pdfplumber(args.input, args.output_dir, pages)
        else:
            results, total = extract_text_with_pypdf(args.input, args.output_dir, pages)

    # Summary
    print(f"\nProcessed {len(results)} pages")
    print(f"Output directory: {args.output_dir}")

    if results:
        print(f"\nFirst few files:")
        for r in results[:5]:
            extra = ""
            if 'text_length' in r:
                extra = f" ({r['text_length']} chars)"
            if r.get('tables'):
                extra += f" [{r['tables']} tables]"
            print(f"  {r['path'].name}{extra}")
        if len(results) > 5:
            print(f"  ... and {len(results) - 5} more")

    # Save TOC if available
    if info.get('toc'):
        toc_path = args.output_dir / '_toc.md'
        with open(toc_path, 'w') as f:
            f.write(f"# Table of Contents\n\n")
            f.write(f"Source: {args.input.name}\n\n")
            for level, title, page in info['toc']:
                indent = "  " * (level - 1)
                f.write(f"{indent}- [{title}](page_{page:04d}.md) (page {page})\n")
        print(f"\nTable of contents saved to: {toc_path}")


if __name__ == '__main__':
    main()
