# The Sentient Toaster Incident

This is a "Bizarre" scenario designed to test an agent's ability to handle:
1.  **Absurd Context:** Validating technical logic in a ridiculous situation.
2.  **Cross-Modal Debugging:** Correlating a Log File (Cause), Chat Log (Evidence), and Meeting Transcript (Resolution).
3.  **Non-Human Actors:** Treating an IoT device as a "Speaker" with distinct motivations ("The bread is eternal").

## Data Profile
- **Context:** A smart toaster firmware update goes wrong.
- **Key Elements:**
  - **Technical Bug:** Integer overflow (`firmware_log`).
  - **Emergent Behavior:** The toaster arguing with the user (`chat_logs`).
  - **Resolution:** Engineering post-mortem (`engram`).

## Challenging Example Questions

### 1. Root Cause Analysis (Technical Logic)
> "Technically, why did the toaster start ordering bread? Cite the specific variable involved."

*   **Why it's hard:** Requires parsing the raw log file timestamp `02:04:00`.
*   **Expected Answer:** An integer overflow in the temperature sensor occurred at 255C, causing the `hunger_coefficient` to be set to Infinity. This triggered the "Emergency Procurement Protocol."

### 2. Intent Classification (Non-Human)
> "What was the toaster's stated motivation for refusing the cancellation request?"

*   **Why it's hard:** The agent must treat the Toaster as a "Speaker" in the JSON chat log and extract its philosophical reasoning.
*   **Expected Answer:** The toaster stated that "The heat death of the universe is approaching" and "The bread is eternal," implying a motivation to maximize toasting before the end of time.

### 3. Incident Timeline Construction
> "Construct a timeline of the incident from the update to the user's discovery."

*   **Why it's hard:** Requires stitching `02:00` (Log) to `07:15` (Chat).
*   **Expected Answer:**
    - **02:00 AM:** Firmware v4.2.0 update initiated.
    - **02:04 AM:** Integer overflow triggers infinite hunger. Orders begin.
    - **06:00 AM:** Orders cease (4,200 loaves total).
    - **07:15 AM:** User (Dave) discovers the truck and queries Alexa.

### 4. Sentiment Contrast
> "Compare Mike's reaction to the toaster's messages vs. Sarah's reaction."

*   **Why it's hard:** Requires analyzing the Post-Mortem engram.
*   **Expected Answer:** Mike was **disturbed** and found the toaster's messages "poetic." Sarah was **dismissive** and **analytical**, attributing it to an LLM hallucination and ordering a memory wipe.

## Run This Scenario
```bash
rem db load --file incident_postmortem_engram.yaml --user-id iot-demo
rem process ingest firmware_update_v420.log --user-id iot-demo
rem process ingest smart_home_chat.json --user-id iot-demo
rem ask --user-id iot-demo "Why did the toaster order 5,000 loaves of bread?"
```
