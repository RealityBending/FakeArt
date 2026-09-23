# Running the models on Artemis (Sussex HPC)

> **Cluster-level instructions live in the lab HPC hub**:
> <https://github.com/RealityBending/Lab/tree/main/hpc> (start at `hpc/README.md`;
> on Dom's machines: `~/Dropbox/RealityBendingLab/Lab/hpc/`).
> Prefer a local clone of `RealityBending/Lab` if there is one — it also holds
> your gitignored `hpc/private/` notes. The hub covers access, storage,
> partitions and quotas, the R/Stan toolchain, job conventions, troubleshooting
> and housekeeping, and **wins over anything here that contradicts it**; this
> file should only hold what is specific to this project.

The Bayesian models in `3_models.qmd` are too heavy for a laptop, so they run
as SLURM array jobs on **Artemis**. The `./hpc` script in this folder wraps the
whole loop (push code, submit, watch, pull results) over SSH, so an agent or a
collaborator can drive the cluster without the web UI.

**One job fits one model.** `models.R` is the registry of what a model *is*;
`./hpc fit <model>` submits an array for it, each array task writing one shard;
`./hpc combine <model>` merges that model's shards into a single fit with `loo`
attached; `./hpc pull` drops the combined fits into `analysis/models/`, where
the notebooks read them.

This layout is shared with the lab's IllusionGameComputational project (same
`./hpc` design, same cluster toolchain, same project R library on the same
account). Cluster-level instructions are in the lab hub linked above; this
folder's `AGENT.md` holds what is specific to FakeArt.

## The cluster, and one-time setup

Access (VPN, Open OnDemand, SSH), storage, partitions and quotas:
[hub `artemis.md`](https://github.com/RealityBending/Lab/blob/main/hpc/artemis.md). Setting up a machine (SSH key,
`artemis` alias) or a new account (R library, CmdStan, precompiled header):
[hub `setup.md`](https://github.com/RealityBending/Lab/blob/main/hpc/setup.md). A machine already set up for any lab
project needs nothing more.

This project's directories on the cluster:

| path | use |
| --- | --- |
| `/mnt/lustre/users/<group>/<user>/FakeArt/` | code, `models/` (shards), `models/combined/`, `models/estimates/` |
| `/mnt/lustre/scratch/<group>/<user>/FakeArt/` | job logs (`fit_<model>_<job>_<task>.out`) |

Once per account, for this project:

```bash
cd analysis/server
./hpc check            # VPN + SSH
./hpc setup            # create /mnt/lustre/{users,scratch}/psych/<user>/FakeArt
./hpc install          # project R library (shared with IGComputational; usually a no-op)
./hpc precompile       # CmdStan precompiled header (per account; a no-op if IGC built it)
```

## Every session

The **GlobalProtect VPN must be connected** before anything below works.

```bash
cd analysis/server
./hpc check                # confirms VPN + SSH are good
./hpc push                 # copy *.R and *.slurm to the cluster (CRLF -> LF)
./hpc models               # what can be fitted
./hpc fit Beauty           # submit one array job (8 shards) for one model
./hpc queue                # what's running
./hpc progress Beauty      # iteration counts per chain + REPORT lines
./hpc log Beauty           # full tail of that model's newest .out/.err
./hpc ls                   # fitted .rds on the cluster
./hpc combine Beauty       # merge its shards and add loo (shards are kept)
./hpc pull                 # combined/*.rds -> analysis/models/
```

`push` **mirrors** rather than merges: a top-level `*.R` / `*.slurm` on the
cluster that no longer exists locally is deleted, so a renamed script can never
be submitted by accident (the pre-2026-09 `make_models.R` / `make.slurm` /
`combine_models.R` are removed on the first push). `models/` and the logs are
untouched.

**The cluster fits the data on GitHub `main`, not your working copy.**
`fit_model.R` reads `data/data_task.csv` and `data/data_eyetracking.csv` (or
`data/data_memory_task.csv` for a model with `data = "memory"`) from the raw
GitHub URL. Commit and push the data before `./hpc fit`, or the job silently
fits the previous dataset.

### How to check job status, cheaply

Report status the hub's way ([`jobs.md#status-reports`](https://github.com/RealityBending/Lab/blob/main/hpc/jobs.md#status-reports)):
running since when, a per-shard table of each chain's iterations, an ETA
against warmup + samples (1,500 by default), and a warning if a shard risks
the wall (`general`: 8 h).

```bash
./hpc queue                # one line per array task: STATE, TIME, TIME_LEFT, reason if PENDING
./hpc progress Beauty      # per log: latest 'Chain N Iteration:' line per chain, REPORT, SUCCESSFUL, errors
```

`REPORT ...` is printed once at the end of a shard (wall time, `n_leapfrog`,
treedepth, step size, divergences, max Rhat, min ESS ratio).

### Smoke tests

Extra arguments to `fit` and `combine` are passed to `sbatch`, so a smoke test
on the cluster is:

```bash
FA_MODELS_DIR=/mnt/lustre/users/psych/dmm56/FakeArt/smoke \
FA_NPARTICIPANTS=20 FA_WARMUP=300 FA_SAMPLES=100 FA_THIN=1 \
  ./hpc fit Beauty --array=1-2 --partition=short --cpus-per-task=8 --mem=16G
```

`--partition=short` is the only wall-clock setting needed: with no `--time`
the task gets that partition's maximum (2 h).

Always give a test run its **own `FA_MODELS_DIR`**. Shards are named
`<model>_<shard>.rds` and `file_refit = "never"` means a shard that already
exists is silently kept, so a 20-participant test shard left in the
production directory would be adopted by the production run.

The same scripts run on a laptop against the local data, which is how the
2026-09-20 rewrite was checked before anything was pushed:

```bash
cd analysis/server
FA_DATA=../../data FA_NPARTICIPANTS=6 FA_WARMUP=40 FA_SAMPLES=20 FA_THIN=1 FA_CHAINS=1 \
SLURM_CPUS_PER_TASK=2 FA_MODELS_DIR=/tmp/fa_smoke FA_MODEL=Meaning SLURM_ARRAY_TASK_ID=1 \
  Rscript fit_model.R
FA_MODELS_DIR=/tmp/fa_smoke FA_MODEL=Meaning FA_CRITERION=waic Rscript combine_model.R
```

## The production runs

Full data, `long` partition, one job per model:

```bash
./hpc push
./hpc fit Beauty
./hpc fit Reality
./hpc fit all              # or everything in models.R, queued behind each other
```

The defaults in `fit.slurm` match IllusionGameComputational: `--array=1-4`,
`--cpus-per-task=16`, `--mem=32G`, `--partition=long`, no `--time` (each task
gets `long`'s 8-day maximum), with `FA_WARMUP=1000`, `FA_SAMPLES=500`,
`FA_THIN=1`, `FA_CHAINS=2`. That is 4 shards × 2 chains × 500 draws =
**4,000 draws per model**, from 8 chains.

They replaced the July 2026 settings (warmup 5,000, 800 samples, thin 2, 8
shards → 6,400 draws) on 2026-09-21. Warmup was 88-94% of every chain's wall
time there and IGC §4.4.1 measured ESS per draw to be flat from warmup 200 to
1,000, so the extra 4,000 warmup iterations bought no precision. The measured
July wall times are in `AGENT.md` §3.2.

One model is 4 tasks × 16 CPUs = 64 CPUs, so two fit inside `long`'s 140-CPU
per-user cap and a third queues. That costs nothing: `--time` is per task, and
pending time does not count against it.

**The 8 h `general` partition is enough for every model** (measured
2026-09-21, `AGENT.md` §3.2/§3.2b): the slowest shard of the nine models
refitted that day was 2.05 h, and the two the projections had flagged as
9 h and 8 h -- Reality and Valence -- came in at 34-50 min per shard once
`cogmod_inits()` replaced `init = 0`. Prefer `general`:

```bash
./hpc fit Entropy --partition=general
```

`general` also has 400 CPUs against `long`'s 140, so six models run at once
instead of two -- and `long` is shared with IGC, whose jobs can hold it for
days, in which case a FakeArt job sent there simply queues.

Since 2026-09-22 there is a third option for when the account's own quotas are
busy: `--partition=sussexneuro` draws on a separate departmental allowance
rather than on `general`'s 400 or `long`'s 140, and dispatches at higher
priority. It is not a wall-clock decision -- every model already fits in 8 h --
but it is how a FakeArt model runs alongside a full IGC production set instead
of behind it. See "Partitions and resource limits" for the group-pool caveats.

The two heaviest models were run one chain per task, so each chain gets all
16 threads instead of sharing with a second (`AGENT.md` §3.2b):

```bash
FA_CHAINS=1 ./hpc fit Reality \
  --partition=general --array=1-8 --cpus-per-task=16 --mem=128G
```

Same 8 chains and 4,000 draws, ~half the per-chain wall, 128 CPUs instead of
64. The risk it adds: a lone chain that dies at init loses its whole task
rather than half of one, which shows up as fewer than 8 chains on the
combined fit -- so check `brms::nchains()` after combining.

If a task ever *is* killed at the wall it loses only its own chain; the shards
that finished are kept, and resubmitting with the default
`FA_FILE_REFIT=never` re-runs only the missing ones.

When a model is done:

```bash
./hpc combine Beauty
./hpc pull                 # combined/*.rds -> analysis/models/Beauty.rds
```

`combine` is one job, not an array. It merges the shards, adds **`loo` over
every draw** and **keeps the shards** (a combined fit is minutes to rebuild
from them; each shard is hours of compute). Override per run only if a model
overruns `general`'s 8 h:

```bash
FA_CRITERION=waic ./hpc combine Beauty            # cheaper criterion
FA_CRITERION_NDRAWS=1500 ./hpc combine Beauty     # or fewer draws
FA_CRITERION=none ./hpc combine Beauty            # merge only
FA_DELETE_SHARDS=1 ./hpc combine Beauty           # drop shards after a verified merge
```

Keeping shards means the `file_refit = "never"` trap is live: a shard on disk
is silently reused even when the formula or the data changed. **A changed
model or dataset needs its own `FA_MODELS_DIR`, or `FA_FILE_REFIT=always`.**
In particular: the 2026-09-20 data update (one added participant, corrected
eye-tracking) means every existing shard on the cluster predates the current
data. Refit with `FA_FILE_REFIT=always`, or clear `models/` first.

`combine_model.R` strips each shard's `$file` slot before merging. A shard is
written by `brm(file = ...)` and remembers its own path; `combine_models()`
keeps the first shard's, and `add_criterion()` writes the fit back to whatever
`$file` says, which would silently save the *combined* fit over shard 1.

## Extract: the marginal means and contrasts

Fitting is not the only expensive half. The marginal means, the contrasts over
every distributional parameter and the posterior-predictive draws behind the
figures took **2 h 50 min** when `3_models.qmd` computed them locally on
2026-09-22, in one R session holding all 13 fits (~15 GB) — which is what made
the laptop unusable. `./hpc extract` moves that next to the fits:

```bash
./hpc extract Beauty
./hpc extract all              # 15 jobs at once; see below
./hpc pull 'estimates/*.rds'   # -> analysis/models/estimates/
```

One job per model, `general`, `--cpus-per-task=4 --mem=64G`, so 13 × 4 = 52
CPUs — well inside the per-user cap, and they all run in parallel. The wall
clock is therefore the slowest model rather than the sum. Measured locally,
per model: SelfRelevance 43 min, Worth 31, Authenticity 25, Reality 23,
Beauty 12, Beauty2 9, Artificiality 8, Shift 6, everything else ≤ 3.

`extract_model.R` reads `models/combined/<model>.rds` and writes
`models/estimates/<model>.rds`: convergence, per-parameter Rhat/ESS and
posterior summaries, marginal means, the three contrast tables, the marginal
CHOCO parameters, and the **reduced** predictive draws. Nothing else travels —
`estimate_prediction(keep_iterations = TRUE)` is 146 MB for Shift, but the
figures only ever plot a summary over response categories or one density curve
per draw, so both reductions run on the cluster and only their output is
pulled.

What is computed for which model is `outcome_info` in **`estimates.R`**, which
is the one definition shared by the cluster and the notebooks: a notebook
`source()`s the same file and does only tables, prose and plots. Neither
`3_models.qmd` nor `4_memory.qmd` opens a `brmsfit` any more, so both render in
about a minute and neither needs a knitr cache.

### The memory models are a different shape

`MemoryCondition` and `MemoryBelief` go through the same `./hpc extract`, but
they are not `3_models.qmd` outcomes and do not belong in `outcome_info`: they
are categorical, contrast a single factor (`Condition` / `Belief`) with no
Emotion stratification, and have no figure needing predictive draws. They get
their own `memory_info` registry and `get_memory_estimates()`, which does the
two calls that `4_memory.qmd` used to make inline —

```r
estimate_means(m_cond1, by = "Condition")
estimate_contrasts(m_cond1, contrast = "Condition", test = "pd")
```

— and nothing else. `get_estimates()` dispatches on which registry the name is
in, so `./hpc extract all` covers all 15 models and `4_memory.qmd` reads its
two `.rds` exactly as `3_models.qmd` reads its thirteen. Adding a model to
either notebook means adding a registry entry here; without one, `extract`
fails immediately with a message naming both registries.

Re-running is cheap and safe — the fit is only read — so a new parameter or a
different iteration count is a resubmit, never a refit. `FA_SEED` (default
1234) fixes the sampled parts:

```bash
FA_SEED=99 ./hpc extract Beauty
```

### Participant-level indices (`7_correlates.qmd`)

`./hpc individual <model|all>` runs the same job with `FA_WHAT=individual`:
only `get_individual()` (estimates.R), for the dpars listed in the model's
`individual` field of `outcome_info`, written to `models/individual/`. It
leaves `models/estimates/` untouched and takes under a minute per model
(`--mem=32G`).

```bash
./hpc individual Beauty
./hpc pull 'individual/*.rds'
```

## Models

`models.R` holds one entry per model: the outcome column it is fitted to, a
function returning the brms formula and, when it is not the Phase-1 trial
file, which data file to use (`data = "memory"`). It is the only place a model
is defined:
`fit_model.R` fits the one named by `FA_MODEL`, `combine_model.R` merges the
same one, and `./hpc` reads the *names* straight out of the file (which is why
the declaration lines must stay in the form `  <name> = list(`).

Every rating and gaze model has the design `Condition * Emotion` (3 labels ×
4 stimulus emotion quadrants) with `(Condition * Emotion | Participant)` and
`(Condition | Item)` on the main and most distributional parameters. The
memory models are `Condition` only, on the follow-up file. Names match the
files the notebooks read (`models/<name>.rds`: `3_models.qmd` for the first
thirteen, `4_memory.qmd` for the memory ones, `5_realitydeterminants.qmd` for `RealityBeauty` / `AuthenticityBeauty`).

| model | outcome | family | notes |
| --- | --- | --- | --- |
| `Beauty` | `Beauty` | `cogmod_choco()` | all 8 dpars modelled; `pex`/`bex`/`pmid ~ Condition + (1 \| Participant)` |
| `Valence` | `Valence` (1..7) | `cogmod_betadiscrete()`, `vint(7)` | `pzero = 0` |
| `Meaning` | `Meaning` (0..6) | `cogmod_betadiscrete()`, `vint(6)` | zero hurdle `pzero` with the full design |
| `Worth` | `Worth` (ordered $0..$100k) | `cumulative()` | `disc ~ 1 + (1 \| Participant) + (1 \| Item)` |
| `Entropy` | `Gaze_Entropy` | `Beta()` | + `Gaze_nSamples`; gaze trials only |
| `pLeft` | `Gaze_pLeft` | `zero_one_inflated_beta()` | `zoi`, `coi ~ 1 + (1 \| Participant)` |
| `pCenter` | `Gaze_pCenter` | `zero_one_inflated_beta()` | as pLeft |
| `Shift` | `Gaze_Shift` | `lognormal()` | `sigma` modelled |
| `Reality` | `Reality` | `cogmod_choco()` | "Syntheticness"; 317 participants |
| `Authenticity` | `Authenticity` | `cogmod_choco()` | 317 participants |
| `Beauty2` | `Beauty2` | `cogmod_choco()` | follow-up; 220 participants |
| `SelfRelevance` | `SelfRelevance` (ordered 0..6) | `cumulative()` | follow-up |
| `Artificiality` | `PerceivedArtificiality` | `cogmod_choco()` | follow-up, "new" items only (~6,000 rows) |
| `MemoryCondition` | `AnswerCondition` (4 categories) | `categorical()` | **`data = "memory"`**; `~ Condition + (1 + Condition \| Participant) + (1 + Condition \| Item)`, `Condition` has a 4th level `New Items`; 220 × 96 = 21,120 rows |
| `MemoryConditionBelief` | `AnswerCondition` | `categorical()` | `data = "memory"`, `subset` = old items with a Phase-2 belief (10,416 rows); `~ Condition + Belief`, both slopes by participant and item |
| `RealityBeauty` | `Reality` | `cogmod_choco()` | `prepare = fa_prepare_beauty` (Phase-1 `Beauty` centred within participant → `Beauty_w`); `Condition * Beauty_w` on mu/conf, `(Condition * Beauty_w \| Participant) + (Condition + Beauty_w \| Item)`; extracted by `get_mediation_estimates()` |
| `AuthenticityBeauty` | `Authenticity` | `cogmod_choco()` | as `RealityBeauty` |

Priors start from `cogmod_priors(f, data)` for the cogmod families (since
cogmod 0.3.3 dev of 2026-09-20 it covers CHOCO and Discrete-Beta:
`normal(0, 0.5)` slopes and informed intercepts on every auxiliary dpar,
`exponential(1)` group SDs) or `brms::get_prior()` for native ones, and
`fa_priors()` in `models.R` then fills **only what is left flat**:
`normal(0, 2)` on a flat blanket slope and `normal(0, 1)` on that dpar's
interaction terms, `normal(0, 3)` / `normal(0, 5)` on flat cogmod intercepts.
Nothing the family helper set is overwritten. Starting values are
`cogmod_inits(f, data)` for the cogmod families (a data-informed init
function, one draw per chain) and `init = 0` for native ones.

Adding a model is one entry in `models.R` and nothing else. An entry may also set `subset` (rows to keep) and/or `prepare` (derived predictors, e.g. within-participant centring), both `function(data) data`, applied in `fit_model.R` after the outcome's NA rows are dropped. If it needs a
data file other than the Phase-1 trial file, set its `data` slot and, for a
new file, add a loader branch in `fit_model.R` and a `fa_prepare_*()` in
`models.R` (as `data = "memory"` does).

### The cogmod API changed under these models

The July 2026 fits used `choco()`, `betadiscrete()`, `choco_stanvars()` and
`Meaning | vint(6)`. cogmod 0.3 renamed the constructors to `cogmod_choco()`
and `cogmod_betadiscrete()` and made the helpers family-generic
(`cogmod_stanvars(f)`), and on 2026-09-20 `cogmod_priors()` / `cogmod_inits()`
gained CHOCO and Discrete-Beta support, which the scripts now rely on (the
fits refuse to start below cogmod 0.3.3; an older 0.3.3 *build* fails in
`fa_inits()`, and `./hpc install cogmod` fixes both). **The distributional
parameter names are unchanged**
(`mu`, `confright`, `confleft`, `precright`, `precleft`, `pex`, `bex`, `pmid`;
`mu`, `phi`, `pzero`), so `3_models.qmd` and `7_correlates.qmd` read a refit
exactly as they read the old fits. The `cumulative()` fits also carry the
`disc` parameter the notebooks use.

## Paths

Nothing is hard-coded to one account. `./hpc` passes the paths to `sbatch`
via `--output/--error/--chdir/--export`, and the scripts read them from
`FA_USERS_DIR` / `FA_MODELS_DIR` / `FA_SCRATCH_DIR`. Defaults:

| variable | default |
| --- | --- |
| `FA_HPC_USER` | `dmm56` |
| `FA_HPC_GROUP` | `psych` |
| `FA_PROJECT` | `FakeArt` |
| `FA_USERS_DIR` | `/mnt/lustre/users/$FA_HPC_GROUP/$FA_HPC_USER/$FA_PROJECT` |
| `FA_SCRATCH_DIR` | `/mnt/lustre/scratch/$FA_HPC_GROUP/$FA_HPC_USER/$FA_PROJECT` |
| `FA_MODELS_DIR` | `$FA_USERS_DIR/models` |
| `FA_R_MODULE` | `CmdStanR/0.7.1-foss-2023a-R-4.3.2` |
| `FA_R_LIBS` | `/mnt/lustre/users/$FA_HPC_GROUP/$FA_HPC_USER/cluster_R_libs/x86_64-pc-linux-gnu-library/4.3` |

`FA_HPC_USER` and `FA_HPC_GROUP` rewrite all the paths at once. Note they
change the *paths*, not who you log in as: that comes from the `artemis` entry
in your own `~/.ssh/config`.

## Running from a second cluster account

The per-user CPU quota is per account, so a colleague with their own Artemis
account and a clone of this repo can fit other models at the same time.

A second account is no longer the only way to get a second allowance: `dmm56`
can also submit to `sussexneuro`, whose quota is independent of `general`'s and
`long`'s (see "Partitions and resource limits"). The two stack, so the widest
arrangement is a colleague on `general` plus a `--partition=sussexneuro` job
here.

Their setup, once:

```bash
bash <Lab>/hpc/scripts/setup-ssh.sh oc236      # lab hub script
echo 'FA_HPC_USER=oc236' > analysis/server/hpc.local   # gitignored
cd analysis/server
./hpc check && ./hpc setup && ./hpc install && ./hpc precompile && ./hpc push
```

`hpc.local` is sourced by `./hpc` before any default is applied and is in
`.gitignore`. Add `FA_HPC_GROUP=...` if they are not in the `psych` tree.

You cannot read another account's fits on the cluster, so the files are handed
over ([hub `jobs.md#sharing-results-between-accounts`](https://github.com/RealityBending/Lab/blob/main/hpc/jobs.md#sharing-results-between-accounts)):
they `./hpc combine` and `./hpc pull`, then send `combined/<model>.rds`.
Combined FakeArt fits run 0.2 to 1 GB each (`ls -lh analysis/models/`).

## Run-shaping variables

`./hpc fit` / `./hpc combine` forward these to the job when you set them;
everything else keeps the script default.

| variable | default | purpose |
| --- | --- | --- |
| `FA_NPARTICIPANTS` | `all` | subset size for tests, e.g. `20` |
| `FA_WARMUP` | `1000` | warmup iterations per chain |
| `FA_SAMPLES` | `500` | post-warmup iterations per chain |
| `FA_THIN` | `1` | keep every n-th draw |
| `FA_CHAINS` | `2` | chains per array task; threads per chain is `cpus / chains` |
| `FA_DATA` | `github` | or a local directory holding the CSVs (`data_task`, `data_eyetracking`, `data_memory_task`; laptop tests) |
| `FA_FILE_REFIT` | `never` | `always` forces a clean refit |
| `FA_CRITERION` | `loo` | `waic` is cheaper; `none` skips it |
| `FA_CRITERION_NDRAWS` | all | subsample the draws the criterion uses |
| `FA_DELETE_SHARDS` | unset | set to `1` to drop shards after combining |
| `FA_COGMOD_REF` | `dev` | which cogmod branch/tag `./hpc install` tracks (shared library; see `install_pkgs.R`) |
| `FA_COGMOD_MIN` | `0.3.3` | the floor `fit_model.R` refuses to start below |

## Precompile the CmdStan header before a cold array

Run `./hpc precompile` once after any change to the toolchain, the CmdStan
version, or the `stan_model_args` in `fit_model.R`, and keep `precompile.R`'s
`cpp_options` identical to `fit_model.R`'s. The header is per **account**, so
if the IGComputational fits already built the `threads_nochecks` variant this
is a no-op. Why it matters: [hub `toolchain.md#precompiled-header`](https://github.com/RealityBending/Lab/blob/main/hpc/toolchain.md#precompiled-header).

## Partitions and resource limits

Quotas, `--time` policy and the `sussexneuro` rules are in
[hub `artemis.md`](https://github.com/RealityBending/Lab/blob/main/hpc/artemis.md) and [`jobs.md#wall-time`](https://github.com/RealityBending/Lab/blob/main/hpc/jobs.md#wall-time).
For this project:

- **`general` is the default choice**: every model fits in its 8 h
  (`AGENT.md` §3.2b), and its 400 CPUs take six models at once.
- `long`'s 140 CPUs take `floor(140 / 16) = 8` tasks, i.e. two FakeArt models
  at the default `--array=1-4` — and **FakeArt and IllusionGameComputational
  run as the same cluster account**, so an IGC array holding `long` is holding
  it against FakeArt too.
- **`sussexneuro`** is the overflow, not the default (`AGENT.md` §3.6): a
  FakeArt array is 4 x 16 = 64 CPUs for a few hours, but it is borrowed from a
  group pool that our own IGC `gam_ddm5` also draws on. Look first:

  ```bash
  ./hpc sh "squeue -p sussexneuro -o '%.10i %.10u %.8T %.5C %.12L'"
  ./hpc fit Entropy --partition=sussexneuro
  ```

- If jobs pend everywhere, check the account-wide 550-CPU cap before
  switching partition (`AGENT.md` §3.6a).

## R environment on the cluster

The jobs load one module, `CmdStanR/0.7.1-foss-2023a-R-4.3.2` (R 4.3.2 +
brms 2.21 + cmdstanr 0.7.1 + dplyr), plus a project library that shadows it:

```
/mnt/lustre/users/psych/$FA_HPC_USER/cluster_R_libs/x86_64-pc-linux-gnu-library/4.3
```

The library holds `cogmod`, `datawizard`, `loo` and a current `cmdstanr` (the
module's 0.7.1 cannot read CmdStan ≥ 2.36 output). It is **the same library
IGComputational uses**, so `./hpc install` is normally a no-op here, and
`./hpc install cogmod` refreshes cogmod for both projects at once. That is why
`FA_COGMOD_REF` defaults to `dev` like the IGC scripts: installing `main` from
here would downgrade the shared cogmod under the IGC fits, which need ≥ 0.3.3.

The pre-2026-09 FakeArt scripts used `R/4.4.1-gfbf-2023b` with the account's
shared `R_LIBS_USER`; that module has no `cmdstanr`, and the shared library is
built for R 4.2, which is why they needed a manual `install.packages()` on the
login node. The `.slurm` files no longer depend on `~/.bashrc` at all: SLURM
does not source it, and they set `R_LIBS` explicitly.

The `.slurm` files handle the cluster's module quirks
([hub `toolchain.md#modules`](https://github.com/RealityBending/Lab/blob/main/hpc/toolchain.md#modules)).

`.gitattributes` forces LF on `*.slurm`, `*.sh`, `hpc` and `analysis/server/*.R`
so a CRLF file never reaches the cluster (which fails with `bad interpreter`).
`./hpc push` strips CR as well.

## Files

| file | role |
| --- | --- |
| `hpc` | the driver: check/setup/push/install/precompile/models/fit/combine/extract/queue/progress/log/ls/pull/cancel/sh |
| `install_pkgs.R` | builds the (shared) project R library (`./hpc install`) |
| `precompile.R` | builds the CmdStan precompiled header (`./hpc precompile`) |
| `models.R` | **the model registry**: one entry per model, plus data prep, priors, inits |
| `fit_model.R` | fits the model named by `FA_MODEL`, one shard per array task |
| `fit.slurm` | array job for the above |
| `combine_model.R` | merges one model's shards into `combined/<model>.rds`, adds `loo` |
| `combine.slurm` | job for the above |
| `estimates.R` | **the post-processing**: what a fit is turned into, plus the two registries (`outcome_info`, `memory_info`). Shared with `3_models.qmd` and `4_memory.qmd`, which `source("server/estimates.R")` it |
| `extract_model.R` | runs `get_estimates()` on one combined fit -> `estimates/<model>.rds` |
| `extract.slurm` | job for the above |
| `AGENT.md` | what is FakeArt-specific, what has been measured, what is open |
| `hpc.local` | **gitignored**: this machine's account settings, e.g. `FA_HPC_USER=oc236` |
| `server.md` | **gitignored**: local notes on this project's cluster dirs |
