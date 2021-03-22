# Futureverse

## Packages part of the Futureverse

### The core package

* [**future**](https://future.futureverse.org) - _Unified Parallel and Distributed Processing in R for Everyone_<br>
This is the core package of the future framework.  It implements the Future API, which comprise three basic functions - `future()`, `resolved()`, and `value()`, is designed to unify parallel processing in R at the lowest possible level. It provides a standard for building richer, higher-level parallel frontends without having to worry about and re-implement common, critical tasks such as identifying global variables and packages, parallel RNG, and relaying of output and conditions - cumbersome tasks that are often essential to parallel processing.
Nearly all parallel processing tasks can be implemented using this low-level API. But, most users and package developers use the futures via higher-level map-reduce functions provided by **future.apply**, **furrr**, and **foreach** with **doFuture**.


### Parallel map-reduce functions for popular programming style

* [**future.apply**](https://future.apply.futureverse.org) - _Apply Function to Elements in Parallel using Future_<br>
Implementations of `apply()`, `by()`, `eapply()`, `lapply()`, `Map()`, `.mapply()`, `mapply()`, `replicate()`, `sapply()`, `tapply()`, and `vapply()` that can be resolved using any future-supported backend, e.g. parallel on the local machine or distributed on a compute cluster. These `future_*apply()` functions come with the same pros and cons as the corresponding **base R** `*apply()` functions but with the additional feature of being able to be processed via the future framework.

* [**furrr**](https://davisvaughan.github.io/furrr/) - _Apply Mapping Functions in Parallel using Futures_<br>
Implementations of the family of `map()` functions from **purrr** that can be resolved using any **future**-supported backend, e.g. parallel on the local machine or distributed on a compute cluster.

* **foreach** with [**doFuture**](https://doFuture.futureverse.org) - _A Universal Foreach Parallel Adapter using the Future API of the **future** Package_<br>
Provides a `%dopar%` adapter such that any type of futures can be used as backends for the **foreach** framework and its `foreach()` function.

* **BiocParallel** with [**BiocParallel.FutureParam**](https://BiocParallel.FutureParam.futureverse.org) - _Use Futures with BiocParallel_<br>
A 'BiocParallelParam' class for using futures with the **BiocParallel** framework, e.g. `BiocParallel::register(FutureParam())`.   An alternative, is to use `BiocParallel::register(DoParam())` in combination of **doFuture**.


### Choosing how and where to parallelize

* [**future**](https://future.futureverse.org) - the **future** package has a set of built-in parallel backends that build upon the **parallel** package, e.g. `multicore`, `multisession`, and `cluster`.

* [**future.batchtools**](https://future.batchtools.futureverse.org) - _A Future API for Parallel and Distributed Processing using batchtools_<br>
Implementation of the Future API on top of the **batchtools** package. This allows you to process futures, as defined by the **future** package, in parallel out of the box, not only on your local machine or ad-hoc cluster of machines, but also via high-performance compute (HPC) job schedulers such as LSF, OpenLava, Slurm, SGE, and TORQUE/PBS, e.g. `y <- future.apply::future_lapply(files, FUN = process)`.

* [**future.callr**](https://future.callr.futureverse.org) - _A Future API for Parallel Processing using callr_<br>
Implementation of the Future API on top of the **callr** package. This allows you to process futures, as defined by the **future** package, in parallel out of the box, on your local (Linux, macOS, Windows, ...) machine. Contrary to backends relying on the **parallel** package (e.g. `future::multisession`), the `callr` backend provided here can run more than 125 parallel R processes.


### Reporting on progress

* [**progressr**](https://progressr.futureverse.org) - _An Inclusive, Unifying API for Progress Updates_<br>A
 minimal, unifying API for scripts and packages to report progress updates from anywhere including when using parallel processing. The package is designed such that the developer can to focus on what progress should be reported on without having to worry about how to present it. The end user has full control of how, where, and when to render these progress updates, including via progress bars of the popular **progress** package.
The future ecosystem support **progressr** at its core and many of the backends can report progress in a near-live fashion.

### Validation

* [**future.tests**](https://future.tests.futureverse.org) - _Test Suite for Future API Backends_<br>
Backends implementing the Future API, as defined by the **future** package, should use the tests provided by this package to validate that they meet the minimal requirements of the Future API. The tests can be performed easily from within R or from outside of R from the command line making it easy to include them package tests and in Continuous Integration (CI) pipelines.


### Supporting packages

* [**parallelly**](https://parallelly.futureverse.org) - _Enhancing the parallel Package_<br>
Utility functions that enhance the **parallel** package and support the built-in parallel backends of the **future** package.

* [**globals**](https://globals.futureverse.org) - _Identify Global Objects in R Expressions_<br>
Identifies global ("unknown" or "free") objects in R expressions by code inspection using various strategies (ordered, liberal, or conservative). The objective of this package is to make it as simple as possible to identify global objects for the purpose of exporting them in parallel, distributed compute environments.

* [**listenv**](https://listenv.futureverse.org) - _Environments Behaving (Almost) as Lists_<br>
List environments are environments that have list-like properties. For instance, the elements of a list environment are ordered and can be accessed and iterated over using index subsetting, e.g. `x <- listenv(a = 1, b = 2); for (i in seq_along(x)) x[[i]] <- x[[i]] ^ 2; y <- as.list(x)`.



## Uptake of future

Since the first CRAN release of **future** in June 2015, its uptake among end-users and package developers have grown steadily.
During March 2021, **future** was among the top-0.6% most downloaded package on CRAN (Figure 1) and there are 166 packages on CRAN and Bioconductor that directly depend on it (Figure 2).  For map-reduce parallelization packages **future.apply** (top-2.1% most downloaded) and and **furrr** (top 1.4%), the corresponding number of packages are 73 and 44, respectively.

As a reference, the popular **foreach**, release in 2009, was among the top-0.9% most downloaded packages during the same period and it has almost 800 reverse package dependencies on CRAN and Bioconductor.  The number of users that download **future** has grown rapidly whereas the the same number has slowly decreased for the **foreach** package (Figure 1).  Similarly, the number of reverse package dependencies on **future** appear to grow faster than for **foreach** (Figure 2).

_Importantly, the comparison toward **foreach** is only done as a reference for the current demand for parallelization frameworks in R and to show the rapid uptake of the future framework since its release.  It is not a competion because **foreach** can per design be used in companion with the future framework via **doFuture**.  The choice between **foreach** with **doFuture**, **future.apply**, and **furrr** is a matter of preference of coding style - they all rely on futures for parallelization._




<div style="width: 100%; margin-bottom: 3ex;">
<center>
<img src="figures/downloads_over_time_on_CRAN.png" alt="Download ranks on CRAN (four-week averages)" style="width: 58%;"/>
</center>
<em>Figure 1: The download percentile ranks for <strong>future</strong>, <strong>future.apply</strong>, <strong>furrr</strong>, and <strong>foreach</strong> average every four weeks.  The data is based on the RStudio CRAN mirror logs.</em>
</div>

<div style="width: 100%; margin-bottom: 3ex;">
<center>
<img src="figures/revdep_over_time_on_CRAN.png" alt="Reverse dependencies on CRAN over time for core future packages" style="width:50%"/><img src="figures/revdep_over_time_on_CRAN-log.png" alt="Reverse dependencies on CRAN over time for core future packages" style="width:50%"/>
</center> 
<em>Figure 2: Number of CRAN packages that depend on <strong>future</strong>, <strong>future.apply</strong>, <strong>furrr</strong>, and <strong>foreach</strong> over time since the first release of <strong>future</strong> in June 2015.  Left: The package counts on the linear scale without <strong>foreach</strong>.  Right: The same data on the logarithmic scale to fit also <strong>foreach</strong>.  (Because historical data for reverse dependencies on Bioconductor are hard to track down, they are currently not reported in this graph.)</em>
</div>

