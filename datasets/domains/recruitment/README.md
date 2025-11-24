# Recruitment Domain

CV parsing, candidate tracking, interview notes, and hiring pipeline data.

## Use Cases

- **Recruitment Agencies**: Track candidates across multiple clients
- **HR Departments**: Manage hiring pipeline and candidate experiences
- **Talent Acquisition**: Source, screen, and evaluate candidates
- **Applicant Tracking**: Full-cycle recruiting workflows

## Scenarios

### Candidate Pipeline

Complete hiring workflow from application to offer.

**Entities**:
- Candidates (5): Software engineers, designers, product managers
- Job Postings (3): Senior Backend Engineer, UX Designer, Product Manager
- Interviews (8): Phone screens, technical interviews, culture fits
- Interview Notes (8): Structured feedback from interviewers
- CVs/Resumes (5): PDF files with candidate background

**Workflow**:
1. Candidate submits application with CV
2. Recruiter screens CV (extracted via ontology)
3. Phone screen interview conducted
4. Technical assessment completed
5. Onsite interviews scheduled
6. Feedback collected and aggregated
7. Offer decision made

**Files**: [scenarios/candidate_pipeline/](./scenarios/candidate_pipeline/)

## Agent Schemas

### CV Parser (`cv-parser-v1.yaml`)

Extracts structured data from CVs/resumes:
- Candidate name and contact info
- Skills and technologies
- Work experience (companies, roles, dates)
- Education (degrees, institutions)
- Seniority level assessment

**Provider configs**: Anthropic (Claude Sonnet 4.5), OpenAI (GPT-4o)

**Embedding fields**: candidate_name, professional_summary, skills, experience

### Interview Analyzer (`interview-analyzer-v1.yaml`)

Analyzes interview notes and extracts:
- Technical assessment scores
- Cultural fit indicators
- Strengths and concerns
- Hiring recommendation
- Comparable candidates

**Use case**: Aggregate feedback across multiple interviewers

## Sample Queries

```bash
# Load recruitment dataset
rem db load \
  --file datasets/domains/recruitment/scenarios/candidate_pipeline/data.yaml \
  --user-id acme-corp

# Find candidates with specific skills
rem ask --user-id acme-corp "Show me candidates with Python and Kubernetes experience"

# TRAVERSE: Find interview feedback for a candidate
rem ask --user-id acme-corp "What did interviewers say about Sarah Chen?"

# Temporal: Recent applications
rem ask --user-id acme-corp "Show me candidates who applied in the last 30 days"

# SEARCH: Semantic similarity
rem ask --user-id acme-corp "Find candidates similar to our top backend engineers"

# Graph traversal: Hiring pipeline
rem ask --user-id acme-corp "Show me the complete interview history for the Senior Backend Engineer role"
```

## Ontology Extraction

Use `OntologyConfig` to automatically extract structured data from CVs:

```yaml
# Example OntologyConfig for CV parsing
ontology_configs:
  - name: CV Parser for Software Engineers
    agent_schema_id: cv-parser-v1
    file_match_rules:
      mime_patterns:
        - application/pdf
        - application/vnd.openxmlformats-officedocument.wordprocessingml.document
      uri_patterns:
        - s3://*/candidates/*/resume.*
        - s3://*/candidates/*/cv.*
      tag_patterns:
        - resume
        - cv
        - candidate-application
    priority: 100
    enabled: true
```

**Load and run**:
```bash
# Load config
rem db load --file ontology_config.yaml --user-id acme-corp

# Upload CV
rem files upload --file sarah_chen_resume.pdf --user-id acme-corp --tags resume

# Run extractor
rem dreaming custom --user-id acme-corp --extractor cv-parser-v1

# Query extracted data
rem ask --user-id acme-corp "What are Sarah's skills?"
```

## Data Model

### Candidates (Resources)

```yaml
resources:
  - id: candidate-001
    user_id: acme-corp
    name: Sarah Chen
    category: candidate
    content: |
      Senior Software Engineer with 8 years of experience...
    metadata:
      email: sarah@example.com
      phone: "+1-555-0123"
      current_title: Senior Software Engineer
      current_company: TechCorp
    tags:
      - candidate
      - software-engineer
      - active
    graph_edges:
      - dst: job-backend-senior
        rel_type: applied_for
        weight: 1.0
```

### Interviews (Moments)

```yaml
moments:
  - id: interview-001
    user_id: acme-corp
    name: Sarah Chen - Technical Interview
    moment_type: interview
    category: technical-assessment
    starts_timestamp: "2024-11-20T14:00:00"
    ends_timestamp: "2024-11-20T15:30:00"
    present_persons:
      - id: candidate-001
        name: Sarah Chen
        role: candidate
      - id: interviewer-mike
        name: Mike Johnson
        role: interviewer
    topic_tags:
      - system-design
      - kubernetes
      - scalability
    metadata:
      interview_type: technical
      focus_areas:
        - distributed_systems
        - kubernetes
        - database_design
```

### Interview Notes (Resources)

```yaml
resources:
  - id: interview-note-001
    user_id: acme-corp
    name: Interview Feedback - Sarah Chen
    category: interview-feedback
    content: |
      Excellent system design skills. Designed a scalable microservices
      architecture with proper service discovery and load balancing...
    metadata:
      overall_score: 4.5
      technical_score: 5.0
      communication_score: 4.0
      recommendation: strong_hire
    graph_edges:
      - dst: candidate-001
        rel_type: evaluates
        weight: 1.0
      - dst: interview-001
        rel_type: derived_from
        weight: 1.0
```

## KPIs and Analytics

Track recruitment metrics using REM queries:

- **Time to Fill**: Days from job posting to offer accepted
- **Source Effectiveness**: Which channels bring best candidates
- **Interview-to-Offer Ratio**: Conversion rates by stage
- **Candidate Experience**: Feedback and sentiment analysis
- **Diversity Metrics**: Track diversity across pipeline stages

## Compliance

**Data Retention**: Configure automated deletion for GDPR/CCPA compliance
**Anonymization**: Remove PII after rejection or withdrawal
**Audit Trail**: Track all access to candidate data

## Next Steps

1. Load the candidate pipeline dataset
2. Upload sample CVs to test extraction
3. Create custom interview feedback templates
4. Build analytics dashboards with Phoenix
5. Integrate with ATS systems (Greenhouse, Lever, etc.)

## Learn More

- [CV Parser Schema](../../../rem/schemas/ontology_extractors/cv-parser-v1.yaml)
- [Ontology Extraction Guide](https://github.com/Percolation-Labs/remstack/blob/main/CLAUDE.md#ontology-extraction-pattern)
- [REM Query Examples](../../quickstart/README.md#example-queries)
