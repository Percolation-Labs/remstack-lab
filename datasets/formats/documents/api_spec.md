# REM API Specification v2.0

## Overview

The REM (Resources Entities Moments) API provides a RESTful interface for managing knowledge graphs, semantic search, and temporal narratives for agentic AI workloads.

## Base URL

```
https://api.rem.acme.com/v1
```

## Authentication

All API requests require authentication using OAuth 2.0 Bearer tokens.

```http
Authorization: Bearer <access_token>
```

### Supported OAuth Providers
- Google Workspace
- Microsoft Entra ID (Azure AD)
- Custom OAuth 2.0 providers

## Headers

### Required Headers
- `Authorization`: Bearer token
- `Content-Type`: application/json

### Optional Headers
- `X-Tenant-Id`: Tenant identifier for multi-tenancy (auto-detected from token if not provided)
- `X-User-Id`: User identifier (auto-detected from token if not provided)
- `X-Session-Id`: Session identifier for conversation context
- `X-Agent-Schema`: Agent schema URI for specialized behavior

## Query Types

### LOOKUP - O(1) Exact Match
Fast exact match by entity label or ID.

```http
POST /v1/query
Content-Type: application/json

{
  "query_type": "LOOKUP",
  "params": {
    "label": "Sarah Chen",
    "entity_type": "person"
  }
}
```

**Performance**: O(1) using UNLOGGED KV store with hash indexes.

### SEARCH - Semantic Vector Search
Find semantically similar content using pgvector.

```http
POST /v1/query
Content-Type: application/json

{
  "query_type": "SEARCH",
  "params": {
    "query_text": "API rate limiting implementation",
    "entity_types": ["resource", "moment"],
    "limit": 10,
    "min_similarity": 0.7
  }
}
```

**Performance**: ~50ms for top-10 results using HNSW indexes.

### TRAVERSE - Graph Traversal
Multi-hop relationship traversal.

```http
POST /v1/query
Content-Type: application/json

{
  "query_type": "TRAVERSE",
  "params": {
    "start_label": "API Design Document v2",
    "relationship_types": ["authored_by", "reviewed_by"],
    "max_depth": 3,
    "direction": "outbound"
  }
}
```

**Performance**: Depth-limited to prevent expensive traversals.

### SQL - Direct SQL Queries
Complex filtering and aggregation.

```http
POST /v1/query
Content-Type: application/json

{
  "query_type": "SQL",
  "params": {
    "table": "resources",
    "where": "category = 'document' AND created_at > '2025-01-01'",
    "order_by": "created_at DESC",
    "limit": 50
  }
}
```

**Security**: Parameterized queries only, no raw SQL injection.

## Rate Limiting

Token bucket algorithm with per-tenant limits:

- **Standard Tier**: 100 requests/minute
- **Professional Tier**: 1,000 requests/minute
- **Enterprise Tier**: Custom limits

Rate limit headers included in responses:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## Error Handling

Standard HTTP status codes:

- `200 OK`: Successful request
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

Error response format:
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Please retry after 60 seconds.",
    "details": {
      "limit": 100,
      "window": "1 minute",
      "retry_after": 60
    }
  }
}
```

## Webhooks

Register webhooks for event notifications:

```http
POST /v1/webhooks
Content-Type: application/json

{
  "url": "https://your-app.com/webhooks/rem",
  "events": ["resource.created", "moment.updated"],
  "secret": "your-webhook-secret"
}
```

Supported events:
- `resource.created`
- `resource.updated`
- `resource.deleted`
- `moment.created`
- `moment.updated`
- `entity.linked`

## Pagination

Cursor-based pagination for large result sets:

```http
GET /v1/resources?limit=50&cursor=eyJpZCI6InJlc18xMjM0NTYifQ==
```

Response includes next cursor:
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6InJlc18xMjM0NTcifQ==",
    "has_more": true
  }
}
```

## Embeddings

Automatic embedding generation for:
- Resource content and summaries
- Moment descriptions
- Entity metadata

Supported embedding providers:
- OpenAI text-embedding-3-small (1536 dimensions)
- OpenAI text-embedding-3-large (3072 dimensions)
- Anthropic Voyage (1024 dimensions)

## Graph Edges

Human-friendly labels for knowledge graph relationships:

```json
{
  "graph_edges": [
    {
      "dst": "Sarah Chen",
      "rel_type": "authored_by",
      "weight": 1.0,
      "properties": {
        "dst_entity_type": "person/engineer",
        "confidence": 1.0
      }
    }
  ]
}
```

**Important**: Use natural language labels ("Sarah Chen"), not UUIDs.

## Versioning

API version specified in URL path: `/v1/`, `/v2/`, etc.

Current version: **v1**

Breaking changes will be introduced in new versions with deprecation notices.

## SDK Support

Official SDKs:
- Python: `pip install rem-sdk`
- TypeScript: `npm install @rem/sdk`
- Go: `go get github.com/rem/rem-go`

## Support

- Documentation: https://docs.rem.acme.com
- Status Page: https://status.rem.acme.com
- Support Email: support@rem.acme.com
