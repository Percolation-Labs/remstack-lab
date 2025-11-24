# Technical Interview Scenario

This scenario evaluates "Soft Skill" extraction and evidence-based reasoning. It simulates an ATS (Applicant Tracking System) agent summarizing a candidate profile.

## Data Profile
- **Type:** Interview Transcript (Engram)
- **Context:** Senior Backend Engineer Interview
- **Key Elements:**
  - Technical Assessment (System Design, Databases)
  - Behavioral Signals (Conflict resolution)
  - Final Hiring Decision

## Challenging Example Questions

### 1. Evidence-Based Evaluation
> "Does the candidate have experience with distributed systems? Cite specific examples from their answers."

*   **Why it's hard:** Requires "Proof of Work" extraction—not just saying "Yes", but quoting the specific techniques mentioned.
*   **Expected Answer:** Yes. Sarah demonstrated strong knowledge by designing a distributed cache using **consistent hashing** for key distribution and specifying a **replication factor of 3** for fault tolerance.

### 2. Cultural Fit Assessment
> "How does the candidate handle technical disagreements? Is there evidence of maturity?"

*   **Why it's hard:** Analyzing a behavioral question ("Tell me about a time...").
*   **Expected Answer:** Sarah handles disagreements data-centrically. When debating microservices vs. monoliths, she created a comparison doc and ran POCs to let "data guide the decision," which the interviewer tagged as "collaborative" and "mature."

### 3. Skill Gap Analysis
> "Did the interviewer identify any major red flags or gaps in the candidate's knowledge?"

*   **Why it's hard:** Proving a negative. The agent must scan the entire engram (and metadata scores) to confirm the *absence* of negative sentiment.
*   **Expected Answer:** No significant red flags were identified. The candidate received high scores (4.5-5.0) across technical, communication, and behavioral categories.

### 4. Role Alignment
> "Based on the 'Database Scaling' section, would this candidate be suitable for a high-traffic consumer app?"

*   **Why it's hard:** Requires mapping specific technical answers (Sharding, Read Replicas) to a hypothetical job requirement ("High Traffic").
*   **Expected Answer:** Yes. Sarah correctly identified strategies for high-traffic systems, including range-based sharding on User ID and using read replicas/cache-aside patterns to handle "hot partitions."

## Run This Scenario
```bash
rem db load --file technical_interview_engram.yaml --user-id recruiting-demo
rem ask --user-id recruiting-demo "Draft a hiring recommendation email for Sarah Chen"
```
