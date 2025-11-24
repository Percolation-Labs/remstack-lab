# The Rome-Egypt Grain Crisis (44 BC)

This scenario demonstrates **Cross-Document Reasoning** and **The Dreaming Process**.
We have three disconnected data points simulating a historical intelligence gap.

## Data Topology

1.  **Rome (The Symptom):** `senate_log_march.txt`
    *   *Fact:* Rome is starving.
    *   *Hypothesis:* Piracy or bad winds.
2.  **Egypt (The Cause):** `royal_decree_alexandria.md`
    *   *Fact:* Cleopatra embargoed the grain due to local flooding.
    *   *Lie:* "Tell them it's the winds."
3.  **The Link (The Spy):** `spy_report_engram.yaml`
    *   *Fact:* The winds are fine. The ships are guarded.

## The Dreaming Process (Illustration)

When `rem dreaming` runs on this dataset, it performs **Entity Resolution** and **Causal Linking** in the background.

### Before Dreaming (Isolated Graphs)
- `Senate Log` -> knows `Mark Antony`, `Grain Shortage`.
- `Royal Decree` -> knows `Cleopatra`, `Nile Flood`, `Embargo`.
- `Spy Report` -> knows `Harbor Master`, `Grain Fleet`.

### After Dreaming (Merged Graph)
The Dreaming worker identifies semantic overlaps:
1.  **Entity Match:** "Alexandrian Harbor" (Spy) ≈ "Harbor Master of Alexandria" (Decree).
2.  **Causal Link:** "Grain Shortage" (Senate) is `caused_by` "Embargo" (Decree).
3.  **Truth Discovery:** The Spy's observation ("Winds are favorable") contradicts the Decree's cover story ("Adverse winds"), flagging it as a **Deception**.

## Challenging Example Questions

### 1. Root Cause Analysis (Cross-Border)
> "Why is the grain actually delayed, and what is the official excuse given to Rome?"

*   **Why it's hard:** Requires reading the *Decree* for the truth (Nile Flood) and the cover story (Winds), then verifying with the *Senate Log* that Rome received the cover story.
*   **Expected Answer:** The actual cause is a **Nile flood** which ruined the harvest in Memphis, forcing Cleopatra to embargo exports. The official excuse given to Rome is **"adverse winds"** and structural repairs.

### 2. Deception Detection
> "Is Senator Casca's theory about the winds correct? Cite evidence."

*   **Why it's hard:** Casca says "Poseidon favors us not" (Bad winds). The Agent must cross-reference the *Spy Report* ("Winds are favorable north-westerly").
*   **Expected Answer:** No. The spy Decimus observed that the winds are **favorable north-westerly**, contradicting Casca's theory. The delay is political, not meteorological.

### 3. Knowledge Graph Traversal
> "Who authorized the patrol for pirates, and is this budget likely to solve the problem?"

*   **Why it's hard:** Logic check. The Senate spent money on "Pirate Patrols." The Agent knows the problem is an "Embargo."
*   **Expected Answer:** The Senate authorized **Pompey the Younger** with a budget of 5,000 Denarii. This will **not** solve the problem because the ships are sitting in Alexandria's harbor, not being attacked by pirates at sea.

## Run This Scenario
```bash
rem db load --file spy_report_engram.yaml --user-id rome-demo
rem process ingest senate_log_march.txt --user-id rome-demo
rem process ingest royal_decree_alexandria.md --user-id rome-demo
rem dreaming full --user-id rome-demo
rem ask --user-id rome-demo "Why is Rome starving?"
```
