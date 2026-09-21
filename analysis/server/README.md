# Running the models on Artemis (Sussex HPC)

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
account). Its `analysis/server/AGENT.md` holds the cluster measurements that
were not repeated here; this folder's `AGENT.md` holds what is specific to
FakeArt.

## The cluster, in a browser

Everything below drives Artemis over SSH, but the web interface is useful for
looking at files, checking a job by hand, and installing your SSH key the first
time. All of it needs the **GlobalProtect VPN** connected first.

| | |
| --- | --- |
| Open OnDemand (OOD) | <https://ood.artemis.hrc.sussex.ac.uk/> |
| a shell on the login node | OOD → Clusters → `>_ artemis Shell Access` |
| submit a `.slurm` by hand | OOD → Jobs → Jobs Composer (set `FA_MODEL` yourself) |
| browse your files | `https://ood.artemis.hrc.sussex.ac.uk/pun/sys/dashboard/files/fs//mnt/lustre/users/psych/<user>/FakeArt` |
| Artemis documentation | <https://artemis-docs.hpc.sussex.ac.uk/artemis/> |

Storage, for orientation:

| path | use |
| --- | --- |
| `/mnt/lustre/users/<group>/<user>/FakeArt/` | long-term: code and fitted models live here |
| `/mnt/lustre/scratch/<group>/<user>/FakeArt/` | fast scratch: job logs go here |
| `/mnt/nfs2/<group>/<user>/` | home directory (holds `~/.cmdstan`) |

## One-time setup (per machine)

```bash
bash analysis/server/setup-ssh.sh
```

Generates a machine-local keypair at `~/.ssh/artemis`, adds the `artemis`
alias to `~/.ssh/config`, and prints the exact command to install the public
key on the cluster. Idempotent, and shared across projects: a machine already
set up for IllusionGameComputational needs nothing more.

Then, once per cluster account:

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
`fit_model.R` reads `data/data_task.csv` and `data/data_eyetracking.csv` from
the raw GitHub URL. Commit and push the data before `./hpc fit`, or the job
silently fits the previous dataset.

### How to check job status, cheaply

For an agent asked to "check on the jobs": two commands, not a log dump.

**Whenever a user asks for status or progress, report:** the state of every
job (`./hpc queue`), and for each chain the highest iteration seen and a rough
ETA, estimated from iterations-so-far vs. elapsed `TIME` and extrapolated to
warmup + samples (5,800 by default).

```bash
./hpc queue                # one line per array task: STATE, TIME, TIME_LEFT, reason if PENDING
./hpc progress Beauty      # per log: latest 'Chain N Iteration:' line per chain, REPORT, SUCCESSFUL, errors
```

`queue` answers "is it running, pending, or dead". `progress` answers "how far
has it got" without the R/brms/compiler banner that fills a `.out`. Two lines
matter:

- `REPORT ...`: printed once at the end of a shard: wall time, `n_leapfrog`,
  treedepth, step size, divergences, max Rhat, min ESS ratio. This is the line
  that says whether the fit is healthy.
- `Chain N Iteration: ...`: printed periodically; the highest number seen is
  the only progress signal before a `REPORT` exists.

A long stretch with no fresh `Iteration` line is **not** by itself a hang:
cmdstanr spaces the console refresh through the run. Trust `TIME` in
`./hpc queue` (climbing, task not requeued) over the absence of output.

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

The defaults in `fit.slurm` are the configuration the July 2026 fits used:
`--array=1-8`, `--cpus-per-task=16`, `--mem=32G`, `--partition=long`, no
`--time` (each task gets `long`'s 8-day maximum), with `FA_WARMUP=5000`,
`FA_SAMPLES=800`, `FA_THIN=2`, `FA_CHAINS=2`. That is 8 shards × 2 chains ×
400 kept draws = **6,400 draws per model**.

One model is 8 tasks × 16 CPUs = 128 of `long`'s 140-CPU per-user cap, so
models run one at a time and later submissions queue. That costs nothing:
`--time` is per task, and pending time does not count against it. If the wall
matters more than draws, `--array=1-4` halves both.

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

## Models

`models.R` holds one entry per model: the outcome column it is fitted to and a
function returning the brms formula. It is the only place a model is defined:
`fit_model.R` fits the one named by `FA_MODEL`, `combine_model.R` merges the
same one, and `./hpc` reads the *names* straight out of the file (which is why
the declaration lines must stay in the form `  <name> = list(`).

Every model has the design `Condition * Emotion` (3 labels × 4 stimulus
emotion quadrants) with `(Condition * Emotion | Participant)` and
`(Condition | Item)` on the main and most distributional parameters. Names
match the files `3_models.qmd` reads (`models/<name>.rds`).

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

Adding a model is one entry in `models.R` and nothing else.

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
`mu`, `phi`, `pzero`), so `3_models.qmd` and `4_correlates.qmd` read a refit
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
account and a clone of this repo can fit other models at the same time. Their
setup, once:

```bash
FA_HPC_USER=oc236 bash analysis/server/setup-ssh.sh
echo 'FA_HPC_USER=oc236' > analysis/server/hpc.local   # gitignored
cd analysis/server
./hpc check && ./hpc setup && ./hpc install && ./hpc precompile && ./hpc push
```

`hpc.local` is sourced by `./hpc` before any default is applied and is in
`.gitignore`. Add `FA_HPC_GROUP=...` if they are not in the `psych` tree.

You cannot read another account's fits on the cluster (every user directory is
`drwx------`), so the files are handed over: they `./hpc combine` and
`./hpc pull`, then send `combined/<model>.rds` by a file-transfer service.
Combined FakeArt fits run 0.2 to 1 GB each (`ls -lh analysis/models/`).

## Run-shaping variables

`./hpc fit` / `./hpc combine` forward these to the job when you set them;
everything else keeps the script default.

| variable | default | purpose |
| --- | --- | --- |
| `FA_NPARTICIPANTS` | `all` | subset size for tests, e.g. `20` |
| `FA_WARMUP` | `5000` | warmup iterations per chain |
| `FA_SAMPLES` | `800` | post-warmup iterations per chain |
| `FA_THIN` | `2` | keep every n-th draw |
| `FA_CHAINS` | `2` | chains per array task; threads per chain is `cpus / chains` |
| `FA_DATA` | `github` | or a local directory holding the two CSVs (laptop tests) |
| `FA_FILE_REFIT` | `never` | `always` forces a clean refit |
| `FA_CRITERION` | `loo` | `waic` is cheaper; `none` skips it |
| `FA_CRITERION_NDRAWS` | all | subsample the draws the criterion uses |
| `FA_DELETE_SHARDS` | unset | set to `1` to drop shards after combining |
| `FA_COGMOD_REF` | `dev` | which cogmod branch/tag `./hpc install` tracks (shared library; see `install_pkgs.R`) |
| `FA_COGMOD_MIN` | `0.3.3` | the floor `fit_model.R` refuses to start below |

## Precompile the CmdStan header before a cold array

Run `./hpc precompile` once after any change to the toolchain, the cmdstan
version, or the `stan_model_args` in `fit_model.R`. The precompiled header
lives in `~/.cmdstan/<version>/stan/src/stan/model/model_header.hpp.gch/`
(a directory, one ~800 MB variant per flag combination), so it is **per
account, not per project**: if the IGComputational fits already built the
`threads_nochecks` variant on this account, this is a no-op. If it is missing
when an array starts, every task races to build it and all but one die with
`while reading precompiled header: No such file or directory`, leaving a
corrupt variant that blocks all compilation until
`cmdstanr::rebuild_cmdstan()`. Keep `precompile.R`'s `cpp_options` identical to
`fit_model.R`'s.

## Partitions and resource limits

Per-user quotas on Artemis (verified with `sacctmgr` on 2026-09-17 for the
IGC project; the cluster, not the project, sets them):

| partition | max runtime | max CPUs | max RAM |
| --- | --- | --- | --- |
| `short` | 2 hours | 550 | 3.6 TB |
| `general` (default) | 8 hours | 400 | 2.7 TB |
| `long` | 8 days | **140** | 900 GB |
| `verylong` | 30 days | 70 | 900 GB |

Every partition has `DefaultTime=NONE`, so a job that passes **no `--time`**
gets the partition's maximum. Choosing the partition is the whole wall-clock
decision; do not set `--time` below it for a job whose runtime is a projection,
because a task killed at the wall loses its entire chain (Stan cannot
checkpoint mid-run).

`long`'s 140 CPUs cap concurrency at `floor(140 / 16) = 8` tasks, i.e. one
FakeArt model at a time at the default `--array=1-8`. Anything beyond it sits
in `PENDING (QOSMaxCpuPerUserLimit)`.

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

Two Artemis quirks the `.slurm` files work around:

1. SLURM runs batch scripts in a *non-interactive* shell where `module` is not
   defined, so they source `/etc/profile.d/lmod.sh` first.
2. Compute nodes only get `/opt/ohpc/pub/modulefiles` on `MODULEPATH`; the
   EasyBuild tree holding R/CmdStanR is on the login node's path only. The
   scripts `module use /mnt/shared/easybuild/modules/all` before `module load`.

`.gitattributes` forces LF on `*.slurm`, `*.sh`, `hpc` and `analysis/server/*.R`
so a CRLF file never reaches the cluster (which fails with `bad interpreter`).
`./hpc push` strips CR as well.

## If SSH starts refusing connections

`kex_exchange_identification: read: Connection reset` means sshd is
rate-limiting a burst of connections, not that the VPN dropped. `./hpc push`
sends everything through a single tar pipe for exactly this reason; if you do
trip it, wait a couple of minutes and retry.

## Files

| file | role |
| --- | --- |
| `hpc` | the driver: check/setup/push/install/precompile/models/fit/combine/queue/progress/log/ls/pull/cancel/sh |
| `setup-ssh.sh` | per-machine key + `~/.ssh/config` entry |
| `install_pkgs.R` | builds the (shared) project R library (`./hpc install`) |
| `precompile.R` | builds the CmdStan precompiled header (`./hpc precompile`) |
| `models.R` | **the model registry**: one entry per model, plus data prep, priors, inits |
| `fit_model.R` | fits the model named by `FA_MODEL`, one shard per array task |
| `fit.slurm` | array job for the above |
| `combine_model.R` | merges one model's shards into `combined/<model>.rds`, adds `loo` |
| `combine.slurm` | job for the above |
| `AGENT.md` | what is FakeArt-specific, what has been measured, what is open |
| `hpc.local` | **gitignored**: this machine's account settings, e.g. `FA_HPC_USER=oc236` |
| `server.md` | **gitignored**: account, keys, OOD URLs |
