# Quarterly Earnings Scenario

This scenario represents a high-stakes financial event with mixed data types: structured financial metrics (GAAP/Non-GAAP) and unstructured executive commentary.

## Data Profile
- **Type:** Earnings Call Transcript (Engram)
- **Context:** Q4 2024 Financial Results
- **Key Elements:**
  - Financial Entities (Revenue, Margin, Guidance)
  - Sentiment Shifts (Optimistic CEO vs Conservative Analyst)
  - Forward-looking statements

## Challenging Example Questions

### 1. Hybrid Retrieval (Structured + Unstructured)
> "Did the company beat revenue expectations, and what was the primary driver of growth?"

*   **Why it's hard:** "Beat expectations" requires comparing reported numbers (metadata) against implicit knowledge or context. "Driver of growth" is narrative text.
*   **Expected Answer:** Yes, revenue grew 28% YoY to $125M. The primary driver was a 35% growth in enterprise customers and strong uptake of the new AI workflow features.

### 2. Sentiment Analysis & Consistency
> "How confident is management about the international expansion compared to their domestic stability?"

*   **Why it's hard:** Requires analyzing the *tone* (metadata: `emotion_tags`) of specific moments (International QA vs Opening Remarks).
*   **Expected Answer:** Management is highly optimistic. The CEO expressed "pride" in the London/Singapore openings and "confidence" that international revenue will triple (to 25-30%) in 3 years.

### 3. Forward-Looking Logic
> "What is the guidance for FY2025, and does the CFO cite any risks to achieving it?"

*   **Why it's hard:** Separating "Q1 Guidance" from "Full Year Guidance" (numbers often appear close together). Detecting *absence* of risk mentions or *defensive* answers.
*   **Expected Answer:** FY2025 revenue guidance is $600-620M. The CFO did not cite specific risks, instead emphasizing "financial flexibility" ($180M cash) and strong pipeline momentum.

### 4. Competitive Positioning (Adversarial Q&A)
> "How did the CEO respond to concerns about pricing power against larger competitors?"

*   **Why it's hard:** Requires isolating the specific Q&A exchange with the analyst (Maria Gonzalez) and synthesizing the defensive argument.
*   **Expected Answer:** The CEO and CFO defended pricing power by citing an 8-10% annual price increase history with no impact on retention, backed by a high NPS of 72.

## Run This Scenario
```bash
rem db load --file earnings_call_engram.yaml --user-id finance-demo
rem ask --user-id finance-demo "Summarize the Q1 2025 guidance and key growth drivers"
```
