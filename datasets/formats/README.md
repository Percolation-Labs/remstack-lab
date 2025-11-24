# Format-Specific Examples

Examples organized by data format: engrams, documents, conversations, and files.

## Engrams

**Personal memory units**: voice memos, reflections, ideas, quick notes.

Engrams are time-stamped, speaker-attributed memory fragments that capture thoughts, conversations, and experiences in their raw form.

**Structure**:
- `kind: engram` - Format identifier
- `resource_timestamp` - When the engram was created
- `content` - Main content (transcript, notes)
- `moments` - Nested time-bound sub-narratives
- `graph_edges` - Entity relationships
- `metadata` - Device info, context

**Use cases**:
- Voice memo transcripts
- Meeting recordings with timestamps
- Personal reflections and journal entries
- Quick idea captures
- Conversation summaries

**See**: [engrams/](./engrams/)

## Documents

**Structured documents**: API specs, meeting notes, design docs, research papers.

Standard document formats with clear structure and organization.

**Formats**:
- Markdown (.md)
- Plain text (.txt)
- PDF (.pdf)
- HTML (.html)

**Use cases**:
- Technical documentation
- Meeting notes
- Design specifications
- Research papers
- Knowledge base articles

**See**: [documents/](./documents/)

## Conversations

**Multi-turn dialogues**: chat logs, meeting transcripts, support tickets.

Speaker-attributed, chronologically ordered conversations.

**Structure**:
- Timestamped messages
- Speaker identification
- Session grouping
- Context metadata

**Use cases**:
- Team chat logs
- Customer support tickets
- Interview transcripts
- Consultation notes
- Multi-party discussions

**See**: [conversations/](./conversations/)

## Files

**Binary file examples** with metadata: images, audio, video, PDFs.

File entities with S3 URIs and processing status tracking.

**Supported types**:
- Images: PNG, JPG, JPEG, GIF, WebP
- Audio: MP3, M4A, WAV, OGG
- Video: MP4, MOV, AVI, WebM
- Documents: PDF, DOCX, PPTX, XLSX

**Use cases**:
- Testing file processor
- Content extraction pipelines
- Multi-modal data handling
- File metadata indexing

**See**: [files/](./files/)

## Format Comparison

| Format | Best For | Time Bounds | Speaker Attribution | Nesting |
|--------|----------|-------------|---------------------|---------|
| Engrams | Voice memos, raw captures | Yes (precise) | Yes | Yes (moments) |
| Documents | Structured content | No | No | Limited |
| Conversations | Multi-turn dialogue | Yes (per message) | Yes | No |
| Files | Binary content | Metadata only | No | No |

## Loading Format Examples

```bash
# Load engram scenario
rem db load \
  --file datasets/formats/engrams/scenarios/team_meeting/team_standup_meeting.yaml \
  --user-id demo-user

# Load multiple documents
for doc in datasets/formats/documents/*.md; do
  rem db load --file "$doc" --user-id demo-user
done
```

## Creating Your Own Format

Each format has a specific structure. Copy an existing example and customize:

```bash
# Copy template
cp datasets/formats/engrams/scenarios/template.yaml my_engram.yaml

# Edit structure
vim my_engram.yaml

# Load and test
rem db load --file my_engram.yaml --user-id test-user
rem ask --user-id test-user "Show me recent engrams"
```

## Learn More

- [Engram Format Guide](./engrams/README.md)
- [Document Format Guide](./documents/README.md)
- [Conversation Format Guide](./conversations/README.md)
- [File Processing Guide](./files/README.md)
