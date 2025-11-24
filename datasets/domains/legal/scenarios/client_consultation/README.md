# Legal Consultation Scenario

This scenario tests precise information extraction and risk identification within a privileged context. Accuracy and specific citations are paramount.

## Data Profile
- **Type:** Client Consultation (Engram)
- **Context:** NDA Review
- **Key Elements:**
  - Specific Contract Clauses (Confidentiality, Termination)
  - Action Items (Redlines)
  - Professional Advice (Risk assessment)

## Challenging Example Questions

### 1. Risk Identification & Remediation
> "What were the attorney's specific concerns regarding the definition of 'Confidential Information', and what was the proposed fix?"

*   **Why it's hard:** Requires connecting a "Concern" (Broad definition) with a specific "Action" (Carve-outs).
*   **Expected Answer:** The attorney (Jennifer Wu) felt the definition was too broad ("any information disclosed"). She proposed adding specific carve-outs for independently developed IP and information received from third parties.

### 2. Term Extraction
> "What is the proposed duration of the agreement, and did the attorney consider it standard market practice?"

*   **Why it's hard:** Requires extracting a specific value ("3 years") and the associated judgment ("reasonable/standard").
*   **Expected Answer:** The proposed term is 3 years. The attorney advised that this is standard for the client's industry.

### 3. Action Item Extraction
> "What is Jennifer delivering to the client, and by when?"

*   **Why it's hard:** Requires identifying the specific "next step" commitment from the speaker stream.
*   **Expected Answer:** Jennifer is sending a "redline" document containing 5 specific amendments by the "end of day" (Feb 14, 2025).

### 4. Clause Analysis
> "Does this NDA require us to destroy information upon termination?"

*   **Why it's hard:** The agent must infer this from the discussion about "return/destruction clauses" even if the full text isn't present.
*   **Expected Answer:** Yes, the consultation mentions a "return of materials" clause which the attorney deemed reasonable.

## Run This Scenario
```bash
rem db load --file nda_consultation_engram.yaml --user-id legal-demo
rem ask --user-id legal-demo "What amendments did the attorney recommend for the NDA?"
```
