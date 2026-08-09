# CRAN parallel-ecosystem statistics

How the parallel-framework figures on futureverse.org are produced, and every
judgment call that goes into them.

The scripts answer one question from several angles: how many packages on the
Comprehensive R Archive Network (CRAN) parallelize, which framework do they
reach for, and is that framework required or merely offered? The numbers are
defensible only if the counting rules are stated, so they are stated here.


## What the scripts produce

| Script | `make` target | Figures |
|---|---|---|
| `R/cran_snapshots.R` | - | none; shared data layer |
| `R/parallel_families.R` | - | none; ecosystem map and palette |
| `R/parallel_frameworks_over_time.R` | `stats-parallel-frameworks` | one band per package, 6 |
| `R/parallel_families_over_time.R` | `stats-parallel-families` | one band per ecosystem, 9 |
| `R/parallel_paradigms_over_time.R` | `stats-parallel-paradigms` | multi-processing vs multi-threading, 6 |
| `R/parallel_hard_vs_soft_over_time.R` | `stats-parallel-hard-vs-soft` | required vs offered, 3 |
| `R/parallel_families_downloads_over_time.R` | `stats-parallel-downloads` | downloads per ecosystem, 2 |

Portable Network Graphics (PNG) files are written to the repository root and
promoted to `figures/` by hand. Tidy series are written to
`cranlogs/parallel-frameworks/*.tsv`, which is where any number quoted in prose
should come from. Every figure quoted below is a snapshot of 2026-08-08 and moves
as CRAN does; those tab-separated values (TSV) files are the source of truth.

`make stats` runs everything. The snapshot cache is shared, so the first script
pays the download cost - roughly five minutes - and the rest are near-instant.


## Data sources

**CRAN package indexes over time.** Posit Public Package Manager (PPPM) serves a
true point-in-time snapshot of CRAN, but only from 2017-10 onwards. EverCRAN
reaches back to the beginning, but it is *cumulative*: its snapshot for a given
date also serves every package archived before that date. Left uncorrected, that
inflates the denominator by about 11% at the handover and puts a visible step in
every curve.

The correction: for the EverCRAN era, drop the packages CRAN had already archived
by that date, using the archival dates recorded by crandb. A package on CRAN
today is never dropped, which slightly overcounts the few that were archived and
later restored. The result lands within about 6% of the EverCRAN-minus-PPPM
difference on every date where both sources exist, and the seam disappears -
2017-10 reads 6.711% and 2017-11 reads 6.769%.

Monthly snapshots from 2010-01 onwards. `SystemRequirements` is *not* available:
no historical package index carries it, which is why multi-threading cannot be
measured properly (see below).

**Downloads.** The weekly all-CRAN cache built by `R/cran_stats.R`, reused rather
than re-downloaded. Each weekly figure is the *median daily* download count for
that package that week. Coverage starts 2015-06, where that cache begins.


## What counts as a parallel framework

Included: the packages that implement, or give direct access to, a parallel
backend. Excluded, with reasons:

- **foreach** - an iteration application programming interface (API), not a
  backend. It is the `do*()` adaptors that parallelize. Counting **foreach**
  as well would count the same packages twice.
- **doRNG** - adds reproducible random number generation (RNG) on top of
  whatever backend is already registered; it parallelizes nothing itself.
- **nanonext** - a transport layer.
- **RhpcBLASctl**, **OpenMPController** - these control how many threads Basic
  Linear Algebra Subprograms (BLAS) and OpenMP may use, which is most often done
  to *suppress* nested threading while forking. Of the 19 packages depending on
  them without also depending on a threading engine, 11 are multi-processing
  packages doing exactly that.
- **data.table** - uses OpenMP internally, but importing it is choosing a fast
  library, not choosing to parallelize. Including it would add roughly 1,800
  packages and swamp the threading band.


## The seven ecosystems

Defined once in `R/parallel_families.R`, so the dependency and download figures
cannot drift apart: `snow era`, `parallel (base R)`, `foreach backends`,
`HPC schedulers` for the high-performance compute (HPC) job schedulers,
`C++ threading`, `mirai`, and `Futureverse`.

Membership calls worth knowing:

- **doFuture** counts as Futureverse, not as a foreach backend, because the
  future API is what the author programs against. This is close to free: of its
  52 hard dependents, 45 already depend on another Futureverse package, so
  moving it would cost Futureverse 7 packages and gain foreach 46.
- **future.batchtools** counts as Futureverse over `HPC schedulers`, for the same
  reason. It has one dependent, so it is immaterial either way.
- **parallelly** counts as Futureverse, although a fair number of its 115
  dependents use it standalone for `availableCores()`.
- **crew** and **crew.cluster** sit with **mirai**, since that is their engine.

**Multi-threading is excluded from the ecosystem figures**, so those present the
multi-process ecosystems. Set `exclude_families <- character(0)` in
`R/parallel_families.R` to fold it back in. The paradigm figures are where
processing and threading are compared, so nothing is excluded there.


## Counting rules

**Union, never intersection.** A package joins an ecosystem if it depends on *at
least one* member. Intersection would give zero - no package depends on all ten
Futureverse packages.

**Within an ecosystem, a package counts once.** Importing **future**,
**future.apply** and **furrr** is one unit of Futureverse, not three.

**Across ecosystems, a package counts once in each.** Those are separate choices.
As of 2026-08, that is 2,793 memberships across 2,243 distinct multi-process
packages, so 550 packages belong to more than one ecosystem - almost all of them
base **parallel** plus something built on top of it.

**Band heights are rescaled.** Stacking 2,793 memberships against CRAN's 24,586
packages would read 11.4% and overstate adoption. Instead each band is its share
of the memberships, scaled so the stack sums to 2,243/24,586 = 9.1%, the true
distinct-package figure. So band *ratios* are membership shares; stack *height*
is the distinct-package count. The `-relative` figures normalise by memberships
and therefore fill 100%; their denominator is stated in the caption.

**The paradigm figures are the exception**: `multi-processing`, `both` and
`multi-threading` are mutually exclusive, and `both` is a genuine intersection.
That is the only intersection in the suite.


## Dependency kinds

Three, drawn for every parameterised figure:

- **hard** - `Depends`, `Imports`, `LinkingTo`. The framework is installed whether
  the user wants it or not.
- **soft** - `Suggests`. Parallelism is offered, not forced.
- **any** - the union, derived from the other two rather than collected.

`Enhances` is excluded: it declares that a package improves the named one, which
is a different statement from using it.

As of 2026-08, multi-process penetration of CRAN is 9.1% hard, 3.1% soft, and
11.7% for either. Including multi-threading those read 10.1%, 3.2% and 12.6%.

The hard/soft split is worth reading per framework rather than in aggregate. The
aggregate soft share fell from 67% in 2010 to 19% today, but that is dominated by
base **parallel**. Per framework the newer ones are markedly more often offered
than required - **mirai** 57%, **future** 41% and rising from 10% in 2018,
against **parallel** 18% and **doParallel** 20%, both flat since 2015.
**RcppParallel** sits at 2%, which is mechanics rather than conservatism:
`LinkingTo` cannot be optional.


## Download statistics

Two corrections and one thing that cannot be corrected.

**Dependency double counting, corrected.** Summing an ecosystem's packages
inflates it, because installing **furrr** fetches **future**, which fetches
**parallelly**, and all three are counted. The fix: build the dependency graph
among each ecosystem's *own members*, split it into connected components, and
take the largest member of each component rather than the sum. Within a component
every install fetches the shared root, so the largest member is the best single
estimate of distinct install events; across components nothing forces overlap, so
those are summed. Both measures are kept in the TSV file, as `downloads` and
`downloads_sum`.

The effect lands where the dependency chains are deep:

| Ecosystem | Naive sum | De-duplicated | Inflation |
|---|---|---|---|
| Futureverse | 41,238 | 14,062 | 2.93x |
| foreach backends | 7,000 | 7,000 | 1.00x |
| snow era | 4,808 | 4,627 | 1.04x |
| mirai | 2,547 | 2,452 | 1.04x |
| HPC schedulers | 491 | 491 | 1.00x |

Nearly half the apparent total was double counting, and all of it Futureverse's -
the only ecosystem with a deep internal chain. Ecosystems of siblings were never
inflated.

**Base R's `parallel` cannot appear.** It ships with R, is not on CRAN, and has no
download record. It is the largest ecosystem in the dependency figures at 53.3%
of multi-process use, so download shares are over a strictly smaller universe and
are **not** comparable to the dependency shares.

**A download is an install, not a choice.** A package pulled in as someone else's
dependency counts the same as one somebody chose. Nothing available here can
separate the two.


## Known limitations

1. **Multi-threading is a lower bound.** It counts packages declaring a threading
   engine (**RcppParallel**, **RcppThread**). Packages calling OpenMP straight
   from `src/Makevars` via `$(SHLIB_OPENMP_*FLAGS)` are invisible: only 26
   packages on CRAN mention OpenMP in `SystemRequirements`, and no historical
   package index carries that field anyway. Recovering the real number would mean
   unpacking every source tarball at every snapshot date.
2. **Cross-ecosystem double counting remains** in the download figures, as it does
   in the dependency figures.
3. **Component-max is a lower bound** on distinct install events. One user
   installing both **doParallel** and **doSNOW** is counted twice.
4. **cranlogs covers the Posit content delivery network (CDN) only**, and its
   counts include continuous integration (CI) runners and mirroring. Read the
   trend, not the level.
5. **EverCRAN restorations** are slightly overcounted before 2017-11, as described
   above.
6. **Download coverage starts 2015-06**, not 2010. Extending to the cranlogs start
   of 2012-10 means re-running the multi-hour all-CRAN download job.

One reassuring detail on the double counting: cranlogs counts actual fetches, so
a dependency already installed at the right version is not fetched again. In the
raw data **future** (14,422 median daily downloads) slightly exceeds
**parallelly** (13,351), even though every **future** install requires it.


## Colours

Categorical palettes are hand-assigned and validated for colour-vision deficiency
(CVD) on the pairs that touch in the stack, not eyeballed. Worst adjacent CVD
delta-E: 9.2 for the per-package figure, 16.2 for the ecosystem figure, 9.2
all-pairs for the paradigm figure (OKLab x100, light surface). Colours follow the
entity, so base **parallel** is amber, foreach green and Futureverse red wherever
they appear. `other` is deliberately desaturated so it recedes; it is the only
slot below the chroma floor.
