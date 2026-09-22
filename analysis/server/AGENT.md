# AGENT.md — running FakeArt on Artemis

> **Cluster-level instructions live in the lab HPC hub**:
> <https://github.com/RealityBending/Lab/tree/main/hpc> (start at `hpc/README.md`;
> on Dom's machines: `~/Dropbox/RealityBendingLab/Lab/hpc/`).
> Prefer a local clone of `RealityBending/Lab` if there is one — it also holds
> your gitignored `hpc/private/` notes. The hub covers access, storage,
> partitions and quotas, the R/Stan toolchain, job conventions, troubleshooting
> and housekeeping, and **wins over anything here that contradicts it**; this
> file should only hold what is specific to this project.

Operational notes for driving the Sussex Artemis HPC from this repo.
`README.md` is the command reference; this file is the *why*, what has and
has not been measured for this project, and what is still open.

Rewritten 2026-09-20 to the layout used by IllusionGameComputational
(`analysis/server/` there, same `./hpc` design). Cluster-level facts
(partition quotas, the toolchain, the precompiled-header race, sshd rate
limiting, `--time` policy, `sussexneuro`) are in the lab hub linked above;
read it before changing a `.slurm` setting. "IGC §x" below refers to
measurements of *that project's* models in its `analysis/server/AGENT.md`.

**Renamed on 2026-09-20**, so that older notes and job logs still make sense:
`make_models.R` → `fit_model.R` (fits *one* model, named by `FA_MODEL`),
`make.slurm` → `fit.slurm`, `combine_models.R` → `combine_model.R`.
`models.R`, `hpc`, `install_pkgs.R`, `precompile.R`, `setup-ssh.sh` are new
(`setup-ssh.sh` moved to the lab hub, `hpc/scripts/`, on 2026-09-22).

The old scripts fitted whichever blocks were uncommented in one 500-line file,
which is how a run of the wrong model used to happen.

**Added 2026-09-22**: `estimates.R`, `extract_model.R`, `extract.slurm` and
`./hpc extract`, which move the notebooks' marginal means and contrasts here.
Neither `3_models.qmd` nor `4_memory.qmd` opens a `brmsfit`; see §4.7.

---

## 1. Quick start

```
# once per machine / account: the lab hub's setup.md
cd analysis/server
./hpc check                         # VPN + SSH
./hpc setup                         # once per account: project dirs
./hpc push
./hpc fit Beauty                    # one array job per model
./hpc queue ; ./hpc progress Beauty
./hpc combine Beauty ; ./hpc pull
```

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
| Gaze_Entropy, pLeft, pCenter | 12,220 | 274 | trials/participants passing the gaze QC in `2_eyetracking.qmd` (post-fix file; the July fits saw 11,947 / 268 and 11,179 for pLeft/pCenter) |
| Gaze_Shift | 11,772 | 273 | as above, minus trials with no measurable shift (July: 11,500 / 267) |
| Beauty2, SelfRelevance | 10,560 | 220 | follow-up session only |
| PerceivedArtificiality | 6,009 | 220 | follow-up, items judged "new" only |

The memory models (`data = "memory"`) read `data/data_memory_task.csv`
instead: 220 participants × 96 items = 21,120 rows, the 48 old items *and*
the 48 new ones, so `Condition` has a fourth level `New Items`. The
categorical outcomes have no NA (`"Not recognized"` stands in when the item
was judged new), so the whole file enters the model.

| outcome | rows | participants | why |
| --- | --- | --- | --- |
| AnswerCondition | 21,120 | 220 | one row per follow-up trial |

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

**The shim is gone (2026-09-22).** Until the refit, `3_models.qmd` (chunk
`helpers`) had to alias `posterior_epred_choco`, `posterior_predict_choco`,
`log_lik_choco` and the `betadiscrete` equivalents onto the new `cogmod_*`
methods, because brms resolves a custom family's post-processing by the family
*name* stored in the fit and the July fits stored `choco` / `betadiscrete`.
Every model in `analysis/models/` is now a 2026-09 refit, verified by reading
the family name back out of the pulled files:

```r
readRDS("models/Beauty.rds")$family$name  # "cogmod_choco"
```

(`Beauty`, `Reality`, `Artificiality` → `cogmod_choco`; `Valence`, `Meaning` →
`cogmod_betadiscrete`.) The alias block was deleted; only
`dchoco <- cogmod::dcogmod_choco` remains, because `get_marginal_densities()`
calls it by that name. The `data = m$data` argument on the
`estimate_prediction()` calls was kept but is now a no-op: the refits read the
current `data_task.csv`, so `nobs()` is 15,552 for the Phase-1 models, matching
`dftask`.

### 2.3 Data comes from GitHub `main`

`fit_model.R` reads the two CSVs from the raw GitHub URL. The 2026-09-20 data
update (participant S360 added; the eye-tracking duplication bug fixed in
`0_preprocessing.R`) was pushed to `main` the same evening, so the cluster sees
it. **Every shard on the cluster from July predates it**, but they sit in
scratch under the old `_task_` naming (§3.2a) and cannot be adopted by the new
array, so a fresh `./hpc fit` starts clean. `2_eyetracking.qmd` was re-run
after the fix (`data_eyetracking.csv` now has 12,220 rows / 274 participants,
the numbers in the manuscript) and the four gaze models were refit on it and
pulled on 2026-09-21 (§3.2, second table). `3_models.qmd` has not been re-run
on those files yet.

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

### 3.2 Measured after the fact: the July 2026 production run

The July 2026 fits used 8 shards × 16 CPUs × 32 GB on `long`; warmup 5,000,
800 post-warmup iterations thinned by 2, 2 chains per shard (Beauty2 and the
four gaze models got 1,000 samples, not 800), with `R/4.4.1` and the old
cogmod, hand-filled priors and `init = 0`. Those were `fit.slurm`'s defaults
until 2026-09-21.

Their wall time was thought to be lost, but **CmdStan's per-chain
warmup/sampling split survives inside the saved fits** and can be read back
without refitting:

```r
rstan::get_elapsed_time(readRDS("models/Reality.rds")$fit)  # seconds, per chain
```

Recovered on 2026-09-21 from `analysis/models/*.rds`. "Wall/shard" is the
slowest chain of the model: a shard runs its 2 chains in parallel, so that is
what the array task took. `s/iter` is the adapted sampling-phase cost. The
transient is the cold-start residual, `warmup_h − 5000 × s/iter`: the part of
warmup that a shorter warmup cannot remove (identity metric at max treedepth,
IGC §4.4.1).

| model | chains | wall/shard | warmup h | sampling h | s/iter | transient | n obs | n params |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reality | 16 | **20.3 h** | 18.56 | 2.13 | 9.59 | 5.25 h | 15,168 | 20,928 |
| Valence | 15 | **15.5 h** | 14.59 | 1.51 | 6.80 | 5.15 h | 15,504 | 8,237 |
| Meaning | 15 | 7.2 h | 6.50 | 0.78 | 3.51 | 1.62 h | 15,504 | 12,353 |
| Beauty | 16 | 5.5 h | 5.00 | 0.54 | 2.43 | 1.62 h | 15,504 | 21,369 |
| Authenticity | 14 | 4.9 h | 4.57 | 0.50 | 2.25 | 1.45 h | 15,168 | 20,928 |
| Beauty2 | 16 | 4.6 h | 4.37 | 0.32 | 1.15 | 2.77 h | 10,560 | 14,880 |
| Artificiality | 14 | 1.6 h | 1.45 | 0.18 | 0.81 | 0.32 h | 6,009 | 14,880 |
| Worth | 16 | 1.2 h | 1.05 | 0.16 | 0.72 | 0.05 h | 15,504 | 5,006 |
| SelfRelevance | 14 | 1.1 h | 0.95 | 0.15 | 0.68 | 0.01 h | 10,560 | 3,669 |
| Entropy | 16 | 1.1 h | 0.99 | 0.10 | 0.36 | 0.49 h | 11,947 | 6,918 |
| Shift | 16 | 0.8 h | 0.70 | 0.09 | 0.32 | 0.25 h | 11,500 | 6,894 |
| pLeft | 16 | 0.6 h | 0.49 | 0.08 | 0.29 | 0.09 h | 11,179 | 7,304 |
| pCenter | 16 | 0.4 h | 0.39 | 0.06 | 0.22 | 0.09 h | 11,179 | 7,304 |

What this says:

- **Warmup was 88-94% of every chain**, everywhere. At warmup 5,000 and 800
  samples that is arithmetic, not pathology, but it is the whole cost.
- **Reality and Valence are the only models that need `long`.** Projected at
  warmup 1,000 + 500 draws (`transient + 1500 × s/iter`) they still come to
  ~9.2 h and ~8.0 h, i.e. at or over `general`'s 8 h wall, where a killed task
  loses its whole chain. Everything else projects under 3.3 h, and the four
  gaze models under 0.7 h.
- **Half the cost of the two slow models is the fixed transient** (~5.2 h
  each), which warmup length cannot touch. `cogmod_inits()` attacks exactly
  that; §3.1a saw Meaning drop ~35% from it at smoke scale. Whether it does so
  at full data is the thing to watch on the first refit.
- **Five of the 13 combined fits are incomplete.** Artificiality,
  Authenticity and SelfRelevance have 14 chains (a whole shard missing);
  Meaning and Valence have 15 (one chain of one shard). Nothing in the
  pipeline flagged it -- `combine_models()` merges whatever shards it finds,
  and `combine_model.R` only errors on *zero* shards. Deliberately left
  unasserted (2026-09-21): check it by hand instead, from the `** found N
  shards` line the combine job prints and the count on the combined fit.

  ```r
  brms::nchains(readRDS("models/Valence.rds"))  # 15 -- expect shards x FA_CHAINS
  ```

  Note that a file count alone would not have caught Meaning and Valence:
  their shards are all present, but one shard contributed a single chain.

Caveats: old cogmod, hand priors and `init = 0`, so the transient is an upper
bound on what the new sampler will pay. Node load alone is a 2-3× factor on
wall time (IGC §4.4.1), so treat every row as indicative, not as a budget.

> **Correction (2026-09-21): `combine_models()` keeps only the first shard's
> timing.** `attr(m$fit, "metadata")$time$chains` on a *combined* fit has 2
> rows, not 8 -- brms keeps the first `mlist` element's metadata and drops the
> rest. So that expression reads shard 1, never the slowest shard, and the
> wall column it produced was understated by up to 6× (Authenticity: 0.33 h
> read back, 2.05 h actually). The Rhat / neff / leapfrog columns are fine --
> `nuts_params()` and `rhat()` operate on the merged draws.
>
> **Take wall time from the logs, not the fit**: the `REPORT ... wall` line
> each shard prints, or `sacct -j <jobid> --format=JobID,State,Elapsed`. Both
> tables below now do, and the gaze rows were recomputed on that basis.

**Measured (2026-09-21): the four gaze models under the 2026-09 scripts.**
4 shards × 2 chains, warmup 1,000 + 500 draws, thin 1, `loo` attached.
"wall/shard" is the slowest of the model's four shards, from its `REPORT`
line; the diagnostics are read back from the pulled `analysis/models/*.rds`.

| model | chains | draws | wall/shard | shard spread | n_leapfrog | treedepth | divergent | max Rhat | min neff ratio | n obs | n params |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Entropy | 8 | 4,000 | 0.69 h | 13.6-41.5 min | 127 | 7.00 | 0.000 | 1.021 | 0.089 | 12,220 | 7,062 |
| pLeft | 8 | 4,000 | 0.58 h | 24.6-34.5 min | 63 | 6.00 | 0.000 | 1.058 | 0.033 | 12,220 | 7,616 |
| pCenter | 8 | 4,000 | 0.47 h | 21.6-28.1 min | 63 | 6.00 | 0.000 | 1.037 | 0.057 | 12,220 | 7,616 |
| Shift | 8 | 4,000 | 0.40 h | 19.8-23.7 min | 103 | 6.62 | 0.000 | 1.018 | 0.100 | 11,772 | 7,038 |

Against the July rows: Entropy, pCenter and Shift came in under the July wall
(1.09, 0.43, 0.78 h) despite ~4% more data and warmup 1,000 instead of 5,000;
pLeft is the one that did not (0.58 h vs 0.55 h). No divergences anywhere, and
all 8 chains present in every combined fit (the July gaps in §3.2 did not
recur). Rhat is fine for Entropy and Shift; pLeft and pCenter sit at 1.04-1.06
with min neff ratio 0.03-0.06, which is what the July fits looked like too and
reflects the weakly identified `zoi`/`coi` participant terms rather than a
problem with the run.

Note the **3× spread across shards of the same model** (Entropy: 13.6 min on
`rtx-02`, 41.5 min on the `a40`s). That is node placement, IGC §4.4.1's 2-3×
factor, and it means a single shard's wall says little on its own.

**Measured (2026-09-21): five rating models under the 2026-09 scripts.**
Same settings, all on `--partition=general`. Meaning, Beauty2, Reality and
Valence are still fitting; their rows follow.

| model | chains | draws | wall/shard | shard spread | n_leapfrog | treedepth | divergent | max Rhat | min neff ratio | n obs | n params |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Beauty | 8 | 4,000 | 1.91 h | 86.8-114.7 min | 103 | 6.62 | 0.000 | 1.068 | 0.023 | 15,552 | 21,432 |
| Authenticity | 8 | 4,000 | 2.05 h | 21.8-123.2 min | 79 | 6.25 | 0.000 | 1.065 | 0.025 | 15,216 | 20,991 |
| Worth | 8 | 4,000 | 0.24 h | 11.4-14.2 min | 143 | 7.12 | 0.001 | 1.028 | 0.075 | 15,552 | 5,019 |
| Artificiality | 8 | 4,000 | 0.23 h | 12.9-13.6 min | 63 | 6.00 | 0.000 | 1.038 | 0.047 | 6,009 | 14,880 |
| SelfRelevance | 8 | 4,000 | 0.19 h | 5.9-11.5 min | 127 | 7.00 | 0.000 | 1.053 | 0.037 | 10,560 | 3,669 |

Every one beat its §3.2 projection: 0.37× (Artificiality) to 0.87×
(Authenticity) of the projected wall. The 5.25 h and 5.15 h "transients" that
§3.2 attributed to Reality and Valence are **not** irreducible -- see §3.2b.

Note that the **Worth and SelfRelevance rows above are the superseded
item-slopes fits** (§4.3a), not the files now in `analysis/models/`. Their
corrected refits are in the next table.

**Measured (2026-09-22): the rest of the registry.** Wall times are the
`REPORT ... wall` lines of the model's shards; "wall/shard" is the slowest,
which is what the array took. Combined diagnostics (Rhat, ESS, divergences) are
deliberately *not* duplicated here -- `3_models.qmd` recomputes them into its
per-model convergence table on every render, so this table would only go stale.
Max Rhat is given for the four models it was read back for by hand.

| model | family | chains | draws | wall/shard | shard spread | n obs | n params | combined max Rhat |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Meaning | Discrete Beta | 8 | 4,000 | 3.08 h | 113.6-185.0 min | 15,552 | 12,389 | 1.041 |
| Valence | Discrete Beta | 8 | 4,000 | 2.38 h | 107.5-142.9 min | 15,552 | 8,261 | 1.039 |
| Reality (refit) | CHOCO | 8 | 4,000 | 1.97 h | 43.2-117.9 min | 15,216 | 20,991 | 1.071 |
| Beauty2 | CHOCO | 8 | 4,000 | 1.16 h | 48.6-69.6 min | 10,560 | 14,880 | -- |
| MemoryBelief | categorical | 8 | 4,000 | 0.88 h | 39.0-52.6 min | 21,120 | 6,466 | -- |
| MemoryCondition | categorical | 8 | 4,000 | 0.43 h | 16.1-26.0 min | 21,120 | 3,869 | -- |
| Worth (corrected) | cumulative | 8 | 4,000 | 0.18 h | 6.5-10.7 min | 15,552 | 4,515 | -- |
| SelfRelevance (corrected) | cumulative | 8 | 4,000 | 0.15 h | 8.0-8.7 min | 10,560 | 3,165 | -- |

Everything fits inside `general`'s 8 h wall with room to spare; the slowest
shard in the whole project is now Meaning's at 3.08 h. **Meaning, not Reality,
is the expensive model under the current scripts** -- the Discrete-Beta
likelihood costs what §3.1a's smoke test predicted, while `cogmod_inits()`
took Reality's 20.3 h July wall down to 1.97 h even at warmup 3,000.

**Reality was refit at warmup 3,000** (job `11403711`, superseding
`11403496` at warmup 1,000) because §3.2b flagged its per-shard
`min neff_ratio` of 0.005-0.010 as the one result worth re-checking. It worked:
the combined fit's max Rhat is **1.071**, in line with Beauty (1.068),
Authenticity (1.065) and Artificiality (1.038), so no further refit is needed.
Per-shard Rhat still reads 1.10-1.22, which is the §3.2b point about judging a
run by the combined fit rather than its shards.

**Two shards died at init and were re-run under new ids.** `Valence`
`11403506_1` and `_3` failed after ~2 min with "No chains finished
successfully" -- the `FA_CHAINS=1` risk of §4.5, where a lone chain that dies
takes the whole task with it. They were resubmitted as shards 9 and 10, so
Valence's shard ids are 2 and 4-10. `Meaning` shard 3 was likewise replaced by
a shard 5. Shard ids **need not be contiguous**; what matters is that the
combine finds `shards x FA_CHAINS` chains (§4.4a).

### 3.2b Measured: what actually killed the wall time (2026-09-21)

Two changes, and the second is the big one.

**1. `FA_CHAINS=1` gives each chain all 16 threads.** Reality and Valence were
submitted as `FA_CHAINS=1 --array=1-8 --cpus-per-task=16 --mem=128G`: still 8
chains and 4,000 draws, but one chain per task with 16 threads instead of two
sharing 8 each. IGC §4.4.1 predicted this roughly halves per-chain wall, and
nothing here contradicts that. Cost is 128 CPUs per model instead of 64, and
the §4.5 caveat bites harder -- a lone chain that dies at init loses the whole
task rather than half of it.

**2. `cogmod_inits()` removes most of the cold-start transient.** This is what
made the difference. §3.2 modelled each July chain as
`transient + iterations × s/iter` and put Reality's transient at 5.25 h, on
fits that started from `init = 0`. With cogmod's data-informed starts,
Reality's eight shards ran **33.9-82.2 min** (slowest 1.37 h) against a 9.2 h
projection -- 6.7×, where the threading alone predicts ~2×. Beauty2 (2 chains
× 8 threads, so *no* threading change) came in at 48.6-69.6 min against
3.25 h, which isolates the inits as the cause rather than the threading.

So §3.2's transient column is an artefact of `init = 0` and should not be used
to budget a run under the current scripts. The practical consequence: **every
model fits inside `general`'s 8 h wall**, and `long` is not needed for this
project at all -- which mattered on the day, because IGC held 80 of `long`'s
140 CPUs with ~6.8 days left, so anything sent there would have queued for a
week. That contention is structural (one account, two projects) and since
2026-09-22 it also has a direct answer: §3.6.

**Rhat needs reading at the right level.** Per-shard `REPORT` lines showed
Reality up to 1.398 and Beauty2 up to 1.266, which looks alarming; the
combined 8-chain fits of the models finished so far are 1.018-1.068. A
2-chain shard (or, with `FA_CHAINS=1`, a split-Rhat on a single chain) is too
few draws for a stable Rhat over ~21,000 parameters, and the max is taken over
all of them, so it lands on the worst participant effect. Judge a run by the
combined fit, not by its shards.

Reality is nonetheless the one to check: all eight of its shards report
`min neff_ratio` 0.005-0.010, i.e. ~20-40 effective draws out of 4,000 for the
worst-mixing parameter, against 0.023-0.075 for the five rating models already
combined. If its combined Rhat does not settle near the others', a refit at
warmup 2,000-3,000 is the obvious next step and now costs ~1.5-3 h per shard
instead of July's 20 h.

**Fit memory is not close to the limit.** `sacct MaxRSS` on the largest CHOCO
models (2 chains × 8 threads, 32 GB requested): Beauty 2.7 GB, Authenticity
2.8 GB, Artificiality 2.5 GB. Peak was ~11× below the request, so the 32 GB
default has a lot of slack. 128 GB was requested for the `FA_CHAINS=1` runs
only because 16 threads in one process doubles the per-thread AD stacks and
headroom is free on nodes with 489-733 GB.

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

### 3.3 The toolchain and the cluster traps → hub

Module `CmdStanR/0.7.1-foss-2023a-R-4.3.2` + the account's shared project
library, and every cluster trap the scripts handle, are in
[hub `toolchain.md`](https://github.com/RealityBending/Lab/blob/main/hpc/toolchain.md) and
[hub `troubleshooting.md`](https://github.com/RealityBending/Lab/blob/main/hpc/troubleshooting.md).

One consequence specific to sharing the library: `FA_COGMOD_REF` defaults to
`dev`, because IGC's fits need cogmod ≥ 0.3.3 (dev until merged) and
`./hpc install cogmod` from either project refreshes the same library.

### 3.4 Measured: `combine` memory (2026-09-22)

`combine.slurm` asks for 64 GB / 4 CPUs on `general`. That was a guess with
margin; `sacct MaxRSS` now says it is the right order and can stay.

| combine | family | shards | MaxRSS | of the 64 GB request |
| --- | --- | --- | --- | --- |
| Reality | CHOCO | 8 | 27.9 GB | 44% |
| Beauty2 | CHOCO | 4 | 26.9 GB | 42% |
| MemoryBelief | categorical | 4 | 9.3 GB | 15% |
| MemoryCondition | categorical | 4 | 8.2 GB | 13% |
| Meaning | Discrete Beta | 4 | 6.1 GB | 10% |
| Valence | Discrete Beta | 8 | 4.3 GB | 7% |
| Worth | cumulative | 4 | 3.4 GB | 5% |
| SelfRelevance | cumulative | 4 | 3.2 GB | 5% |

Peak is **~28 GB on the CHOCO models**, i.e. 2.3× headroom, and it tracks the
family rather than the shard count (Reality merges 8 shards, Beauty2 only 4,
and they cost the same). Nothing came close to being killed. If a future model
does, raise `--mem` on the command line (`./hpc combine Beauty --mem=128G`) and
add the row here.

### 3.5 Measured: `artemis-rtx-00` throws transient lustre I/O errors

The general symptom and fix (resubmit with `--exclude=artemis-rtx-00`,
stagger bursts with `--dependency=afterany:<jobid>`, clear 0-byte stubs) are
in [hub `troubleshooting.md#inputoutput-error`](https://github.com/RealityBending/Lab/blob/main/hpc/troubleshooting.md#inputoutput-error).
This project is where it was found: on 2026-09-22 **4 of 9 combine jobs
failed on `artemis-rtx-00`** — Meaning twice (`saveRDS` → `Input/output
error`), Worth and SelfRelevance leaving **0-byte** `combined/<Model>.rds`
stubs, and one `seek failed on .../cogmod/R/cogmod.rdb` inside
`add_criterion()`. Four jobs had started within three minutes, so contention
on the lustre-backed R library is the likely trigger.

Stub sweep for this project:

```
./hpc sh "find /mnt/lustre/users/psych/dmm56/FakeArt/models -size 0 -name '*.rds' -print -delete"
```

A failed `saveRDS` can bump the target's mtime while leaving the previous
bytes in place: Meaning's stale 334,900,188-byte combine carried a 09:06 mtime
from a write that never happened; the real one is 382,523,074 bytes. Only the
`** wrote ... with N draws` line is evidence (§4.4a).

### 3.6 Gained: `sussexneuro`, a second quota for this account (2026-09-22)

`dmm56` joined `artemis_sussexneuro` on or before 2026-09-22, so
`--partition=sussexneuro` works from here. How the partition works — separate
quota, higher priority, a 256-CPU **group** pool with `DenyOnLimit`, and why a
partition list is not an access check — is in
[hub `artemis.md#sussexneuro`](https://github.com/RealityBending/Lab/blob/main/hpc/artemis.md#sussexneuro). Its 60-day wall is
of no interest to a project whose slowest shard is Meaning at 3.08 h (§3.2);
**what it is good for here is the quota.**

That matters more to FakeArt than the table suggests, because **IGC and
FakeArt are the same cluster user**. The per-partition caps are per *user*,
not per project, so §3.2b's observation -- IGC sitting on `long` with 6.8 days
left -- is a standing condition rather than a bad day, and `sussexneuro` is an
allowance neither project's arrays can spend on the other's behalf:

```
./hpc fit Entropy --partition=sussexneuro
```

It does not bypass the account-wide 550-CPU ceiling (§3.6a). Note also that
the pool is shared with our own IGC `gam_ddm5` array, which has held 64 of its
256 CPUs since 2026-09-22.

**Where this leaves the default.** `general` stays the first choice for
FakeArt: 400 CPUs against a 256-CPU *shared* pool, no colleague's allowance
spent, and 8 h covers every model in the registry. Reach for
`sussexneuro` when `general` is congested or when a FakeArt run has to overlap
an IGC production set -- not routinely. A FakeArt array is 4 x 16 = 64 CPUs for
at most a few hours, which is modest against the group ceiling but is still
borrowed.

---

### 3.7 Measured: convergence got worse at warmup 1,000 (2026-09-22)

Every model's `Max_Rhat` rose and every model's `Min_ESS_ratio` fell between
the July production run and the September refit. July numbers recovered from
`git show 060910f:analysis/3_models.html.md`, September from the 2026-09-22
render:

| model | family | Rhat Jul → Sep | ESS ratio Jul → Sep | draws Jul → Sep |
| --- | --- | --- | --- | --- |
| Beauty | CHOCO | 1.064 → **1.068** | .031 → .023 | 6400 → 4000 |
| Beauty2 | CHOCO | 1.025 → **1.088** | .072 → .023 | 8000 → 4000 |
| Reality | CHOCO | 1.051 → **1.071** | .047 → .020 | 6400 → 4000 |
| Authenticity | CHOCO | 1.043 → **1.065** | .057 → .025 | 5600 → 4000 |
| Artificiality | CHOCO | 1.027 → 1.038 | .121 → .047 | 5600 → 4000 |
| Valence | DiscBeta | 1.036 → 1.039 | .102 → .035 | 6000 → 4000 |
| Meaning | DiscBeta | 1.038 → 1.041 | .063 → .050 | 6000 → 4000 |
| Worth | cumulative | 1.011 → 1.037 | .187 → .078 | 6400 → 4000 |
| SelfRelevance | cumulative | 1.030 → **1.085** | .062 → .021 | 5600 → 4000 |
| Entropy | Beta | 1.011 → 1.021 | .204 → .089 | 8000 → 4000 |
| pLeft | ZOIB | 1.023 → 1.058 | .075 → .033 | 8000 → 4000 |
| pCenter | ZOIB | 1.013 → 1.037 | .146 → .057 | 8000 → 4000 |
| Shift | LogNormal | 1.005 → 1.018 | .276 → .100 | 8000 → 4000 |

**This is not cogmod.** The obvious suspect was the new
`cogmod_priors()` / `cogmod_inits()` defaults (§4.3, adopted 2026-09-20), but
five of these models are native brms families for which `fa_is_cogmod()` is
FALSE: they still get `brms::get_prior()` and `init = 0`, exactly as in July.
Entropy, pLeft, pCenter and Shift changed in no way except the sampler
settings, and all four degraded — pLeft 1.023 → 1.058. Whatever moved, moved
for every family at once.

What did change for all 13 is §"The production runs": warmup 5,000 → 1,000,
samples 800 → 500, thin 2 → 1, 14-16 chains → 8. Fewer chains should make Rhat
*less* likely to flag, not more, so the July advantage is if anything
understated. The ESS ratio falling alongside Rhat points at adaptation: a
shorter warmup leaves a worse step size, which shows up as autocorrelation
rather than as divergences (still 0.0% everywhere).

Note also that Beauty was **already 1.064 in July**, at warmup 5,000 with the
old API, `init = 0` and `normal(0, 2)` priors. The CHOCO Rhat problem predates
every recent change; what September did was generalise it.

`cogmod_priors()` / `cogmod_inits()` themselves check out (inspected
2026-09-22, cogmod 0.3.3, brms 2.23.1): `normal(0, 0.5)` on auxiliary dpar
slopes, informed intercepts (`pex` `normal(-2, 1)`, `pmid` `normal(-2.5, 1)`,
`prec*` `normal(2, 1.5)`, `phi` `normal(0.7, 0.8)`), `exponential(1)` on
auxiliary group SDs, and inits that start each chain jittered around those
(`sd ≈ 0.25`, `z ≈ 0`, `Intercept_precright ≈ 1.7-2.1`). Nothing there is
mis-scaled, and nothing is left flat once brms's class-level inheritance is
accounted for.

**Where the bad Rhat lives: the random-effects covariance, not the estimates.**
`get_estimates()` stores `$convergence` — Rhat, ESS bulk/tail and the posterior
summary for every non-`r_` parameter — so the headline number can be split by
parameter class. Measured 2026-09-22 on three extracted models:

| model | headline | `cor_` max | `sd_` max | `b_`/Intercept max (min ESS) |
| --- | --- | --- | --- | --- |
| Beauty | 1.068 | **1.068** (n=339) | 1.025 (n=74) | **1.012** (n=77, ESS 573) |
| Valence | 1.039 | 1.031 (n=138) | **1.039** (n=30) | 1.025 (n=26, ESS 439) |
| Entropy | 1.021 | 1.009 (n=138) | **1.021** (n=30) | 1.007 (n=28, ESS 1111) |

Two things follow. First, the headline is *not* an artefact of maximising over
tens of thousands of `r_` terms — it is reproduced exactly within the few
hundred non-`r_` parameters. Second, it is not in the population-level
coefficients either: those top out at 1.007-1.025 with ESS in the hundreds,
and they are what the marginal means and contrasts are built from. The report's
numbers are fine in both runs.

**The correlation blocks are unidentified, and warmup will not fix that.**
Under LKJ(1) on a K x K matrix each correlation is marginally Beta(K/2, K/2) on
(-1, 1), with sd `1/sqrt(K+1)` = **0.277** for the K = 12 of
`Condition * Emotion`. The measured posteriors:

| model | median posterior sd of `cor_` | share with \|mean\| < 0.1 |
| --- | --- | --- |
| Beauty | 0.273 | 82% |
| Valence | 0.269 | 77% |
| Entropy | 0.275 | 92% |

The posterior *is* the prior. 339 correlations in Beauty that the data does not
inform are being sampled from a flat 12-dimensional simplex, and the chains
wander there — Beauty's worst, `cor_Participant__confleft_ConditionHumanForgery__confleft_EmotionNegativeMHighintensity`,
has mean 0.13, sd 0.28, ESS 91. No amount of warmup identifies a parameter the
data says nothing about.

So the two findings answer different questions. The Jul → Sep *degradation* is
the sampler settings (the native-family control group proves it). The *absolute
level* of Rhat, in both runs, is the unidentified `(Condition * Emotion | ...)`
covariance in the auxiliary dpars, which is why Beauty was already 1.064 in
July. If that level is what needs fixing, the lever is the model — `||` or a
tighter `lkj(2)` on the auxiliary dpars' participant blocks — not the warmup.
If the goal is only to undo the September regression, the warmup sweep is the
cheap test: the settings are per-run environment variables, so

```bash
FA_WARMUP=3000 FA_MODELS_DIR=.../models_w3000 ./hpc fit Beauty2 --partition=general
```

against the current 1,000 answers it directly. Reality was already run a second
time at warmup 3,000 (§3.2), so there is a precedent and a wall-time figure.
Run `./hpc extract` on Beauty2 and SelfRelevance (the two worst) first — the
class split above may well show the same pattern, in which case a blanket
refit buys a better-looking headline and nothing else.

---

### 3.6a Measured: `normal` caps the whole account at 550 CPUs (2026-09-22)

Found here, now a hub fact: [hub `artemis.md#quotas`](https://github.com/RealityBending/Lab/blob/main/hpc/artemis.md#quotas).
The incident: when `./hpc extract all` was first run, the account already held
`general 400 + long 128 (IGC gam) + sussexneuro 64 (IGC gam_ddm5) = 592` CPUs,
so 15 four-CPU extract jobs sat `PENDING (QOSMaxCpuPerUserLimit)` on
`sussexneuro` exactly as they had on `general`. Cancelling and resubmitting on
another partition was wasted effort. What the partition still bought was
priority once there *was* headroom: the extract jobs were first in line
(priority 23636) when the running array released capacity.

### 3.6b Fixed: `./hpc fit|combine|extract all` opened one SSH per model

`./hpc extract all` (15 models in a few seconds) lost several submissions to
the sshd rate limit, each surfacing only as `error: cannot reach artemis`.
Fixed 2026-09-22: `submit_per_model()` sends one script through a single
`remote` call (2 connections for any number of models), each `sbatch`
labelled with its model and suffixed `|| echo 'SUBMIT FAILED'`. This is now
part of the hub's driver contract
([`project-template.md`](https://github.com/RealityBending/Lab/blob/main/hpc/project-template.md#the-driver-contract)).

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

### 4.3a Worth and SelfRelevance: item term corrected (2026-09-21)

Both cumulative models had `(Condition * Emotion | Item)` from July. `Emotion`
is a property of the item (each item sits in exactly one quadrant), so the
item-level Emotion slopes had no within-item variation to be estimated from
and were only a re-parametrisation of the item intercept, paid for in
parameters and sampling time. Changed to `fa_rhs_full`, i.e.
`(Condition | Item)`, like every other model. Both had already been refit
under the 2026-09 scripts that afternoon with the old term (shards 14:26 to
14:37, combined 17:55 / 17:58); those files were moved, not deleted, to
`models/superseded_itemslopes/` (+ `combined/`) on the cluster so that
`file_refit = "never"` could not adopt them, and fresh arrays were submitted
on `general` at 19:40: Worth `11403591`, SelfRelevance `11403592`.

> **Correction (2026-09-22): both superseded combined files _had_ been pulled.**
> This section originally said neither had reached `analysis/models/` and that
> the local copies were still the July fits. They were not: `Worth.rds`
> (155,633,649 bytes, 18:58) and `SelfRelevance.rds` (113,752,065 bytes, 20:16)
> sat locally, byte-identical to `superseded_itemslopes/combined/`, until the
> corrected combines were pulled on 2026-09-22. Moving a file on the cluster
> does not un-pull its local copy -- check `analysis/models/` by size against
> the cluster, not by assumption.

The corrected fits bear out the reasoning: dropping the redundant item-level
Emotion slopes took Worth from 5,019 to **4,515** parameters and SelfRelevance
from 3,669 to **3,165**, with no cost in convergence (max Rhat per shard
1.039-1.057 and 1.038-1.258, no divergences).

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

**Measured (2026-09-21): `loo` cost scales hard with the likelihood, not with
the dataset.** Combine jobs, 4 shards → 4,000 draws, `FA_CRITERION=loo`:

| model | combine wall | n obs | n params | family |
| --- | --- | --- | --- | --- |
| Entropy, pLeft, pCenter, Shift | 1.0-3.1 min | 11.8-12.2k | ~7k | native brms |
| SelfRelevance | 0.7 min | 10,560 | 3,669 | cumulative |
| Worth | 1.3 min | 15,552 | 5,019 | cumulative |
| Beauty | 45.1 min | 15,552 | 21,432 | CHOCO |
| Artificiality | 60.6 min | 6,009 | 14,880 | CHOCO |
| Authenticity | 69.5 min | 15,216 | 20,991 | CHOCO |

A CHOCO combine is **~40× a gaze combine** on comparable data, and
Artificiality takes an hour on 6k rows, so it is the custom-family `log_lik`
being evaluated in R per draw per observation that costs, not the data size.
Still far inside `combine.slurm`'s 8 h on `general`, but budget ~1 h per CHOCO
model. `FA_CRITERION` / `FA_CRITERION_NDRAWS` are the levers if that ever
stops fitting.

**Measured (2026-09-22), the remaining models.** Reality came in *under* the
~1 h budget the row above predicted for it:

| model | combine wall | n obs | n params | family |
| --- | --- | --- | --- | --- |
| Reality | 32.9 min | 15,216 | 20,991 | CHOCO |
| Beauty2 | 33.3 min | 10,560 | 14,880 | CHOCO |
| MemoryBelief | 10.5 min | 21,120 | 6,466 | categorical |
| Valence | 8.6 min | 15,552 | 8,261 | Discrete Beta |
| SelfRelevance | 6.0 min | 10,560 | 3,165 | cumulative |
| Meaning | 4.5 min | 15,552 | 12,389 | Discrete Beta |
| Worth | 4.0 min | 15,552 | 4,515 | cumulative |
| MemoryCondition | 1.2 min | 21,120 | 3,869 | categorical |

Two things worth keeping: **Discrete Beta is cheap to `loo`** (Meaning, 12,389
parameters over 15,552 rows, in 4.5 min) even though it is the *dearest* family
to sample (§3.2's table) -- the cost profiles of fitting and of `loo` do not
track each other. And **node placement moves these numbers by 3-5×**: the
corrected Worth and SelfRelevance combines took 4.0 and 6.0 min against 1.3 and
0.7 min for the superseded versions, on *fewer* parameters, purely because they
landed on a busy node.

### 4.4a Check the draw count, not the exit status

`combine_models()` merges whatever shards it finds and `combine_model.R` only
errors on *zero* shards, so neither a clean exit nor a full shard listing
proves the chains are all there (§3.2 found five July fits silently short).
The check is the line the combine prints:

```
** wrote .../combined/Meaning.rds with 4000 draws
```

`shards x FA_CHAINS x FA_SAMPLES` = 4 x 2 x 500 = 4,000 at the current
settings. On 2026-09-21 `combine_Meaning_11403686` reported `found 4 shards`,
exited 0, and wrote **3,500** -- shard 3 had contributed one chain of its two.
That shard was dropped and re-run as shard 5. Sweep them all with:

```
./hpc sh "grep -h 'wrote' /mnt/lustre/scratch/psych/dmm56/FakeArt/combine_*.out"
```

All 15 models read 4,000 as of 2026-09-22.

### 4.5 Everything is parameterised by environment variable

So the `.slurm` files contain nothing account-specific and a second account
needs only `hpc.local`. The `FA_` prefix keeps them apart from IGC's `IGC_`
variables when both projects are driven from the same shell.

### 4.6 Downstream: why `3_models.qmd`'s cache was 74 GB

Not a cluster matter, but it is the first thing you meet after a `./hpc pull`,
and it cost a day to diagnose.

**easystats attaches the entire fitted model to every `estimate_*()` result**,
as `attr(x, "model")`. A three-row table of marginal means therefore serialises
to the size of the fit:

```r
em <- estimate_means(m, by = "Condition", predict = "mu", backend = "emmeans")
nrow(em)                                 # 3
length(serialize(em, NULL)) / 1024^2     # 475 MB  (Artificiality)
attr(em, "model") <- NULL
length(serialize(em, NULL)) / 1024^2     # 0.00 MB
```

`get_marginal_parameters()` makes nine such calls and `full_join()`s them, and
dplyr keeps the left-hand side's attributes, so every cached `fig-*` chunk
stored copies of its model: 7.0 GB for `fig-beauty`, 8.0 GB for
`fig-beauty-emotion`, **73 GB** over the notebook. The numbers in those objects
are kilobytes; none of it was compute.

Fixed 2026-09-22 by a one-line `fa_light()` in the `helpers` chunk that drops
that one attribute, applied at each `estimate_means()` / `estimate_contrasts()`
/ `estimate_prediction()` call site in `3_models.qmd` and `4_memory.qmd`. The
small formatting attributes easystats prints from (`ci`, `at`, `by`,
`focal_terms`) are kept. Verified identical numbers, same runtime.

**Superseded on 2026-09-22 by `extract`** (§4.7). `3_models.qmd` no longer
calls `estimate_*()` at all, so there is nothing left to attach a model to and
nothing left to cache. `strip_model()` (the former `fa_light()`) survives in
`estimates.R`, where it now keeps the *cluster's* results small enough to pull.

The interim fix between the two was a `cache.extra` keyed on
`file.info(models/*.rds)`, because knitr keys its cache on chunk code alone and
re-rendering after a refit silently reused results computed from the previous
models. That hazard is gone with the cache: each estimates file records the
`fit_file` and `created` time it came from, and the notebook prints them.

### 4.7 Downstream: the notebook does not open a fit any more (2026-09-22)

The 2026-09-22 render of `3_models.qmd` took **2 h 50 min** and held all 13
fits in one R session. Per model, from the knitr cache timestamps:

| | | | |
| --- | --- | --- | --- |
| SelfRelevance 43 min | Worth 31 | Authenticity 25 | Reality 23 |
| Beauty 12 | Beauty2 9 | Artificiality 8 | Shift 6 |
| Valence / Meaning / pLeft / pCenter 3 | Entropy 2 | | **171 total** |

It also never produced an HTML: the knit finished at 14:54:14 and the process
died before pandoc, losing all of it (pandoc on the finished `.knit.md` takes
18 s, so it was not the document).

`estimates.R` + `extract_model.R` + `extract.slurm` move that to the cluster,
one job per model, all in parallel. What comes back per model is 0.4-2 MB and
the notebook renders from it in about a minute. Measured on Entropy locally
(2026-09-22): 2.4 min, **0.44 MB**, against a 218 MB fit, and every contrast
identical to the published CSV to 4e-16.

Two reductions had to move cluster-side or the payload would not have been
worth the trip: `estimate_prediction(keep_iterations = TRUE)` is 146 MB for
Shift at 500 draws, but the figures only plot a summary over response
categories (`get_discrete_summary()`) or one kernel density per draw
(`get_density_curves()`, matching what `geom_line(stat = "density")` drew).

What stays local is anything cheap and presentational: `prep_contrasts()` is
re-run on the stored contrasts, and `get_marginal_densities()` evaluates the
CHOCO density on the marginal parameters, so a rescaled unit or a retuned
`adjust` costs a render and not a job.

**`4_memory.qmd` goes the same way, through a second registry.** Its two
categorical models are not `3_models.qmd` outcomes and forcing them into
`outcome_info` would mean carrying fields none of them use (`range`,
`marginal`, `discrete`, `density`, an Emotion stratification they do not
have). They get `memory_info` and `get_memory_estimates()` instead, which does
only what that notebook needs:

```r
estimate_means(m, by = info$by)                               # Condition / Belief
estimate_contrasts(m, contrast = info$by, test = "pd")
```

`get_estimates()` dispatches on which registry a name is in, so
`extract_model.R`, `extract.slurm` and `./hpc extract` are unchanged and
`./hpc extract all` now covers all 15 registry models instead of failing on
two. A model in neither registry still fails fast, with a message naming both.

The calls are copied from the notebook verbatim, backend and all — modelbased's
default rather than an explicit one — so moving the computation does not move
the numbers.

Measured locally, 2026-09-22 (8 chains × 4,000 draws, 21,120 rows each):

| model | `estimate_means()` | `estimate_contrasts(test="pd")` | total |
| --- | --- | --- | --- |
| MemoryCondition | 19.6 min | 24 min | **44.6 min** |
| MemoryBelief | 40.2 min | 51 min | **92.3 min** |

So `4_memory.qmd` was ~2 h 17 min, on top of `3_models.qmd`'s 2 h 50 min. Note
that the means are as expensive as the contrasts on this backend — offloading
only the `estimate_contrasts()` line would have left half the cost behind.

### 4.7a `strip_model()` has to do more than drop `attr(x, "model")`

The marginaleffects backend — which the two memory models and the two ordinal
models (`Worth`, `SelfRelevance`) use — attaches two further things that each
hold the fit indirectly. Measured on `MemoryCondition`, whose tables are 16 and
120 rows:

| attribute | size | what it is |
| --- | --- | --- |
| `attr(<contrasts>, "comparison")` | 380.5 MB | a `difference ~ pairwise` **formula**. A formula carries its defining environment, and that environment is modelbased's own frame: `model_data`, the result, and the formula itself. `environment(f) <- baseenv()` takes it to 0.0002 MB. |
| `attr(<means>, "datagrid")` | 128.8 MB | an 84,480 × 3 grid whose columns are 1.4 MB and whose *own* `model` attribute is the 125.7 MB brmsfit. Nothing downstream reads it. |

Left unhandled, the two memory estimates files came out at **430 MB and
700 MB** — larger than the fits they were extracted from, and the opposite of
the point. `strip_model()` now drops `model` and `datagrid`, rebases any
formula-valued attribute onto `baseenv()`, and finally drops any remaining
attribute over 256 KB, so a backend that starts attaching something new cannot
quietly put a model back inside a three-row table. Same files afterwards:
**0.010 MB and 0.019 MB**, with every small formatting attribute (`ci`, `at`,
`by`, `focal_terms`, `table_title`, …) intact, and `make_contrasts()` and the
figures unchanged.

The emmeans backend does not do this, which is why the first three models
extracted (Beauty, Valence, Entropy) came in at 0.02-0.44 MB and the problem
went unseen until a marginaleffects model was run.

---

## 5. Open questions

**Closed on 2026-09-22.** All 15 registry models are fitted, combined at 4,000
draws, and pulled; `analysis/models/` holds no July fit and no superseded fit.
The four questions this section used to carry are answered in place:

1. ~~Wall time per shard~~ → §3.2's two tables. Every model fits inside
   `general`'s 8 h; the slowest shard in the project is Meaning at 3.08 h.
2. ~~Combine memory~~ → §3.4. Peak 27.9 GB against a 64 GB request.
3. ~~Whether to refit the rating models~~ → all refitted, plus Reality a second
   time at warmup 3,000 (§3.2), and Worth / SelfRelevance a second time with
   the corrected item term (§4.3a).
4. ~~Memory models~~ → `MemoryCondition` (`11403593`) and `MemoryBelief`
   (`11403721`) both fitted, combined and read by `4_memory.qmd`, which loads
   them from `models/` instead of fitting pathfinder stand-ins. The
   `participants: 220  items: 96  rows: 21120` line confirmed the
   `data = "memory"` path on the cluster for both.

Still open:

1. **cogmod ≥ 0.3.3 and CHOCO.** The floor here is 0.3.1 (API). If a later
   cogmod changes the CHOCO/Discrete-Beta numerics, the fits should be
   re-run together so the notebooks compare like with like. This now means all
   15 at once, which §3.2's tables price at roughly a day of `general`.
2. **Further memory models.** The registry comment anticipates recognition as a
   function of the Phase-1 ratings; it is not written yet. Same pattern:
   `data = "memory"` and a `fa_prepare_memory()` factor.
3. ~~Whether `analysis/models/` should hold the fits at all~~ → built on
   2026-09-22 as `./hpc extract` (§4.7). The last sentence this entry used to
   carry was wrong: the local extraction is **not** seconds per model, it is
   2 h 50 min over the 13, which is the whole reason the step exists.
   `analysis/models/` still holds the 5 GB of fits — nothing deletes them —
   but no notebook reads them any longer, so they can now go to a
   Dropbox-excluded path or be dropped entirely, since the cluster keeps both
   the shards and the combined fits.

4. **Whether the September settings need revisiting.** Every model's Rhat rose
   and ESS ratio fell against the July run (§3.7), across families that share
   nothing but the sampler settings. A warmup sweep on Beauty2 or
   SelfRelevance is the cheap test; a blanket refit at warmup 3,000 is roughly
   a day of `general` (§3.2).

---

## 6. File map

| file | role |
| --- | --- |
| `hpc` | driver (see `README.md`) |
| `models.R` | registry + `fa_prepare_data()`, `fa_priors()`, `fa_stanvars()`, `fa_inits()` |
| `fit_model.R` / `fit.slurm` | one shard of one model |
| `combine_model.R` / `combine.slurm` | merge one model's shards |
| `estimates.R` | post-processing, shared with `3_models.qmd` (§4.7) |
| `extract_model.R` / `extract.slurm` | one model's means/contrasts/figure data |
| `install_pkgs.R`, `precompile.R` | environment (SSH setup: lab hub `hpc/scripts/setup-ssh.sh`) |
| `README.md` | command reference |
| `server.md`, `hpc.local` | gitignored: local notes on this project's cluster dirs / per-machine account |
