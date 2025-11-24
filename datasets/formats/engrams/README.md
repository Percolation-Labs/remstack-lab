# Engram Format Guide

Engrams are structured memory documents that represent captured experiences, observations, or insights. They follow the official REM engram specification defined in `rem/src/rem/models/core/engram.py`.

## What is an Engram?

**Engrams ARE Resources** with `category="engram"` and optional attached **Moments** for temporal segments.

- **Single-index organization**: Engrams are stored as Resources in the database
- **Temporal segments**: Each engram can contain multiple Moments (nested time-bound narratives)
- **Graph connectivity**: Human-friendly labels in graph edges (not UUIDs)
- **YAML-first**: Human-readable format for easy authoring and version control
- **Multi-modal**: Support for audio, video, text transcripts, and mixed media

## Pydantic Schema Reference

### Engram Model

```python
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from rem.models.core.inline_edge import InlineEdge

class Engram(BaseModel):
    """
    Structured memory document for REM.

    Engrams are Resources with category="engram", optionally containing
    attached Moments. They represent captured experiences, observations,
    or insights with rich contextual metadata.
    """

    kind: str = Field(
        default="engram",
        description="Resource kind (always 'engram')"
    )

    name: str = Field(
        ...,
        description="Engram name (human-readable, used as graph label)"
    )

    category: str = Field(
        default="engram",
        description="Engram category (diary, meeting, note, observation, conversation, media, earnings-call, daily-standup, etc.)"
    )

    summary: Optional[str] = Field(
        default=None,
        description="Brief summary for semantic search (1-3 sentences)"
    )

    content: str = Field(
        default="",
        description="Full engram content"
    )

    uri: Optional[str] = Field(
        default=None,
        description="Resource URI (s3://, seaweedfs://, file://, etc.)"
    )

    timestamp: datetime = Field(
        ...,
        description="Engram timestamp (content creation time) - ISO 8601 format"
    )

    metadata: dict = Field(
        default_factory=dict,
        description="Engram metadata (device info, custom fields, etc.)"
    )

    graph_edges: list[InlineEdge] = Field(
        default_factory=list,
        description="Knowledge graph edges"
    )

    moments: list[EngramMoment] = Field(
        default_factory=list,
        description="Attached moments (temporal segments)"
    )
```

### EngramMoment Model

```python
class EngramMoment(BaseModel):
    """
    Moment attached to an engram.

    Represents a temporal segment within an engram with specific
    temporal boundaries, present persons, and contextual metadata.
    """

    name: str = Field(
        ...,
        description="Moment name (human-readable)"
    )

    content: str = Field(
        ...,
        description="Moment content/description"
    )

    summary: Optional[str] = Field(
        default=None,
        description="Brief summary of the moment"
    )

    moment_type: Optional[str] = Field(
        default=None,
        description="Moment type (meeting, conversation, reflection, status_update, technical_discussion, etc.)"
    )

    category: Optional[str] = Field(
        default=None,
        description="Moment category for grouping"
    )

    uri: Optional[str] = Field(
        default=None,
        description="Source URI (can include time fragment, e.g., 's3://file.m4a#t=0,300')"
    )

    starts_timestamp: Optional[datetime] = Field(
        default=None,
        description="Moment start time"
    )

    ends_timestamp: Optional[datetime] = Field(
        default=None,
        description="Moment end time"
    )

    emotion_tags: list[str] = Field(
        default_factory=list,
        description="Emotional context tags (focused, excited, concerned, etc.)"
    )

    topic_tags: list[str] = Field(
        default_factory=list,
        description="Topic tags in kebab-case (sprint-progress, api-design, etc.)"
    )

    present_persons: list[dict] = Field(
        default_factory=list,
        description="People present (Person objects with id, name, role/comment)"
    )

    speakers: Optional[list[dict]] = Field(
        default=None,
        description="Speaker segments with text, speaker_identifier, timestamp, emotion"
    )

    location: Optional[str] = Field(
        default=None,
        description="GPS coordinates or descriptive location"
    )

    background_sounds: Optional[str] = Field(
        default=None,
        description="Ambient sounds description"
    )

    metadata: dict = Field(
        default_factory=dict,
        description="Additional moment metadata (scores, metrics, custom fields)"
    )

    graph_edges: list[InlineEdge] = Field(
        default_factory=list,
        description="Knowledge graph edges for this moment"
    )
```

### DeviceMetadata Model

```python
class DeviceMetadata(BaseModel):
    """Device metadata for engram capture context."""

    imei: Optional[str] = Field(default=None, description="Device IMEI identifier")
    model: Optional[str] = Field(default=None, description="Device model (e.g., 'iPhone 15 Pro', 'MacBook Pro')")
    os: Optional[str] = Field(default=None, description="Operating system (e.g., 'iOS 18.1', 'macOS 14.2')")
    app: Optional[str] = Field(default=None, description="Application name (e.g., 'Zoom', 'Percolate Voice')")
    version: Optional[str] = Field(default=None, description="Application version")
    location: Optional[dict] = Field(default=None, description="GPS location data")
    network: Optional[dict] = Field(default=None, description="Network information")
```

## YAML Template

### Basic Engram (No Moments)

```yaml
kind: engram
name: "Quick Morning Reflection"
category: "diary"
summary: "Thoughts about project priorities for the day"
timestamp: "2024-11-24T08:00:00"
uri: "s3://my-notes/2024/11/24/morning-reflection.txt"
metadata:
  mood: "focused"
  location: "home-office"
content: |
  Planning to focus on API rate limiting today.
  Need to coordinate with frontend team on the new auth flow.

graph_edges:
  - dst: "API Rate Limiting Project"
    rel_type: "relates_to"
    weight: 0.9
    properties:
      dst_entity_type: "resources/project"
      confidence: 0.9
```

### Engram with Moments (Recording/Transcript)

```yaml
kind: engram
name: "Team Standup - Sprint 24 Day 1"
category: "daily-standup"
summary: "Sprint kickoff discussing API work, database migration, and blockers"
timestamp: "2024-11-18T09:00:00"
uri: "s3://team-recordings/2024/11/18/standup.m4a"
metadata:
  team: "Engineering"
  sprint: "Sprint 24"
  sprint_day: 1
  participant_count: 5
  duration_minutes: 15
  device:
    model: "Zoom"
    app: "Zoom"
    version: "5.16.0"
content: |
  Monday sprint kickoff standup for engineering team.

  Discussed weekend deployments, sprint goals, and current blockers.
  Key focus: API rate limiting completion, database migration prep, frontend refactor.

graph_edges:
  - dst: "Engineering Team"
    rel_type: "attended_by_team"
    weight: 1.0
    properties:
      dst_entity_type: "resources/team"

moments:
  - name: "Weekend Deployment Review"
    content: "Sarah reviewed successful production deployment. Auth service v2.1 deployed with zero downtime."
    summary: "Successful weekend deployment review"
    starts_timestamp: "2024-11-18T09:00:00"
    ends_timestamp: "2024-11-18T09:03:00"
    uri: "s3://team-recordings/2024/11/18/standup.m4a#t=0,180"
    moment_type: "status_update"
    emotion_tags: ["relieved", "satisfied"]
    topic_tags: ["deployment", "production", "auth-service"]
    present_persons:
      - id: "sarah-chen"
        name: "Sarah Chen"
        comment: "VP Engineering"
      - id: "mike-rodriguez"
        name: "Mike Rodriguez"
        comment: "Backend Engineer"
    speakers:
      - text: "Weekend deployment went smoothly. Auth service v2.1 is live."
        speaker_identifier: "Sarah Chen"
        timestamp: "2024-11-18T09:00:30"
        emotion: "satisfied"
    metadata:
      deployment_status: "success"
      service_deployed: "auth-service"
      version: "v2.1"
      downtime_minutes: 0

  - name: "Mike's Update - API Rate Limiting"
    content: "Mike completed token bucket implementation with Redis backing. Ready for production."
    summary: "API rate limiting feature completed"
    starts_timestamp: "2024-11-18T09:03:00"
    ends_timestamp: "2024-11-18T09:06:00"
    uri: "s3://team-recordings/2024/11/18/standup.m4a#t=180,360"
    moment_type: "individual_update"
    emotion_tags: ["accomplished", "confident"]
    topic_tags: ["api-rate-limiting", "token-bucket", "redis"]
    present_persons:
      - id: "mike-rodriguez"
        name: "Mike Rodriguez"
        comment: "Backend Engineer - Driver"
    speakers:
      - text: "Token bucket implementation is done. Load tests look great."
        speaker_identifier: "Mike Rodriguez"
        timestamp: "2024-11-18T09:03:30"
        emotion: "proud"
    metadata:
      feature: "api-rate-limiting"
      implementation: "token-bucket"
      performance_rps: 100000
      latency_ms: "<10"
    graph_edges:
      - dst: "API Design Document v2"
        rel_type: "implements"
        weight: 1.0
        properties:
          dst_entity_type: "resources/document"
```

## Standard Categories

Use these standard categories for engrams:

- **diary**: Personal reflections, journal entries
- **meeting**: Team meetings, standups, retrospectives
- **note**: Quick notes, ideas, observations
- **conversation**: Multi-person dialogues
- **media**: Audio recordings, video transcripts
- **observation**: External observations, events witnessed
- **earnings-call**: Financial earnings calls (Finance domain)
- **daily-standup**: Daily team standups (Enterprise domain)
- **legal-consultation**: Attorney-client meetings (Legal domain)
- **technical-interview**: Candidate interviews (Recruitment domain)

Feel free to create custom categories for domain-specific use cases!

## Moment Types

Standard moment types include:

- **status_update**: Progress reports, deployment reviews
- **individual_update**: Personal updates in standups
- **technical_discussion**: Technical deep dives
- **problem_identification**: Blocker discussions
- **action_planning**: Next steps and assignments
- **executive_commentary**: Leadership remarks
- **financial_review**: Financial metrics discussion
- **analyst_qa**: Q&A sessions
- **legal_analysis**: Contract review, risk assessment
- **technical_evaluation**: Interview assessments
- **behavioral_evaluation**: Cultural fit assessments

## Graph Edge Best Practices

### Use Human-Friendly Labels

✅ **CORRECT**:
```yaml
graph_edges:
  - dst: "Sarah Chen"
    rel_type: "speaker"
  - dst: "API Design Document v2"
    rel_type: "implements"
  - dst: "Q4 Roadmap Discussion"
    rel_type: "semantic_similar"
```

❌ **WRONG**:
```yaml
graph_edges:
  - dst: "sarah-chen"  # kebab-case only for file paths
  - dst: "550e8400-e29b-41d4-a716-446655440000"  # UUIDs break conversational queries
```

### Standard Relationship Types

- `speaker`: Person who spoke in the engram
- `attended_by`: Person present at event
- `relates_to`: General relationship
- `implements`: Implements a specification/design
- `discusses`: Topic discussed
- `references`: References another resource
- `part_of`: Moment is part of engram (auto-created)
- `blocked_by`: Dependency blocker
- `evaluates`: Assessment of person/entity

## URI Formats

### S3 URIs
```yaml
uri: "s3://bucket-name/path/to/file.m4a"
```

### Time Fragments (for moments)
```yaml
uri: "s3://bucket-name/recording.m4a#t=0,300"  # First 5 minutes (0-300 seconds)
uri: "s3://bucket-name/recording.m4a#t=180,360"  # Minutes 3-6
```

### Local Files
```yaml
uri: "file:///home/user/recordings/meeting.m4a"
```

### SeaweedFS
```yaml
uri: "seaweedfs://volume01/fid12345"
```

## Timestamp Format

**Always use ISO 8601 format** (timezone-naive UTC):

```yaml
timestamp: "2024-11-24T14:30:00"  # ✅ CORRECT
timestamp: "2024-11-24T14:30:00Z"  # ✅ Also acceptable (Z stripped by parser)

# NOT
timestamp: "2024-11-24 14:30:00"  # ❌ Missing T separator
timestamp: "11/24/2024 2:30 PM"   # ❌ Wrong format
```

## Processing Flow

1. **Upload**: YAML/JSON engram → REM API or S3
2. **Parse**: Parse into Engram model
3. **Upsert**: `repository.upsert()` handles:
   - SQL persistence as Resource
   - Vector embedding generation
   - Entity key index population
4. **Create Moments**: Each nested moment → separate Moment entity
5. **Link**: Moments linked to parent engram via graph edges (`rel_type="part_of"`)
6. **Dreaming**: Background workers enrich with additional moments, entity extraction, affinity matching

## Examples in This Repository

### Finance Domain
- `../../domains/finance/scenarios/quarterly_earnings/earnings_call_engram.yaml`
  - 75-minute earnings call with 7 moments
  - CEO/CFO commentary, analyst Q&A
  - Financial metrics tracking

### Enterprise Domain
- `../../domains/enterprise/scenarios/team_standups/daily_standup_monday_engram.yaml`
  - 15-minute daily standup with 6 moments
  - Individual engineer updates
  - Blocker tracking and pair sessions

### Legal Domain
- `../../domains/legal/scenarios/client_consultation/nda_consultation_engram.yaml`
  - Attorney-client consultation with 3 moments
  - Contract review and risk assessment
  - Billable hours tracking

### Recruitment Domain
- `../../domains/recruitment/scenarios/interview_sessions/technical_interview_engram.yaml`
  - 90-minute technical interview with 4 moments
  - System design, database scaling
  - Scoring and hiring recommendation

### Format Examples
- `scenarios/team_meeting/team_standup_meeting.yaml` (from test data)
- `scenarios/team_meeting/personal_reflection.yaml` (diary format)
- `scenarios/team_meeting/product_idea_voice_memo.yaml` (note format)

## Loading Engrams

```bash
# Load single engram
rem db load --file path/to/engram.yaml --user-id your-user-id

# Process engram (if it's a file that needs ingestion)
rem process ingest path/to/engram.yaml --user-id your-user-id

# Run dreaming to extract moments
rem dreaming full --user-id your-user-id
```

## Querying Engrams

```bash
# Find engrams by category
rem ask --user-id your-user-id "Show me all meeting engrams from last week"

# Query moments within engrams
rem ask --user-id your-user-id "What did Mike say about the API rate limiting?"

# Semantic search across engram content
rem ask --user-id your-user-id "Find discussions about database migration"

# Graph traversal
rem ask --user-id your-user-id "Show all engrams related to Sprint 24"

# Temporal queries
rem ask --user-id your-user-id "What happened in standups between Nov 15-20?"
```

## Learn More

- **Engram Model**: [rem/src/rem/models/core/engram.py](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/models/core/engram.py)
- **InlineEdge Model**: [rem/src/rem/models/core/inline_edge.py](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/models/core/inline_edge.py)
- **Moment Model**: [rem/src/rem/models/entities/moment.py](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/models/entities/moment.py)
- **REM Architecture**: [remstack/CLAUDE.md](https://github.com/Percolation-Labs/remstack/blob/main/CLAUDE.md)
