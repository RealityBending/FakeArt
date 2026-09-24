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
4. **Follow-up — Memory task** (separate jsPsych app in `memory/`, run ~47 days later, range 36–58; 220 of 324 participants completed it). Participants are first told explicitly that *all* Phase-1 artworks were genuine human originals. 96 images (48 old + 48 matched new). Per image: `Beauty2` (same slider as Phase 1), `SelfRelevance` (0–6: how much the work relates to one's own experiences/personality/life), old/new `Recognition`; if "Yes" → which label it had in Phase 1 (raw `SourceCondition`, renamed **`AnswerCondition`** in the cleaned data) and which of four categories one's own Phase-2 belief fell in (raw `SourceBelief` → **`AnswerBelief`**: Human Original / Human Forgery / AI Original / AI Copy); if "No" → `PerceivedArtificiality` (−1..1, how easily it could be AI). See "Memory-task file" below for the derived columns.

Stimuli: 4 styles × 4 valence/arousal quadrants × 3 = 48 (see `Emotion` column: Positive/Negative × Low/High intensity, derived from VAPS norms).

Recruitment: Prolific (main), SONA, SurveySwap. Data collection is complete (324 participants after exclusions, as of 2026-09-20).

## Research questions and theoretical framing (digest of `paper/manuscript.qmd`)

Read this instead of the manuscript's Introduction. The paper asks four questions; each maps onto specific columns and models.

| # | Question | Where it lives in the data / analysis |
|---|---|---|
| 1 | Is the anti-AI bias a *generic* non-originality penalty or *specific* to algorithmic authorship? | The three-way `Condition` contrast on the Phase-1 ratings. **Human Forgery is the crux**: if AI ≈ Forgery the bias is an authenticity penalty; if AI < Forgery there is something AI-specific. Phase-2 `Reality` / `Authenticity` then test whether each label was encoded as syntheticness or as authenticity. |
| 2 | Do the artwork's affective properties (normative valence/arousal) account for judgments independently of the label, and do they moderate the bias? | `Emotion` quadrant (and continuous `Norms_Valence`, `Norms_Arousal`) as predictors and in the `Condition * Emotion` interaction. `3_models.qmd` reports contrasts overall and per quadrant. |
| 3 | Is the bias moderated by self-relevance (does high self-relevance narrow the Human–AI gap)? | `SelfRelevance` (follow-up) as a moderator of the label effect. |
| 4 | Does the label effect persist ~47 days later once participants are told all works were human, and does persistence relate to explicit source memory? | `Beauty2`, `PerceivedArtificiality` by original `Condition`; `Recognition`, `AnswerCondition` (label recall), `AnswerBelief` (recall of own belief) in `data_memory_task.csv`. |

**Exploratory:** interoceptive sensibility (`MINT_*`) is hypothesised to modulate the label effect in *either* direction (weaker if people lean on embodied signals rather than belief-based inference; stronger if it indexes responsiveness to internally generated meaning). Other dispositional correlates: `BAIT_*` (beliefs/attitudes about AI), `VVIQ_Total`, `PHQ4_*`, `LifeSatisfaction`, `Art_Expertise` (→ `7_correlates.qmd`).

**Theoretical anchor.** Leder et al.'s stage model of aesthetic experience (perception → implicit memory integration → explicit classification → cognitive mastering → evaluation). The label is expected to act at the memory-integration / cognitive-mastering stages, i.e. to depress judgments that depend on inferred intention, meaning and personal connection more than perceptually driven ones. The literature reviewed says the anti-AI bias is *belief-driven, not perceptual* (people cannot tell AI from human images blind; the penalty is larger for meaning-laden judgments and under reflective processing; psychophysiology is largely unaffected). Three candidate mechanisms drive the design: (a) attributed originality/authenticity (Newman & Bloom's contagion account; Huang et al. 2011 "copy vs. authentic" Rembrandts) → the Forgery condition; (b) affective response and its interoceptive grounding → stimuli stratified by valence/arousal, MINT; (c) self-relevance (Vessel et al. 2023: personalised synthetic images are liked as much as real art) → `SelfRelevance`. Durability after correction (Q4) is framed via belief perseverance / source-memory literature.

**Key argument for the analysis strategy.** The four Phase-1 dimensions have distinct distributional signatures (Valence symmetric unimodal; Meaning zero-inflated; Worth right-skewed/decaying; Beauty bimodal with anchoring at 0, 1 and midpoint) and are treated as separate constructs, **not** collapsed into one "aesthetic appreciation" factor. That is why each outcome gets its own family (see "Statistical modelling").

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
│   ├── 3_models.qmd, 4_memory.qmd   # read models/estimates/*.rds (see below)
│   ├── 5_realitydeterminants.qmd   # label -> Phase-1 beauty -> reality beliefs (mediation)
│   ├── 6_*.qmd             # planned: self-relevance analyses
│   ├── 7_correlates.qmd
│   ├── report.R            # table helpers, read_estimates(), CHOCO plot helpers; shared by 3_, 4_ and 5_
│   ├── server/             # ./hpc driver + models.R registry + SLURM/R scripts for the Sussex HPC (see its README.md)
│   ├── models/             # GITIGNORED: fitted brms *.rds (0.2–1 GB) + estimates/*.rds (KB, what the notebooks read)
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
| HPC | `analysis/server/hpc fit` → `fit_model.R` (per shard) → `hpc combine` → `combine_model.R` | `data_task.csv` + `data_eyetracking.csv`, or `data_memory_task.csv` for models with `data = "memory"`, **fetched from GitHub raw URL** | `analysis/models/<Model>.rds` via `hpc pull` |
| HPC | `hpc extract <model|all>` → `extract_model.R` → `server/estimates.R::get_estimates()`; `hpc pull 'estimates/*.rds'` | `combined/<Model>.rds` on the cluster | `analysis/models/estimates/<Model>.rds` (means, contrasts, figure data) |
| 3 | `analysis/3_models.qmd` | `data_*`, `models/estimates/*.rds` (renders in ~1 min; opens no fit) | HTML report + Markdown twin (`3_models.html.md`, via `keep-md`), figures, **`data/results_contrasts.csv`** (every contrast x parameter, overall and per emotion quadrant) and **`data/results_means.csv`** (marginal means per condition). The report is written to be machine-readable: per model a convergence table, marginal means, the full coloured contrast table with a folded Markdown twin, and an auto-generated summary of credible effects; see its "How to read this report" section. |
| 4 | `analysis/4_memory.qmd` | `data_memory_task.csv`, `data_participants.csv`, `models/estimates/Memory*.rds` | HTML report + `4_memory.html.md`, `data/results_memory_contrasts.csv`, `data/results_memory_means.csv` |
| 5 | `analysis/5_realitydeterminants.qmd` | `data_task.csv`, `models/estimates/{RealityBeauty,AuthenticityBeauty,Beauty,Reality,Authenticity}.rds` (mediation computed in the notebook by `mediation_effects()` in `server/estimates.R`) | HTML report + `5_realitydeterminants.html.md`, `data/results_determinants_{mediation,slopes,contrasts}.csv` |
| 6 | *(planned)* self-relevance notebook | | |
| 7 | `analysis/7_correlates.qmd` | `models/individual/*.rds` (`./hpc individual`, `get_individual()` in `server/estimates.R`) | HTML report + `7_correlates.html.md`; participant-level indices (link-scale Baseline, Forgery − Original, AI − Original per dpar; plus the `RealityBeauty` beauty slope) |

Notes on step 0: anonymises participants to `S001…` by start date; skips test runs (`researcher` in `test`, `testp`, `README`, case-insensitive); joins VAPS norms and renames them `Norms_*`. Raw files are never in the repo. Recruitment tags in the data: `prolific`, `os`, `fw`, `dm` (lab members), `mia` (master's student, summer 2026). Check `Age`, duration and attention scores of lab-collected files: students sometimes run the task on themselves without a test tag.

Notes on step 1: excludes participants failing ≥50% of task catch trials (`exclude$checks`); questionnaire data set to NA (not excluded) when the questionnaire attention check fails; Phase-2 data set to NA for participants with no variability or implausibly high label congruence. All outcomes are **rescaled to 0–1** in `data_task.csv` (`Beauty`, `Valence`, `Meaning`, `Worth`, `Reality`, `Authenticity`, `Beauty2`, `SelfRelevance`, `PerceivedArtificiality`). Downstream scripts rescale back (e.g. `Meaning * 6`, `Valence * 6 + 1`, `Worth` → ordered factor with dollar labels).

Notes on step 2: strict webcam-gaze QC; coordinates normalised to stimulus width, centred on the image. Output features: `Gaze_Entropy`, `Gaze_Shift`, `Gaze_pLeft`, `Gaze_pCenter`, `Gaze_pTop`, `Gaze_nSamples`.

### Manuscript term ↔ data column

| Manuscript term | Column | Scale in `data_*` (original) | Notes |
|---|---|---|---|
| Beauty | `Beauty` | 0–1 (slider −3..3) | Phase 1 |
| Emotional valence | `Valence` | 0–1 (7-pt, 1..7) | `Valence * 6 + 1` recovers it |
| Meaningfulness | `Meaning` | 0–1 (0..6) | zero-inflated |
| Monetary worth (WTP) | `Worth` | 0–1 in 0.2 steps ($0, $10, $100, $1k, $10k, $100k) | ordinal; results report P(category), e.g. the "$0" option |
| **Syntheticness** | `Reality` | 0–1 (−100 AI .. +100 Human) | **higher = more human**; "more synthetic" = *lower* `Reality` |
| Authenticity | `Authenticity` | 0–1 (−100 Copy .. +100 Original) | higher = more original |
| Beauty (follow-up) | `Beauty2` | 0–1 | memory session |
| Self-relevance | `SelfRelevance` | 0–1 (0..6) | memory session |
| Perceived artificiality | `PerceivedArtificiality` | 0–1 (−1..1) | asked only when `Recognition == "No"`; models use old items judged new (6,009 rows) |
| Entropy | `Gaze_Entropy` | 0–1 | 5×5-grid Shannon entropy, normalised by the max achievable for that trial's n samples |
| Laterality | `Gaze_pLeft` | proportion | share of samples in the left half |
| Centeredness | `Gaze_pCenter` | proportion | share of samples in the central region |
| Max. Shift | `Gaze_Shift` | stimulus widths | largest centroid distance between an initial and a final segment (≥ 30 samples each) |
| Label | `Condition` | `Human Original`, `Human Forgery`, `AI-Generated` | reference level: Human Original. In text: "Originals", "Forgeries", "AI-Generated" |
| Valence × arousal quadrant | `Emotion` | `Positive - High intensity`, `Positive - Low intensity`, `Negative - High intensity`, `Negative - Low intensity` | from VAPS norms (upper/lower tertiles); 12 items each |
| Style | `Style` | `Abstract and Avant-garde`, `Impressionist and Expressionist`, `Romantic and Realism`, `Classical` | 12 items each; `Category` / `Subcategory` are the finer VAPS labels |
| VAPS norms | `Norms_Liking`, `Norms_Valence`, `Norms_Arousal`, `Norms_Complexity`, `Norms_Familiarity` | 0–1 | item-level |
| Manipulation distrust | `ManipulationDistrust` | | from `Feedback_ConfidenceReal` / `Feedback_ConfidenceAI` (confidence that *all* images were real / AI) |
| Interoceptive sensibility (MINT) | `MINT_Card`, `_Resp`, `_Gast`, `_Derm`, `_Urin`, `_SexS`, `_Olfa`, `_Sati`, `_ExAc`, `_RelA`, `_CaCo` | 11 subscales × 3 items | `MINT_AttentionCheck` |
| BAIT-14 | `BAIT_ArtRealistic` (realism beliefs), `BAIT_Positive` / `BAIT_Negative` (GAAIS-derived attitudes), `BAIT_Total`, `BAIT_AI_Knowledge`, `BAIT_AI_Use` | | `BAIT_AttentionCheck` |
| VVIQ, PHQ-4, life satisfaction | `VVIQ_Total`, `PHQ4_Depression`, `PHQ4_Anxiety`, `LifeSatisfaction` | | `ERNS_*` items are also in the file but are not described in the manuscript |
| Delay to follow-up (days) | `Delay` (in `data_participants.csv`) | | NA for the 104 who did not return; `Experiment_StartDate2` is the follow-up date |

### Memory-task file

`data/data_memory_task.csv` has 220 × 96 = 21,120 rows: the follow-up responses joined with the same participant's Phase-1/2 data for that item. Derived in `1_cleaning.qmd`:

- `Type` = `Old` / `New`; `Condition` = the original label, or `New Items`.
- `Recognition` = `Yes` / `No`. `AnswerCondition` (recalled label) and `AnswerBelief` (recalled own Phase-2 belief) are `"Not recognized"` whenever `Recognition == "No"`.
- `Belief` = the participant's *actual* Phase-2 belief, dichotomised at 0.5 on `Reality` × `Authenticity`: `Human Original`, `AI Original`, `Human Forgery`, `AI Copy`; `None` for new items or missing Phase-2 data. So `AnswerCondition == Condition` is label source-memory accuracy and `AnswerBelief == Belief` is accuracy for one's own past belief.
- Old items judged "No" = misses (6,009); new items judged "Yes" = false alarms (1,176).

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
| AnswerCondition (memory: recalled label incl. "Not recognized") | `categorical(link = "logit")`, `~ Condition + (1 + Condition | Participant) + (1 + Condition | Item)`, fitted on `data_memory_task.csv` where `Condition` also has `New Items` | brms |

`cogmod` is the lab's own package (<https://github.com/DominiqueMakowski/cogmod>). Analyses use the `easystats` ecosystem (`modelbased::estimate_means/contrasts`, `marginaleffects` backend).

**HPC workflow** (`analysis/server/`, rewritten 2026-09-20 to the lab's standard layout, same as IllusionGameComputational). `models.R` is the registry: one entry per model (14: the 13 rating/gaze models read by `3_models.qmd` plus `MemoryCondition`, the first memory model for `4_memory.qmd`), named after the `.rds` files the notebooks read; an entry may set `data = "memory"` to be fitted on the follow-up file. `./hpc` drives the Sussex Artemis cluster over SSH: `./hpc push`, `./hpc fit <model|all>` (one SLURM array of 4 shards per model, each shard 2 chains × 8 threads, warmup 1000 + 500 draws → 4,000 draws), `./hpc queue` / `./hpc progress <model>` to watch, `./hpc combine <model>` to merge shards and add `loo`, `./hpc pull` to bring `combined/<model>.rds` into `analysis/models/`. Everything is parameterised by `FA_*` environment variables; nothing is hard-coded to one account. The cluster reads the data from GitHub `main`, so push data before fitting. Default partition is `general` -- every model fits inside its 8 h; `./hpc fit <model> --partition=sussexneuro` is the overflow when a FakeArt job must overlap an IllusionGameComputational one (both projects are the same cluster user, and the CPU caps are per user). **Cluster-level instructions** (access, storage, partitions and quotas, toolchain, job conventions, troubleshooting, housekeeping) live in the lab HPC hub, <https://github.com/RealityBending/Lab/tree/main/hpc> (start at `hpc/README.md`); `analysis/server/README.md` is this project's command reference and `AGENT.md` its project-specific notes (§3.6 for how it uses `sussexneuro`). `server.md` and `hpc.local` are gitignored (local notes, per-machine account).

Fitted `.rds` files live in `analysis/models/` but are gitignored (too large). `3_models.qmd` and `4_memory.qmd` never open them: marginal means, contrasts and figure data are computed on the cluster (`./hpc extract`) and read from `analysis/models/estimates/`. `server/estimates.R` holds that computation and the outcome registries; the notebooks source it for `prep_contrasts()`.

## Sample and QC numbers (as written in the manuscript, 2026-09)

- **Recruited 360**, 36 (11.1%) excluded for failing ≥ 50% of label catch trials → **324** (169 women, 153 men, 2 other; age M = 42.1, SD = 12.9, range 20–82; 74% UK, 21% US). The manuscript says "recruited via Prolific" and that is a deliberate simplification: `Recruitment` in the data also has a few `os` / `fw` / `dm` / `mia` participants (31 in total) recruited through other routes. Do not flag this or add it to the manuscript.
- Questionnaire attention-check failures set to NA: MINT and VVIQ n = 23, BAIT n = 25.
- Phase 2 (`Reality`, `Authenticity`) set to NA for 7 participants (identical ratings for every image, or a pattern indicating misunderstanding) → 317 participants / 15,216 rows.
- Follow-up: **220** participants, delay M = 47 days (SD = 4.4, range 36–58).
- Eye-tracking QC (manuscript numbers = current `data_eyetracking.csv`): 318 had recordings; 15 excluded (> 25% consecutive duplicate samples); samples removed if off-screen or faster than 6 stimulus-widths/s; trials removed if < 20 valid samples, SD < 0.02 or > 0.60 on either axis, < 50% of samples inside the stimulus, drift > 1 width, or near-uniform scatter; 18 excluded for < 2,000 valid samples overall; 11 lost every trial → **12,220 trials from 274 participants (84.6%)**. A preprocessing bug (duplicated eye-tracking rows) was fixed in 2026-09; the four gaze models (Entropy, pLeft, pCenter, Shift) were **refit on the corrected data and pulled into `analysis/models/` on 2026-09-21**.
- Gaze sensitivity check (Methods, "Eye Tracking"): each of the 8 rating outcomes regressed on each gaze feature in turn (mixed models, random intercepts for Participant and Item, controlling `Gaze_nSamples`), effect expressed in % of the outcome's range per SD of the feature. Every feature had at least one credible association, all ≤ ~1% (Entropy positive with most ratings; Max. Shift negative with authenticity/valence/worth). Purpose: show the webcam features carry signal, not to test hypotheses.
- Stimuli: VAPS paintings with familiarity below the sample median; 4 styles; within style, quadrants from the upper/lower tertiles of normative arousal and valence; the 3 items farthest from the style's median per quadrant → 48. New items for the memory task were matched one-to-one within style by minimising Euclidean distance on standardised valence, arousal, liking, complexity and familiarity (Bayesian *t*-tests all BF < 1).
- Cover story: participants were told AI images were made with Midjourney/Stable Diffusion "in a new style *or* inspired by existing artists" (deliberately equivocal so that recognising a real painting under the AI label does not break the manipulation). Phase 2 is a *pseudo-reveal*: "some labels were randomised", so participants still believe originals, forgeries and AI images are present.

## Reporting conventions (match the manuscript)

- Effects are **marginal contrasts between label conditions on the response scale**: posterior median with 95% CI (HDI); an effect is called significant when the CI excludes 0. `3_models.qmd` writes them to `data/results_contrasts.csv` (`Contrast` ∈ `AI-Generated - Human Original`, `Human Forgery - Human Original`, `AI-Generated - Human Forgery`; `Parameter` = `response`, `mu`, other dpars, or `response - <category>` for ordinal models; `Unit` `%` / `raw`; `*_pct` columns; `Effect` ∈ Positive / Negative / n.s.) and marginal means per condition to `data/results_means.csv`. Quote numbers from these files, not from memory.
- Effect sizes are in **% of the scale range**: 0–1 sliders × 100; Valence and Meaning divided by their 6-point range; Worth and Self-Relevance as change in the probability of a category (the manuscript reports the "$0" option); CHOCO auxiliary parameters as probabilities.
- Report `mu` / the response first; auxiliary parameters only where theoretically relevant (`pzero` for Meaning; for Beauty the CHOCO split into the probability of choosing "beautiful" vs. the degree of beauty within that side).
- Sign conventions: for `Reality` a negative contrast = "judged more synthetic / less human"; for `Authenticity` negative = "less original".
- Wording: "Human Originals", "Forgeries", "AI-Generated"; "syntheticness" (not "reality") for `Reality`; "Laterality / Centeredness / Entropy / Max. Shift" for the gaze features; "Phase 1", "Phase 2", "follow-up".

## Results already established (in the manuscript's Results, from the July 2026 fits)

- **Phase 1:** consistent ordering Original > Forgery > AI on all four dimensions. Forgery vs Original: Beauty −3.6%, Valence −3.5%, Meaning −4.2%, P($0) +9.5%. AI vs Original roughly double: −7.0%, −6.2%, −10.5%, +18.3%. AI vs Forgery credible on all four. Meaning `pzero` rises (+0.9% Forgery, +5.1% AI). Beauty CHOCO: both the probability of "beautiful" (−6.7% / −15.9%) and the degree among beautiful (−4.3% / −6.3%) drop.
- **Gaze:** no condition differences on any feature (appraisal changed, visual exploration did not).
- **Phase 2 dissociation:** the AI label lowers `Reality` (more synthetic) vs Original (−5.4%) and vs Forgery (−4.0%), the Forgery label barely (−1.4%); the Forgery label lowers `Authenticity` vs Original (−2.0%), AI less (−1.3%), AI vs Forgery n.s. → AI is encoded as syntheticness, Forgery as authenticity, and beliefs partially persist despite the pseudo-reveal.
- **Follow-up:** the label effect on `Beauty2` is gone (AI −1.0% n.s., Forgery −0.2% n.s.); no effect on `SelfRelevance` or `PerceivedArtificiality`.
- **Still to write:** Effect on Memory (recognition; source memory for the label and for one's own belief), Determinants of Reality Beliefs, Interindividual Differences (reliability of random-effect estimates), Dispositional Factors (questionnaire correlations), Discussion (only the outcome-distribution paragraph exists), Abstract.

## Experiment code conventions

- Plain jsPsych 8.2 loaded from unpkg CDNs; no build step. Test locally by opening `index.html` or via GitHub Pages with `?exp=README` (test data is skipped by preprocessing).
- URL variable `exp` sets recruitment source (`prolific`, `SONA`, or a researcher tag); `prolific_id` / `sona_id` are captured in `browser_info`. Completion codes are hard-coded in `index.html`.
- Every trial writes a `screen` field in `data`; `0_preprocessing.R` filters on these names (`fiction_cue`, `fiction_image1`, `fiction_ratings1`, `fiction_ratings2`, `memory_ratings`, `questionnaire_*`, etc.). **Renaming a screen breaks preprocessing.**
- Conditions are assigned per style in `assignCondition()` (balanced thirds, shuffled). Condition strings in JS are `AI`, `Human`, `Forgery`; R maps them to the full labels.
- Data saving goes through jsPsych DataPipe (OSF). Both experiment and memory task share one DataPipe project; memory files are prefixed `memory_`.

## Manuscript

`paper/manuscript.qmd` renders with the `apaquarto` extension to PDF/DOCX/HTML (`quarto render` inside `paper/`). Bibliography in `paper/bibliography.bib`. Figures are referenced from `../analysis/figures/` (`figure1.png` procedure, `figure2.png` Phase-1 label effects from `3_models.qmd`, `figure3.png` Phase-2 label effects + appraisal path diagram from `5_realitydeterminants.qmd`; `figure4.png` structure and correlates of the participant-level indices from `7_correlates.qmd`, not yet in the manuscript -- it was `figure3.png` until 2026-09-24). Introduction, Methods (incl. Participants, Eye Tracking, Statistical Models) and the first Results subsection ("Effect of Label Condition") are drafted; the remaining Results subsections, Discussion and Abstract are still `TODO` (see "Results already established"). Bracketed bold `**TODO**` / `**REF**` markers flag missing citations or numbers (CHOCO/cogmod preprint, Sciandra 2024 discrete Beta, MINT paper under review, Fictionero preprint, ethics number, Zhang 2025, Wang 2026 unverified).

## Current state (as of 2026-09)

- Data collection and cleaning: done.
- Models: all 15 registry models (13 rating/gaze + `MemoryCondition`, `MemoryBelief`) refitted on the 2026-09-20 data (4,000 draws each), extracted on the cluster and pulled; `3_models.qmd` and `4_memory.qmd` re-rendered from them on 2026-09-22.
- `3_models.qmd` is the active analysis notebook (Phase 1/2/follow-up sections, Summary, and Python/matplotlib GIF animations of Beauty distributions).
- `7_correlates.qmd` (was `5_correlates.qmd`; notebooks renumbered 2026-09-23 to follow the order of the Results section): rewritten 2026-09-22. Participant-level indices (link scale) extracted on the cluster for Beauty, Valence, Meaning, Worth (`mu` + Baseline-only `disc`), Reality and Authenticity; models are added via the `individual` field of `outcome_info`, and the notebook lists the models left out and why. Since 2026-09-24 it also has one determinants index, the participant-level slope of `RealityBeauty`'s `mu` on Phase-1 beauty ("beautiful = human"; `individual` field of `mediation_info`, `get_mediation_individual()`, D-vour ~.45); `ArtificialityBeauty`'s slope (D-vour .67, 220 participants) is noted there as a candidate. Reliability is D-vour (`performance_dvour()`), structure a `cor_sort()` correlation matrix and a bootstrapped hierarchical EGA (`bootEGA(EGA.type = "hierEGA")`, Leiden at the higher order, indices with D-vour > 1/3; the fit chunk is knitr-cached, keyed on the input data). Memory indices (recognition, accuracy, tendencies) get reliability only. Next: dispositional correlates; later Beauty2, SelfRelevance, Artificiality, gaze and memory models. `data/data_grouplevel.csv` is from the old version and no longer written.
- Manuscript: Introduction, Methods and the Phase-1/2/follow-up label-effect Results drafted (numbers from the July fits; re-check against `data/results_contrasts.csv`, which is now from the September refit). Memory, reality-belief determinants, interindividual differences, dispositional correlates, Discussion and Abstract not yet written.
- `5_realitydeterminants.qmd` (2026-09-23): does the label lower reality beliefs directly or through the lower Phase-1 beauty it induced? Models `RealityBeauty` / `AuthenticityBeauty` (`Belief ~ Condition * Beauty_w`, CHOCO; `Beauty_w` = Phase-1 beauty centred within participant) are extracted by `get_mediation_estimates()` (population-level predictions over a `Beauty_w` grid + per-participant mediator means); the notebook's `mediation_effects()` gives total / direct / indirect effects. Extensions (all fitted, extracted and reported in the notebook and the manuscript, 2026-09-23): `RealityBeautyControl` / `AuthenticityBeautyControl` (+ follow-up beauty `Beauty2_w`), `ArtificialityBeauty` (memory file, items judged new, `Type * Beauty2_w`), `RealityAppraisal` / `AuthenticityAppraisal` (beauty, valence, meaning, worth as joint mediators; `get_appraisal_estimates()` / `appraisal_effects()`, first-order unique indirect effects), `RealityItems` / `AuthenticityItems` (style + z-scored VAPS norms; `get_items_estimates()` / `items_effects()`). The notebook also draws a path diagram of the appraisal models (`figures/determinants_diagram.png`) and the manuscript's Figure 3 (`figures/figure3.png`: the `Reality` / `Authenticity` label distributions on top, the diagram below). `RealityBeauty` and `RealityItems` were refit at warmup 3,000 on 2026-09-24 (numbers unchanged, CIs ±0.1; convergence slightly better, see `analysis/server/AGENT.md` §3.7a); those refits are the analysed fits, the warmup-1,000 ones are in `models/w1000_backup/` on the cluster.
- `MemoryCondition`: the analysed fit is the 2026-09-21 one (local `analysis/models/MemoryCondition.rds` and its estimates). Its headline Rhat (1.13) comes from the participant random-effect correlations only; fixed effects max Rhat 1.013, min ESS 558, which was judged acceptable. A refit at warmup 2,000 (job 11407228, 2026-09-23) was worse (per-shard Rhat 1.11-1.34, 2-6% divergent) and was **not** combined, but its shards replaced the originals on the cluster: do not `./hpc combine MemoryCondition` or pull `combined/MemoryCondition.rds` from the cluster over the local file.
- `MemoryConditionBelief` (2026-09-23): `AnswerCondition ~ Condition + Belief` on old items with a recorded belief (registry `subset`), to test whether the recalled label is reconstructed from one's own Phase-2 belief. Registry entries can now set `subset` and/or `prepare` (`function(data) data`), applied in `fit_model.R`.

## Working rules for agents

- **Do not modify `pilot/`, `analysis/old/`, or anything in `data/rawdata_*`** unless explicitly asked; they are historical records.
- Do not edit `data/data_*.csv` by hand; regenerate via the pipeline.
- Rendered HTML (`analysis/*.html`, `*_files/`) is committed because GitHub Pages serves it. Re-render rather than hand-edit.
- `*_cache/`, `*.knit.md`, `analysis/models/*.rds`, `analysis/server/server.md`, `analysis/server/hpc.local` are gitignored on purpose.
- R style: tidyverse + easystats, native pipe `|>`, `Participant` / `Item` / `Condition` / `Emotion` as canonical grouping columns. Colours for conditions are defined in `cols` at the top of `3_models.qmd`.
- Windows machine; Dropbox-synced folder. Avoid generating large temporary files inside the repo.
- Reading a fitted model (`analysis/models/*.rds`, 0.2–1 GB) with `readRDS()` inside the **sandboxed** Bash tool segfaults R (memory cap); the same call works with the sandbox disabled or from a terminal. Local R is 4.5.3 at `C:/Program Files/R/R-4.5.3/bin/Rscript.exe` (not on PATH in Git Bash) with brms 2.23.1, cogmod 0.3.3, cmdstanr 0.9.0.9000; the laptop smoke test in `analysis/server/README.md` runs in ~2 min per model.
- Commit messages in this repo are short and informal; keep that style.
