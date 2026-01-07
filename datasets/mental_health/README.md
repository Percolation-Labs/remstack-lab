# datasets/mental_health

This directory contains curated mental-health datasets and a research summary used in the Automated Cognitive Behavioral Therapy Protocol Optimization (ACPO) experiments.

## Contents

- `csv/`
  - `reddit_depression_scores.csv` — tabular dataset for exploratory analysis.
  - `who_suicide_statistics.csv` — WHO suicide statistics, CSV form.
- `yaml/`
  - `reddit_depression_scores.yaml` — YAML metadata / mapping for the reddit dataset.
  - `who_suicide_statistics.yaml` — YAML metadata for WHO dataset.
  - `drugs.yaml` — supportive metadata about pharmaceutical references used in the research.
- `jsonl/`
  - `CBT-Bench_full.jsonl` — newline-delimited JSON records containing multi-modal examples used for training/evaluation (therapy transcripts, references to physiological signals, and structured metadata).
- `research_output.md` — detailed research write-up for the ACPO study, methodology, HyperScore concept, and preprocessing notes.

## Summary

These files are intended to provide reproducible inputs and documentation to reproduce ACPO experiments. The repo stores both human-friendly formats (CSV/YAML) and a streaming training/evaluation format (`CBT-Bench_full.jsonl`).

## Provenance, privacy & ethics

- The `research_output.md` documents that data were collected under ethical guidelines and patient consent. Before any public distribution, confirm and attach the IRB/consent documentation.
- Do not assume these files are safe for public release. Maintainers must verify that no PII/PHI is included in `CBT-Bench_full.jsonl` or other files. If any identifying information exists, either redact it or move the sensitive dataset to a gated/private storage and replace with a synthetic sample in this repo.
- If you plan to publish or share slices of the data externally, get explicit approval from the data owners and legal/ethics teams.

## Quick start — usage examples

Python examples you can run locally (assumes appropriate packages installed):

1) Load the CSVs with pandas (exploration):

```python
import pandas as pd

df = pd.read_csv('datasets/mental_health/csv/reddit_depression_scores.csv')
print(df.head())
```

2) Stream the JSONL for training/evaluation:

```python
import json

with open('datasets/mental_health/jsonl/CBT-Bench_full.jsonl', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        record = json.loads(line)
        # record expected to contain fields like: transcript, mood_scores, physio_signals, metadata
        if i > 10:
            break
```

3) Load YAML metadata:

```python
import yaml

with open('datasets/mental_health/yaml/reddit_depression_scores.yaml') as fh:
    meta = yaml.safe_load(fh)
    print(meta)
```

## Recommended minimal preprocessing

- Text transcripts: tokenization (use the tokenizer your model expects), optional lowercasing, stop-word removal or lemmatization as relevant. Preserve timestamps or speaker labels if present.
- Physiological signals (HR, GSR, etc.): apply smoothing (e.g., low-pass filter), baseline normalization per-subject, and range checks to detect sensor errors or dropouts.
- Mood/self-report scales: re-scale to a 0–1 range and document the original scale in metadata.
- For reproducibility, fix random seeds and record library versions used during preprocessing and training.

## Validation suggestions (small dataset validator)

Add a validator script (suggested filename: `datasets/mental_health/validate_datasets.py`) to check:

- CSV/YAML/JSONL parseability
- Required fields in `CBT-Bench_full.jsonl` (e.g., `transcript`, `id`, `metadata`, `mood_scores`)
- Type and range checks for physiological signals and mood scores
- No obviously-identifying strings (optionally run a heuristic PII detector)
- Row counts and basic statistics (min, max, null counts)

This validator can be wired into CI to prevent accidental corruption or inclusion of sensitive data.

## Access & licensing

- Confirm the license and sharing restrictions for each data source before redistribution. If a dataset is restricted, document the access process in `datasets/mental_health/README.md` and add a placeholder file (e.g., `datasets/mental_health/ACCESS.md`) with instructions for requesting access.
- If possible, provide small synthetic examples for public usage while keeping protected data gated.

## Contact & suggested reviewers

- For questions about dataset contents, provenance, or redaction, contact the dataset owner or the ACPO experiment lead (add names/emails in this section as appropriate).
- Suggested reviewers for PRs touching these files:
  - dataset maintainers for `datasets/mental_health`
  - ethics/data-governance (IRB/privacy) reviewer
  - the ACPO experiment lead

## Next steps

1. Confirm redaction/IRB/consent artifacts and attach them to the repository or PR.
2. Add a small `validate_datasets.py` script and wire it into CI as a lightweight check.
3. Optionally add a short `examples/` notebook showing ingestion and a reproducible preprocessing pipeline.

---

If you want, I can create the validator script and a minimal notebook example next — tell me which you'd prefer first.
