# Quickstart Dataset

Minimal dataset to get started with REM in under 5 minutes.

## What's Included

- **3 Users**: Software team members (engineer, designer, engineer)
- **3 Resources**: API design doc, retrospective notes, refactor notes
- **3 Moments**: Team retrospective, design review, pairing session
- **4 Messages**: Team chat conversation
- **3 Files**: Diagram, recording, mockups
- **3 Agent Schemas**: Query assistant, document analyzer, code reviewer

## Use Case

Perfect for:
- First-time REM users learning the concepts
- Quick demos and tutorials
- Testing REM query patterns
- Understanding data model structure

## Loading the Dataset

```bash
# Load into REM
rem db load --file datasets/quickstart/sample_data.yaml --user-id demo-user

# Verify data loaded
rem ask --user-id demo-user "List all users in the system"
```

## Example Queries

### LOOKUP - Find specific entities by label

```bash
rem ask --user-id demo-user "Who is Sarah Chen?"
rem ask --user-id demo-user "Show me the API Design Document v2"
```

### SEARCH - Semantic search across content

```bash
rem ask --user-id demo-user "Find documents about API architecture"
rem ask --user-id demo-user "What meetings discussed frontend work?"
```

### TRAVERSE - Follow relationships

```bash
rem ask --user-id demo-user "What documents did Sarah Chen author?"
rem ask --user-id demo-user "Who reviewed the API design document?"
rem ask --user-id demo-user "Show me all moments involving Alex Kim"
```

### Temporal - Time-based queries

```bash
rem ask --user-id demo-user "What happened in December 2024?"
rem ask --user-id demo-user "Show me coding sessions from Q4"
```

## Data Model

### Users
Team members with roles, departments, and locations.

**Fields**: `id`, `name`, `email`, `role`, `tags`, `metadata`

**Example**:
```yaml
- id: bb55c781-f880-594a-82e5-5191f0b64be8
  user_id: demo-user
  name: Sarah Chen
  email: sarah.chen@acme.com
  role: engineer
  tags:
    - backend
    - python
```

### Resources
Content units: documents, conversations, artifacts.

**Fields**: `id`, `user_id`, `name`, `uri`, `content`, `category`, `tags`, `graph_edges`

**Categories**: `document`, `conversation`, `artifact`

**Example**:
```yaml
- id: 06179554-0f2b-5548-a9c5-87d4cc576473
  user_id: demo-user
  name: API Design Document v2
  category: document
  content: |
    RESTful API design for the REM query system...
  graph_edges:
    - dst: bb55c781-f880-594a-82e5-5191f0b64be8
      rel_type: authored_by
      weight: 1.0
```

### Moments
Temporal narratives: meetings, coding sessions, events.

**Fields**: `id`, `name`, `moment_type`, `starts_timestamp`, `ends_timestamp`, `present_persons`, `topic_tags`, `emotion_tags`

**Types**: `meeting`, `coding-session`, `event`

**Example**:
```yaml
- id: 4f056f0b-0043-5441-b23b-cb250641c232
  user_id: demo-user
  name: Q4 2024 Team Retrospective
  moment_type: meeting
  starts_timestamp: "2024-12-20T14:00:00"
  present_persons:
    - id: bb55c781-f880-594a-82e5-5191f0b64be8
      name: Sarah Chen
      role: facilitator
```

### Messages
Chat messages and conversations.

**Fields**: `id`, `user_id`, `content`, `message_type`, `session_id`

**Types**: `user`, `assistant`

### Files
File metadata with S3 URIs.

**Fields**: `id`, `user_id`, `name`, `uri`, `mime_type`, `size_bytes`, `processing_status`

**Statuses**: `pending`, `processing`, `completed`, `failed`

### Agent Schemas
JSON Schema-based agent definitions.

**Fields**: `id`, `name`, `content` (description), `spec` (JSON Schema), `category`, `tags`

## Graph Structure

The dataset includes a simple knowledge graph:

```
Sarah Chen (user)
  └─ authored_by ─> API Design Document v2 (resource)
       └─ reviewed_by ─> Mike Johnson (user)

Q4 Retrospective (moment)
  └─ derived_from ─> Q4 Retrospective Notes (resource)
       └─ facilitator ─> Sarah Chen (user)

Alex Kim (user)
  └─ authored_by ─> Frontend Refactor (resource)
       └─ paired_with ─> Mike Johnson (user)
```

## Next Steps

After loading the quickstart dataset:

1. **Explore domains**: Check out [domains/](../domains/) for industry-specific examples
2. **Try formats**: See [formats/](../formats/) for engrams, documents, conversations
3. **Run evaluations**: Use [evaluation/](../evaluation/) golden datasets to test agents
4. **Build your own**: Copy this structure and customize with your data

## Troubleshooting

**Data not loading?**
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Verify migrations applied
rem db migrate

# Check connection
rem db status
```

**Queries returning empty?**
```bash
# Verify user_id matches
rem ask --user-id demo-user "List all resources"

# Check data exists
rem db query "SELECT COUNT(*) FROM resources WHERE user_id = 'demo-user'"
```

## Learn More

- [REM Query Language](https://github.com/Percolation-Labs/remstack/blob/main/rem/src/rem/models/core/README.md)
- [Data Model Documentation](https://github.com/Percolation-Labs/remstack/blob/main/rem/README.md#data-model)
- [Agent Schema Guide](https://github.com/Percolation-Labs/remstack/blob/main/CLAUDE.md#jsonschema-to-pydantic-pattern)
