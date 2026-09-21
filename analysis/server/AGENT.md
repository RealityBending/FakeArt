# AGENT.md — running FakeArt on Artemis

Operational notes for driving the Sussex Artemis HPC from this repo.
`README.md` is the command reference; this file is the *why*, what has and
has not been measured for this project, and what is still open.

Rewritten 2026-09-20 to the layout used by IllusionGameComputational
(`analysis/server/` there, same `./hpc` design). Its `AGENT.md` holds the
cluster-level measurements (partition quotas, the toolchain, the precompiled
header race, sshd rate limiting, `--time` policy). They are cluster facts and
are not repeated here beyond what `README.md` needs; read that file before
changing a `.slurm` setting.

**Renamed on 2026-09-20**, so that older notes and job logs still make sense:
`make_models.R` → `fit_model.R` (fits *one* model, named by `FA_MODEL`),
`make.slurm` → `fit.slurm`, `combine_models.R` → `combine_model.R`.
`models.R`, `hpc`, `install_pkgs.R`, `precompile.R`, `setup-ssh.sh` are new.
The old scripts fitted whichever blocks were uncommented in one 500-line file,
which is how a run of the wrong model used to happen.

---

## 1. Quick start

```
bash analysis/server/setup-ssh.sh   # once per machine (no-op if IGC already did it)
cd analysis/server
./hpc check                         # VPN + SSH
./hpc setup                         # once per account: project dirs
./hpc push
./hpc fit Beauty                    # one array job per model
./hpc queue ; ./hpc progress Beauty
./hpc combine Beauty ; ./hpc pull
```

The **GlobalProtect VPN** (portal `bond.sussex.ac.uk`) must be up for any of it.

---

## 2. What is FakeArt-specific

### 2.1 The dataset

`data/data_task.csv` merged with `data/data_eyetracking.csv`: 324 participants
× 48 items = 15,552 trials after cleaning (as of 2026-09-20). Outcomes are
observed on subsets:

| outcome | rows | participants | why |
| --- | --- | --- | --- |
| Beauty, Valence, Meaning, Worth | 15,552 | 324 | Phase 1, everyone |
| Reality, Authenticity | 15,216 | 317 | Phase 2 dropped for 7 participants in `1_cleaning.qmd` |
| Gaze_Entropy, pLeft, pCenter | 11,947 | 268 | trials/participants passing the gaze QC in `2_eyetracking.qmd` |
| Gaze_Shift | 11,500 | 267 | as above, minus trials with no measurable shift |
| Beauty2, SelfRelevance | 10,560 | 220 | follow-up session only |
| PerceivedArtificiality | 6,009 | 220 | follow-up, items judged "new" only |

`fit_model.R` drops the NA rows of the model's own outcome and prints the
resulting counts on the `participants:` line of the `.out`; check it against
this table.

At ~15k rows this is **20× smaller than the IGC dataset** (324k rows), and the
models are simpler in the likelihood (no numerical quadrature), but the
random-effects structure is heavier: `(Condition * Emotion | Participant)` is a
12 × 12 correlation matrix per distributional parameter, × up to 5 dpars for
CHOCO, over 324 participants. That is where the time goes.

### 2.2 The families

Five CHOCO models (`cogmod_choco()`) for the analog sliders, two Discrete-Beta
(`cogmod_betadiscrete()`) for the 7- and 0..6-point scales, two `cumulative()`
for the ordered money and self-relevance scales, and four native brms gaze
models. See the table in `README.md`.

The cogmod API moved between the July 2026 fits and now (`choco()` →
`cogmod_choco()`, family-generic `cogmod_stanvars(f)`); the dpar names did
not, so the notebooks are unaffected. On 2026-09-20 `cogmod_priors()` and
`cogmod_inits()` gained CHOCO / Discrete-Beta support (0.3.3 dev, commit
`d04c7f8`), and the scripts use them: `fa_priors()` fills only what
`cogmod_priors()` leaves flat, and `fa_inits()` calls `cogmod_inits()`
directly, with no `init = 0` fallback for cogmod families. The shared cluster
library was refreshed to that commit the same evening (`./hpc install cogmod`,
built 20:17 UTC). Consequence for comparability: the July fits used
`normal(0, 2)` / `normal(0, 1)` slopes on every dpar; cogmod now puts
`normal(0, 0.5)` on the auxiliary dpars' slopes, so a refit is more tightly
regularised there.

**Until the refit, the notebook carries a shim.** `3_models.qmd` (chunk
`helpers`) aliases `posterior_epred_choco`, `posterior_predict_choco`,
`log_lik_choco` and the `betadiscrete` equivalents to the new `cogmod_*`
methods, because brms resolves a custom family's post-processing by the family
*name* stored in the fit, and the July fits store `choco` / `betadiscrete`.
Verified 2026-09-20: marginal means computed through the shim reproduce the
cached response contrasts to 3 decimals. Delete the shim block once
`analysis/models/` holds fits made with `cogmod_choco()`.

### 2.3 Data comes from GitHub `main`

`fit_model.R` reads the two CSVs from the raw GitHub URL. The 2026-09-20 data
update (participant S360 added; the eye-tracking duplication bug fixed in
`0_preprocessing.R`) was pushed to `main` the same evening, so the cluster sees
it. **Every shard on the cluster from July predates it**, but they sit in
scratch under the old `_task_` naming (§3.2a) and cannot be adopted by the new
array, so a fresh `./hpc fit` starts clean. `2_eyetracking.qmd` has not been
re-run since the fix, so `data_eyetracking.csv` on `main` is still the
pre-fix version; the four gaze models should wait for that.

---

## 3. What has been measured, and what has not

Everything in this section is honest about its provenance.

### 3.1 Measured: the local smoke test (2026-09-20)

All 13 registry models build their Stan code and priors from the real data
(`brms::make_stancode`, no compilation), and `fit_model.R` → `combine_model.R`
ran end to end on a laptop for `Meaning` (2 shards, 6 participants, 40 + 20
iterations, 1 chain) and `Beauty` (1 shard). The commands are in `README.md`,
"Smoke tests". This checks the plumbing, not the sampler.

### 3.1a Measured: the cluster smoke test (2026-09-20)

Submitted with the commands in `README.md` ("Smoke tests"): 20 participants,
warmup 200 + 100 samples, thin 1, 2 chains × 4 threads on `short`
(`--array=1-2 --cpus-per-task=8 --mem=16G`), own `FA_MODELS_DIR=.../smoke`,
data read from GitHub `main`. Wall time includes Stan compilation.

| model | shard | wall | n_leapfrog | treedepth | divergent | max Rhat | n params |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Beauty (CHOCO) | 1 | 2.5 min | 93 | 6.5 | 0.000 | 1.13 | 2,280 |
| Beauty (CHOCO) | 2 | 2.6 min | 106 | 6.6 | 0.000 | 1.12 | 2,280 |
| Meaning (Discrete Beta + hurdle) | 1 | 7.1 min | 86 | 6.2 | 0.145 | 1.18 | 1,445 |
| Meaning (Discrete Beta + hurdle) | 2 | 5.8 min | 86 | 6.1 | 0.210 | 1.25 | 1,445 |

`./hpc combine Beauty` on those two shards (`--partition=short --mem=16G`):
2 shards found, `loo` over 400 draws in 0.1 min, `combined/Beauty.rds`
written, exit 0. So the whole loop (push → fit → progress → combine) works on
the current toolchain: module `CmdStanR/0.7.1-foss-2023a-R-4.3.2`, shared
library with cogmod 0.3.3 `dev`, CmdStan 2.39.0 with its PCH already built.

Rhat and divergences at 300 iterations on 20 participants say nothing about
production; the numbers are here as the baseline the first full `REPORT`
lines will be compared against. One thing they do say: **Meaning is ~2.5×
slower per iteration than Beauty** at the same size, despite fewer parameters.
The Discrete-Beta likelihood (two Beta CDF evaluations per observation) is
the cost. Watch it on the first full run.

**Re-run the same evening with cogmod `d04c7f8`** (CHOCO / Discrete-Beta
support in `cogmod_priors()` and `cogmod_inits()`, so cogmod's slope priors
and data-informed inits instead of the hand-filled priors and `init = 0`),
identical settings, `FA_MODELS_DIR=.../smoke2`:

| model | shard | wall | n_leapfrog | treedepth | divergent | max Rhat |
| --- | --- | --- | --- | --- | --- | --- |
| Beauty (CHOCO) | 1 | 2.1 min | 127 | 7.0 | 0.000 | 1.16 |
| Beauty (CHOCO) | 2 | 2.1 min | 63 | 6.0 | 0.000 | 1.13 |
| Meaning (Discrete Beta + hurdle) | 1 | 4.4 min | 72 | 6.0 | 0.030 | 1.16 |
| Meaning (Discrete Beta + hurdle) | 2 | 4.5 min | 62 | 6.0 | 0.040 | 1.10 |

Same plumbing, better sampler: Meaning's divergences fell from 15-21% to
3-4% and its wall time from 5.8-7.1 to 4.4-4.5 min, with fewer leapfrog
steps; Beauty was already clean and is unchanged. At 300 iterations these are
indications, not measurements, but they point the same way as IGC's
experience with `cogmod_inits()` (their §4.5): the informed start buys back
warmup.

Both smoke directories (`smoke/`, `smoke2/`) and their logs were deleted from
the cluster the same evening; `users/FakeArt/models/` is empty apart from
`combined/`, ready for production shards.

### 3.2 Inherited, not re-measured: the production settings

`fit.slurm`'s defaults (8 shards × 16 CPUs × 32 GB on `long`; warmup 5,000,
800 iterations thinned by 2, 2 chains per shard) are **what the July 2026
production fits used**, with `R/4.4.1` and the old cogmod. Those fits
completed and produced the `.rds` files the notebooks were written on (0.2 to
1 GB each on disk), so the settings are known to be sufficient; their wall
time was not recorded. Expect a CHOCO model at full data to take many hours
per shard; the first production run under the new toolchain should be watched
with `./hpc progress` and its `REPORT` line kept here.

**Open**: fill in a wall-time table after the first refit.

| model | shards | wall/shard | n_leapfrog | divergent | max Rhat |
| --- | --- | --- | --- | --- | --- |
| *(none yet under the 2026-09 scripts)* | | | | | |

### 3.2a Measured: the cluster state at the rewrite (2026-09-20, via `./hpc sh`)

- `./hpc check`, `./hpc setup` and `./hpc push` work from this machine; the
  push removed the old `make_models.R` / `make.slurm` / `combine_models.R`
  from `/mnt/lustre/users/psych/dmm56/FakeArt/`.
- The shared library already holds **cogmod 0.3.3 (`dev`, commit `7ac11be`,
  built 2026-09-20 09:54 UTC)** and the account has CmdStan 2.39.0 with the
  `model_header_threads_nochecks_12_3.hpp.gch` variant present, so
  `./hpc install` and `./hpc precompile` are both no-ops here today.
- The July shards live in **scratch**, not in the new `models/`:
  `/mnt/lustre/scratch/psych/dmm56/FakeArt/models/<Model>_task_<n>.rds`
  (5 GB: Artificiality, Authenticity, Reality, SelfRelevance; the Phase 1 and
  gaze shards were apparently already removed) with the combined files beside
  the logs in `/mnt/lustre/scratch/psych/dmm56/FakeArt/<Model>.rds`. The new
  shard pattern `<Model>_<n>.rds` does not match `_task_`, so they cannot be
  adopted by a resumed array. Delete them once the refits exist.

### 3.3 Inherited from IGC: the toolchain and the traps

Module `CmdStanR/0.7.1-foss-2023a-R-4.3.2` + the shared project library
(`cluster_R_libs/.../4.3`, holding cogmod, a current cmdstanr, datawizard,
loo). Measured there, not here: compute nodes need `module use` of the
EasyBuild tree; `module` is undefined in a batch shell; the CmdStan
precompiled header races on a cold array; sshd rate-limits connection bursts;
the `.slurm` files must propagate R's exit status; do not set `--time` below
the partition's maximum. All of these are handled in the scripts and explained
in `README.md`.

One consequence specific to sharing the library: `FA_COGMOD_REF` defaults to
`dev`, because IGC's fits need cogmod ≥ 0.3.3 (dev until merged) and
`./hpc install cogmod` from either project refreshes the same library.

### 3.4 Not measured: `combine` memory

`combine.slurm` asks for 64 GB / 4 CPUs on `general`. The pointwise
log-likelihood matrix is 6,400 draws × ≤ 15,552 responses ≈ 0.8 GB; the eight
shards of a CHOCO model are ~1 GB each on disk and larger in memory. 64 GB is a
guess with margin, not a measurement. If a combine job is killed for memory,
raise `--mem` on the command line (`./hpc combine Beauty --mem=128G`) and
record the peak here.

---

## 4. Design decisions

### 4.1 One job per model, `models.R` as the single definition

Same reasoning as IGC §5.1. The old `make_models.R` was one file with every
model in it and fitting was done by commenting blocks in and out; which models
a job fitted depended on the state of the file at push time, and `./hpc`
could not validate a model name. Now `./hpc fit <name>` is refused unless the
name is declared in `models.R`, every log is named after its model, and adding
a model is one list entry.

### 4.2 Per-model NA filtering in `fit_model.R`, not in the registry

Each registry entry names its `outcome`; `fit_model.R` drops the rows where it
is NA. This replaces the `dftask[!is.na(dftask$Reality), ]` that was repeated,
and once forgotten (`Valence`, `Meaning` ran on the full frame, harmlessly),
in the old script.

### 4.3 Priors filled against what brms leaves flat

`fa_priors()` starts from `cogmod_priors()` / `get_prior()` for the model in
hand and only edits rows, so a prior that matches nothing is impossible and a
formula change does not orphan a prior list. The fill values (slopes `normal(0, 2)`,
interactions `normal(0, 1)`, cogmod intercepts `normal(0, 3)` / `normal(0, 5)`)
are the July 2026 values, but they now apply only where `cogmod_priors()` left
a row flat, which for CHOCO is the main (`mu`) slopes and nothing else: IGC's
lesson (their §5.7) is that cogmod's family priors are tighter than a blanket
on purpose, and overriding them widened exactly what cogmod had tightened.
The main intercept keeps brms's `student_t(3, 0, 2.5)`.

The old script also had two bugs the rewrite removes: the `Shift` block built
its tightened priors into `priors_pleft` and then fitted with the untightened
`priors_shift`, and the `pLeft`/`pCenter` blocks declared `zoi`/`coi` in the
formula while passing `family = Beta()` to `brm()` (the `bf()` family wins in
brms, so the fits were ZOIB as intended, but the code said otherwise).

### 4.4 `loo` over all draws, shards kept

IGC measured (their §4.8) that `loo` over every draw costs minutes against an
8 h wall and that subsampling degrades `r_eff`; the same defaults apply here on
a dataset 20× smaller. The old `combine_models.R` used `waic` with
`ndraws = 1500` and deleted nothing; `FA_CRITERION=waic` restores the former.
The notebooks currently use neither criterion, so this is free to change.

### 4.5 Everything is parameterised by environment variable

So the `.slurm` files contain nothing account-specific and a second account
needs only `hpc.local`. The `FA_` prefix keeps them apart from IGC's `IGC_`
variables when both projects are driven from the same shell.

---

## 5. Open questions

1. **Wall time per shard** under the new toolchain (§3.2). Unknown until the
   first refit; the `REPORT` lines answer it.
2. **Combine memory** (§3.4).
3. **Whether to refit everything.** The current `analysis/models/*.rds` predate
   the 2026-09-20 data changes (+1 participant; the eye-tracking fix affects
   which trials/participants enter the four gaze models once `2_eyetracking.qmd`
   is re-run). Ratings models change by one participant in 324; gaze models
   may change more. Decide per model; the registry makes a partial refit
   cheap.
4. **cogmod ≥ 0.3.3 and CHOCO.** The floor here is 0.3.1 (API). If a later
   cogmod changes the CHOCO/Discrete-Beta numerics, the fits should be
   re-run together so the notebooks compare like with like.

---

## 6. File map

| file | role |
| --- | --- |
| `hpc` | driver (see `README.md`) |
| `models.R` | registry + `fa_prepare_data()`, `fa_priors()`, `fa_stanvars()`, `fa_inits()` |
| `fit_model.R` / `fit.slurm` | one shard of one model |
| `combine_model.R` / `combine.slurm` | merge one model's shards |
| `install_pkgs.R`, `precompile.R`, `setup-ssh.sh` | environment |
| `README.md` | command reference |
| `server.md`, `hpc.local` | gitignored: credentials / per-machine account |
