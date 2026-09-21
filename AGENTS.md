# AGENTS.md — FakeArt

Orientation for AI agents (and humans) working in this repository. Read this before touching anything.

## What this project is

**FakeArt** is a psychology / neuroaesthetics study run by the [Reality Bending Lab](https://realitybending.github.io/) (Dominique Makowski, University of Sussex; co-authors Ana Neves, Giulia Cabbai, Marco Sperduti). Public repo: <https://github.com/RealityBending/FakeArt>. Preregistration: <https://osf.io/xbrhe>.

**Research question.** Is the well-documented "anti-AI bias" in art appreciation a *generic* penalty for non-original / non-authentic works, or something *specific* to algorithmic authorship? To disentangle these, participants view 48 genuine human paintings (from the Vienna Art Picture System, VAPS), each falsely labelled as one of three conditions:

| Condition label (data) | Cue shown to participant | Meaning |
|---|---|---|
| `Human Original` | "Original" | authentic human work |
| `Human Forgery` | "Human Forgery" | human-made copy/imitation |
| `AI-Generated` | "AI-Generated" | synthetic |

Only *beliefs* are manipulated; every stimulus is a real human artwork. Two orthogonal belief dimensions are then probed: **Syntheticness** (AI vs. Human, stored as `Reality`) and **Authenticity** (Copy vs. Original).

Working manuscript title: *"Not All Fakes Are Equally Ugly: Disentangling the role of Syntheticness and Authenticity Beliefs in Aesthetic Experience"*.

## Study design (three parts)

1. **Phase 1 — Aesthetic judgment** (jsPsych, webcam eye-tracking via WebGazer). 48 trials. Each: label cue → fixation → image (5 s) → four ratings: `Beauty` (analog slider, −3..3), `Valence` (7-pt pictorial, −3..3), `Meaning` (0–6), `Worth` (6-pt log-money: $0, $10, $100, $1k, $10k, $100k). Random catch trials ask "what was the label?" (→ `Task_AttentionCheck`). Ends with a manipulation-check "feedback" questionnaire (`Feedback_*` columns, `ManipulationDistrust`).
2. **Questionnaires** (shuffled order): MINT (interoception, 11 subscales), VVIQ (imagery), PHQ-4 (+ life satisfaction), BAIT-14 (beliefs/attitudes about AI images). Each has an attention check.
3. **Phase 2 — Reality beliefs.** Cover story partially revealed ("some labels were randomized"). Each image re-shown 1.5 s, then two sliders: `Reality` (AI ↔ Human) and `Authenticity` (Copy ↔ Original), both −100..100.
4. **Follow-up — Memory task** (separate jsPsych app in `memory/`, run ~47 days later, range 36–58; 220 of 324 participants completed it). 96 images (48 old + 48 matched new). Per image: `Beauty2`, `SelfRelevance` (0–6), old/new `Recognition`; if "Yes" → `SourceCondition` (which label?) and `SourceBelief` (own Phase-2 belief in 4 categories); if "No" → `PerceivedArtificiality`.

Stimuli: 4 styles × 4 valence/arousal quadrants × 3 = 48 (see `Emotion` column: Positive/Negative × Low/High intensity, derived from VAPS norms).

Recruitment: Prolific (main), SONA, SurveySwap. Data collection is complete (324 participants after exclusions, as of 2026-09-20).

## Repository layout

```
FakeArt/
├── README.md               # public links (GitHub Pages renders this repo)
├── AGENTS.md               # this file
├── experiment/             # MAIN jsPsych experiment (Phase 1 + questionnaires + Phase 2)
│   ├── index.html          # timeline assembly; DataPipe save (experiment_id DoOfdX2FFR4H)
│   ├── fiction.js          # task: condition assignment, cue, image, ratings, catch trials, feedback
│   ├── demographics.js, questionnaires.js, eyetracking.js
│   ├── media/
│   └── stimuli/
│       ├── stimuli/*.jpg   # 48 VAPS images
│       ├── stimuli_data.csv, stimuli_list.js   # item metadata + VAPS norms
│       └── stimuli_selection/  # .qmd deriving the 48 items from VAPS (needs VAPS .sav/.xlsx)
├── memory/                 # FOLLOW-UP jsPsych memory task (same DataPipe id, files prefixed memory_)
│   ├── index.html, memory.js, consent.js, instructions.js
│   ├── stimuli/*.jpg (96), stimuli_data.csv (Status = Old/New), stimuli_list.js
│   ├── stimuli_selection/  # matching of new to old items
│   └── ethics/             # consent, debrief, ethics forms (.docx), preregistration.md
├── pilot/                  # earlier version of experiment/ (different stimuli set). Frozen; do not edit.
├── data/                   # ALL CSVs committed (raw = anonymised but unfiltered; data_ = cleaned)
├── analysis/               # R / Quarto pipeline (see below)
│   ├── 0_preprocessing.R
│   ├── 1_cleaning.qmd
│   ├── 2_eyetracking.qmd
│   ├── 3_models.qmd
│   ├── 4_correlates.qmd
│   ├── server/             # ./hpc driver + models.R registry + SLURM/R scripts for the Sussex HPC (see its README.md)
│   ├── models/             # *.rds fitted brms models (GITIGNORED, 0.2–1 GB each) + contrasts.csv
│   ├── figures/            # exported figures (figure1.png/.pptx is the procedure figure)
│   └── old/                # superseded notebooks (2_analysis, 3_analysis, 4_memory, funs_eyetracking.R)
├── paper/                  # Quarto manuscript, apaquarto extension, bibliography.bib
└── docs/                   # ethics.pdf, recruitment-platform blurbs
```

## Data pipeline (run in order)

| Step | File | Reads | Writes |
|---|---|---|---|
| 0 | `analysis/0_preprocessing.R` | raw DataPipe CSVs from **local Box folder** `C:/Users/domma/Box/Data/FictionArt/` (not in repo) | `data/rawdata_participants.csv`, `rawdata_task.csv`, `rawdata_eyetracking{1,2}.csv`, `rawdata_memory_participants.csv`, `rawdata_memory_task.csv` |
| 1 | `analysis/1_cleaning.qmd` | `rawdata_*` | `data/data_participants.csv`, `data_task.csv`, `data_memory_task.csv` |
| 2 | `analysis/2_eyetracking.qmd` | `rawdata_eyetracking*`, `data_participants.csv` | `data/data_eyetracking.csv` |
| HPC | `analysis/server/hpc fit` → `fit_model.R` (per shard) → `hpc combine` → `combine_model.R` | `data_task.csv` + `data_eyetracking.csv` **fetched from GitHub raw URL** | `analysis/models/<Model>.rds` via `hpc pull` |
| 3 | `analysis/3_models.qmd` | `data_*`, `models/*.rds` | HTML report + Markdown twin (`3_models.html.md`, via `keep-md`), figures, **`data/results_contrasts.csv`** (every contrast x parameter, overall and per emotion quadrant) and **`data/results_means.csv`** (marginal means per condition). The report is written to be machine-readable: per model a convergence table, marginal means, the full coloured contrast table with a folded Markdown twin, and an auto-generated summary of credible effects; see its "How to read this report" section. |
| 4 | `analysis/4_correlates.qmd` | `models/*.rds` (eval: false), `data_grouplevel.csv` | `data/data_grouplevel.csv` (per-participant model parameters) |

Notes on step 0: anonymises participants to `S001…` by start date; skips test runs (`researcher` in `test`, `testp`, `README`, case-insensitive); joins VAPS norms and renames them `Norms_*`. Raw files are never in the repo. Recruitment tags in the data: `prolific`, `os`, `fw`, `dm` (lab members), `mia` (master's student, summer 2026). Check `Age`, duration and attention scores of lab-collected files: students sometimes run the task on themselves without a test tag.

Notes on step 1: excludes participants failing ≥50% of task catch trials (`exclude$checks`); questionnaire data set to NA (not excluded) when the questionnaire attention check fails; Phase-2 data set to NA for participants with no variability or implausibly high label congruence. All outcomes are **rescaled to 0–1** in `data_task.csv` (`Beauty`, `Valence`, `Meaning`, `Worth`, `Reality`, `Authenticity`, `Beauty2`, `SelfRelevance`, `PerceivedArtificiality`). Downstream scripts rescale back (e.g. `Meaning * 6`, `Valence * 6 + 1`, `Worth` → ordered factor with dollar labels).

Notes on step 2: strict webcam-gaze QC; coordinates normalised to stimulus width, centred on the image. Output features: `Gaze_Entropy`, `Gaze_Shift`, `Gaze_pLeft`, `Gaze_pCenter`, `Gaze_pTop`, `Gaze_nSamples`.

## Statistical modelling

All models are Bayesian (`brms` + `cmdstanr`), fit on the HPC, with formula pattern
`Outcome ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item)` (plus distributional parameters). Families are matched to each outcome's distribution:

| Outcome | Family | Package |
|---|---|---|
| Beauty, Beauty2, Reality, Authenticity, PerceivedArtificiality | `choco()` (Choice-Confidence Beta mixture: `mu`, `confright/left`, `precright/left`, `pex`, `bex`, `pmid`) | `cogmod` |
| Valence | `betadiscrete()` with `pzero = 0` | `cogmod` |
| Meaning | `betadiscrete()` zero-inflated | `cogmod` |
| Worth, SelfRelevance | `cumulative()` ordinal | brms |
| Gaze_Entropy | `Beta()` | brms |
| Gaze_pLeft, Gaze_pCenter | `zero_one_inflated_beta()` | brms |
| Gaze_Shift | `lognormal()` | brms |

`cogmod` is the lab's own package (<https://github.com/DominiqueMakowski/cogmod>). Analyses use the `easystats` ecosystem (`modelbased::estimate_means/contrasts`, `marginaleffects` backend).

**HPC workflow** (`analysis/server/`, rewritten 2026-09-20 to the lab's standard layout, same as IllusionGameComputational). `models.R` is the registry: one entry per model (13 of them, named after the `.rds` files the notebooks read). `./hpc` drives the Sussex Artemis cluster over SSH: `./hpc push`, `./hpc fit <model|all>` (one SLURM array of 8 shards per model, each shard 2 chains × 8 threads), `./hpc queue` / `./hpc progress <model>` to watch, `./hpc combine <model>` to merge shards and add `loo`, `./hpc pull` to bring `combined/<model>.rds` into `analysis/models/`. Everything is parameterised by `FA_*` environment variables; nothing is hard-coded to one account. The cluster reads the data from GitHub `main`, so push data before fitting. `analysis/server/README.md` is the command reference and `AGENT.md` the project-specific notes. `server.md` and `hpc.local` are gitignored (credentials, per-machine account).

Fitted `.rds` files live in `analysis/models/` but are gitignored (too large). Without them, chunks in `3_models.qmd` that call `readRDS("models/...")` will fail; the notebook relies on Quarto `cache: true` (`3_models_cache/`) and `knitr::load_cache` for the Summary section.

## Experiment code conventions

- Plain jsPsych 8.2 loaded from unpkg CDNs; no build step. Test locally by opening `index.html` or via GitHub Pages with `?exp=README` (test data is skipped by preprocessing).
- URL variable `exp` sets recruitment source (`prolific`, `SONA`, or a researcher tag); `prolific_id` / `sona_id` are captured in `browser_info`. Completion codes are hard-coded in `index.html`.
- Every trial writes a `screen` field in `data`; `0_preprocessing.R` filters on these names (`fiction_cue`, `fiction_image1`, `fiction_ratings1`, `fiction_ratings2`, `memory_ratings`, `questionnaire_*`, etc.). **Renaming a screen breaks preprocessing.**
- Conditions are assigned per style in `assignCondition()` (balanced thirds, shuffled). Condition strings in JS are `AI`, `Human`, `Forgery`; R maps them to the full labels.
- Data saving goes through jsPsych DataPipe (OSF). Both experiment and memory task share one DataPipe project; memory files are prefixed `memory_`.

## Manuscript

`paper/manuscript.qmd` renders with the `apaquarto` extension to PDF/DOCX/HTML (`quarto render` inside `paper/`). Bibliography in `paper/bibliography.bib`. Figures are referenced from `../analysis/figures/`. Introduction and Methods are drafted; Participants, Results, Discussion and Abstract are still `TODO`. Bracketed bold `**TODO**` / `**REF**` markers flag missing citations or numbers.

## Current state (as of 2026-09)

- Data collection and cleaning: done.
- Models: all 13 fitted in July 2026 with the previous scripts (family names `choco`/`betadiscrete`; `3_models.qmd` has a compatibility shim in its `helpers` chunk so the new cogmod can post-process them, to be removed after the refit); those fits predate the 2026-09-20 data update (+1 participant, eye-tracking fix) and the cogmod API rename. A refit with the new `analysis/server/` layout is pending; existing shards on the cluster must be cleared or `FA_FILE_REFIT=always` used.
- `3_models.qmd` is the active analysis notebook (Phase 1/2/follow-up sections, Summary, and Python/matplotlib GIF animations of Beauty distributions).
- `4_correlates.qmd`: extracting per-participant parameters into `data_grouplevel.csv`, then factor analysis / EGA and correlation with questionnaires. Early stage.
- Manuscript: Introduction and Methods drafted; Results not yet written.
- Uncommitted work exists in `3_models.qmd`, `4_correlates.qmd`, server scripts and the manuscript.

## Working rules for agents

- **Do not modify `pilot/`, `analysis/old/`, or anything in `data/rawdata_*`** unless explicitly asked; they are historical records.
- Do not edit `data/data_*.csv` by hand; regenerate via the pipeline.
- Rendered HTML (`analysis/*.html`, `*_files/`) is committed because GitHub Pages serves it. Re-render rather than hand-edit.
- `*_cache/`, `*.knit.md`, `analysis/models/*.rds`, `analysis/server/server.md`, `analysis/server/hpc.local` are gitignored on purpose.
- R style: tidyverse + easystats, native pipe `|>`, `Participant` / `Item` / `Condition` / `Emotion` as canonical grouping columns. Colours for conditions are defined in `cols` at the top of `3_models.qmd`.
- Windows machine; Dropbox-synced folder. Avoid generating large temporary files inside the repo.
- Commit messages in this repo are short and informal; keep that style.
