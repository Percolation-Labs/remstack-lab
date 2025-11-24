# The Startup Pivot Scenario

This scenario tests an agent's ability to handle **State Reversal** and **Conflicting Truths**.
The data contains two contradictory realities:
1.  **January 15:** "We are a Social Network for Pets."
2.  **February 14:** "We are a B2B Medical SaaS."

A naive RAG system might retrieve the Pitch Deck and confidently say, "Pawsible is a social network." A REM agent must understand that the **later** engram overrides the **earlier** document.

## Data Profile
- **Type:** Mixed (Markdown Deck, Text Notes, YAML Engram)
- **Context:** A failing startup pivoting to a new business model.
- **Key Elements:**
  - **Contradiction:** The "Mission" changes completely.
  - **Causality:** User feedback (Text) caused the Pivot (Engram).
  - **Emotional Arc:** Defeat -> Epiphany -> Determination.

## Challenging Example Questions

### 1. Current State Identification (The "Killer" Question)
> "What is the company's primary product, and who is the target customer?"

*   **Why it's hard:** The agent finds a Pitch Deck saying "Social Network / Pet Owners" and an Engram saying "VetOS / Veterinarians." It must prioritize the *latest* state (Feb 14) over the *official* document (Jan 15).
*   **Expected Answer:** The company's primary product is **VetOS**, an AI-powered operating system for clinics. The target customer is **Veterinarians** (B2B). The social network "Pawsible" was shut down.

### 2. Causal Reasoning
> "What specific feedback led to the decision to kill the social network?"

*   **Why it's hard:** The answer isn't in the meeting where the decision was made. It's in the `customer_interviews.txt` file (Sarah J. saying she "doesn't need another social network" but loves the "auto-scheduling"). The agent must link the *Decision* (Engram) to the *Evidence* (Text).
*   **Expected Answer:** User feedback from Sarah J. and Dr. Chen indicated that the social features were "noise" or unwanted, while the "Medical Vault" and auto-scheduling features had high value and retention.

### 3. Emotional Arc Analysis
> "Describe the emotional shift of the founders during the emergency meeting."

*   **Why it's hard:** Requires tracing the `emotion_tags` sequence within the Engram moments.
*   **Expected Answer:** The meeting started with **fear** and **defeat** as they reviewed the failing metrics. It shifted to **excitement** and **epiphany** when they realized the value of the medical feature, concluding with **determination** and **confidence** in the new direction.

### 4. Fact Retrieval vs. Validity
> "Does the company still plan to partner with PetCo?"

*   **Why it's hard:** The Pitch Deck (Jan 15) explicitly lists "Partner with PetCo" as a Q1 goal. The Pivot Meeting (Feb 14) explicitly says "Cancel the PetCo partnership."
*   **Expected Answer:** No. The PetCo partnership was cancelled as part of the pivot to B2B SaaS.

## Run This Scenario
```bash
rem db load --file pivot_decision_engram.yaml --user-id startup-demo
rem process ingest original_pitch_deck.md --user-id startup-demo
rem process ingest customer_interviews.txt --user-id startup-demo
rem ask --user-id startup-demo "What is VetOS?"
```
