# Finance Domain

Financial analysis, earnings reports, market research, risk assessment, and investment tracking.

## Use Cases

- **Investment Firms**: Track portfolio performance, market trends, research reports
- **Corporate Finance**: Quarterly earnings, financial planning, budget analysis
- **Financial Analysts**: Company research, earnings calls, SEC filings analysis
- **Risk Management**: Risk assessment, compliance tracking, audit trails

## Scenarios

### Quarterly Earnings

Complete quarterly earnings cycle with financial reports, earnings calls, analyst notes, and investor presentations.

**Entities**:
- Companies (3): TechVentures Inc, DataFlow Systems, CloudScale Corp
- Financial Reports (6): Q3 2024 earnings reports, balance sheets, cash flow statements
- Earnings Calls (3): Transcripts with Q&A sessions
- Analyst Notes (6): Research reports from different analysts
- Market Data (3): Stock performance, sector trends

**Workflow**:
1. Company releases quarterly earnings report
2. Earnings call held with analysts and investors
3. Analysts publish research notes and recommendations
4. Market reacts with price movements
5. Historical data updated for trend analysis

**Files**: [scenarios/quarterly_earnings/](./scenarios/quarterly_earnings/)

## Agent Schemas

### Financial Report Analyzer (`financial-report-analyzer-v1.yaml`)

Extracts structured data from earnings reports and financial statements:
- Revenue, profit, and margin metrics
- Year-over-year and quarter-over-quarter growth rates
- Key performance indicators (KPIs)
- Risk factors and forward guidance
- Management commentary highlights

**Provider configs**: Anthropic (Claude Sonnet 4.5), OpenAI (GPT-4o)

**Embedding fields**: company_name, executive_summary, key_metrics, risk_factors

### Earnings Call Analyzer (`earnings-call-analyzer-v1.yaml`)

Analyzes earnings call transcripts:
- Executive commentary themes
- Analyst questions and concerns
- Management tone and sentiment
- Forward guidance and outlook
- Competitive positioning

**Use case**: Extract insights from multi-hour earnings calls

## Sample Queries

```bash
# Load finance dataset
rem db load \
  --file datasets/domains/finance/scenarios/quarterly_earnings/data.yaml \
  --user-id finance-team

# Find specific metrics
rem ask --user-id finance-team "What was TechVentures' Q3 2024 revenue?"
rem ask --user-id finance-team "Show me companies with revenue growth above 20%"

# TRAVERSE: Find analyst coverage
rem ask --user-id finance-team "What did analysts say about DataFlow Systems?"

# Temporal: Track performance over time
rem ask --user-id finance-team "How has CloudScale's profit margin changed over the past year?"

# SEARCH: Semantic similarity
rem ask --user-id finance-team "Find companies with similar growth profiles to TechVentures"

# Risk analysis
rem ask --user-id finance-team "What are the main risk factors mentioned in Q3 earnings reports?"
```

## Ontology Extraction

Use `OntologyConfig` to automatically extract structured metrics from financial reports:

```yaml
# Example OntologyConfig for financial reports
ontology_configs:
  - name: Financial Report Extractor
    agent_schema_id: financial-report-analyzer-v1
    file_match_rules:
      mime_patterns:
        - application/pdf
        - text/html
      uri_patterns:
        - s3://*/earnings-reports/*
        - s3://*/sec-filings/*
      tag_patterns:
        - earnings-report
        - 10-q
        - 10-k
        - financial-statement
    priority: 100
    enabled: true
```

**Load and run**:
```bash
# Load config
rem db load --file ontology_config.yaml --user-id finance-team

# Upload report
rem files upload --file techventures_q3_2024_earnings.pdf --user-id finance-team --tags earnings-report

# Run extractor
rem dreaming custom --user-id finance-team --extractor financial-report-analyzer-v1

# Query extracted data
rem ask --user-id finance-team "What were TechVentures' key metrics in Q3?"
```

## Data Model

### Companies (Resources)

```yaml
resources:
  - id: company-techventures
    user_id: finance-team
    name: TechVentures Inc
    category: company
    content: |
      TechVentures Inc is a leading SaaS platform for enterprise workflow automation...
    metadata:
      ticker: TECH
      sector: Technology
      industry: Enterprise Software
      market_cap_millions: 2500
      founded: 2015
    tags:
      - public-company
      - saas
      - enterprise
    graph_edges:
      - dst: report-techventures-q3-2024
        rel_type: published
        weight: 1.0
```

### Financial Reports (Resources)

```yaml
resources:
  - id: report-techventures-q3-2024
    user_id: finance-team
    name: TechVentures Q3 2024 Earnings Report
    category: financial-report
    content: |
      Q3 2024 Financial Highlights
      Revenue: $125M (+28% YoY)
      Operating Income: $32M (+45% YoY)
      Net Income: $28M (+42% YoY)
      Operating Margin: 25.6% (up from 22.1% in Q3 2023)
      ...
    metadata:
      report_type: quarterly_earnings
      fiscal_quarter: Q3
      fiscal_year: 2024
      revenue_millions: 125
      revenue_growth_yoy_percent: 28
      operating_income_millions: 32
      net_income_millions: 28
      operating_margin_percent: 25.6
    tags:
      - earnings-report
      - q3-2024
    graph_edges:
      - dst: company-techventures
        rel_type: reports_on
        weight: 1.0
      - dst: earnings-call-techventures-q3-2024
        rel_type: discussed_in
        weight: 1.0
```

### Earnings Calls (Moments)

```yaml
moments:
  - id: earnings-call-techventures-q3-2024
    user_id: finance-team
    name: TechVentures Q3 2024 Earnings Call
    moment_type: earnings-call
    category: investor-relations
    starts_timestamp: "2024-10-24T16:30:00"
    ends_timestamp: "2024-10-24T17:45:00"
    present_persons:
      - id: person-sarah-martinez
        name: Sarah Martinez
        role: ceo
      - id: person-john-chen
        name: John Chen
        role: cfo
    topic_tags:
      - quarterly-results
      - product-launches
      - market-expansion
      - forward-guidance
    emotion_tags:
      - confident
      - optimistic
    metadata:
      call_type: quarterly_earnings
      participant_count: 47
      analyst_questions: 12
```

### Analyst Notes (Resources)

```yaml
resources:
  - id: analyst-note-001
    user_id: finance-team
    name: TechVentures Q3 Analysis - Goldman Sachs
    category: analyst-report
    content: |
      Investment Thesis: BUY - Price Target $95

      TechVentures delivered another strong quarter with 28% revenue growth...
      Key strengths: expanding margins, product-market fit, competitive moat...
      Risks: market saturation, competition from larger players...
    metadata:
      analyst_firm: Goldman Sachs
      analyst_name: David Kim
      rating: buy
      price_target: 95
      current_price: 78
      upside_percent: 21.8
    graph_edges:
      - dst: company-techventures
        rel_type: analyzes
        weight: 1.0
      - dst: report-techventures-q3-2024
        rel_type: references
        weight: 0.9
```

## KPIs and Analytics

Track financial metrics using REM queries:

- **Revenue Growth**: YoY and QoQ trends across portfolio
- **Margin Analysis**: Operating and net margin expansion/contraction
- **Analyst Consensus**: Average price targets and rating distribution
- **Risk Monitoring**: Track emerging risks across holdings
- **Sector Performance**: Compare metrics across industries
- **Valuation Metrics**: P/E ratios, growth rates, multiples

## Compliance

**Data Classification**: Mark financial data with appropriate sensitivity levels
**Access Control**: Audit all queries to material non-public information (MNPI)
**Retention Policies**: Archive earnings data per SEC requirements
**Audit Trail**: Track all access to financial reports and analyst notes

## Common Financial Queries

### Growth Analysis
```bash
rem ask --user-id finance-team "Which companies had revenue growth above 25% in Q3?"
rem ask --user-id finance-team "Show me margin expansion trends over the past 4 quarters"
```

### Analyst Coverage
```bash
rem ask --user-id finance-team "What's the analyst consensus on TechVentures?"
rem ask --user-id finance-team "Show me all buy-rated companies in the technology sector"
```

### Risk Tracking
```bash
rem ask --user-id finance-team "What supply chain risks were mentioned in Q3 calls?"
rem ask --user-id finance-team "Find companies with foreign exchange headwinds"
```

### Comparative Analysis
```bash
rem ask --user-id finance-team "Compare TechVentures and DataFlow margins"
rem ask --user-id finance-team "Which SaaS companies have the highest growth rates?"
```

## Next Steps

1. Load the quarterly earnings dataset
2. Upload your own earnings reports for extraction
3. Create custom financial analyst agents
4. Build dashboards with Phoenix visualizations
5. Integrate with Bloomberg Terminal or FactSet

## Learn More

- [Financial Report Schema](../../../rem/schemas/ontology_extractors/financial-report-analyzer-v1.yaml)
- [Ontology Extraction Guide](https://github.com/Percolation-Labs/remstack/blob/main/CLAUDE.md#ontology-extraction-pattern)
- [REM Query Examples](../../quickstart/README.md#example-queries)
