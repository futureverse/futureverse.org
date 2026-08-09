## The parallel ecosystems ("families") and their colours, shared by the
## dependency graphs (R/parallel_families_over_time.R) and the download
## graphs (R/parallel_families_downloads_over_time.R).
##
## The families, bottom-up in roughly the order they arrived on CRAN
##
## 'foreach' and 'doRNG' are left out: neither parallelizes on its own, it is
## the do*() backends that do.  'nanonext' is a transport layer, and
## 'RhpcBLASctl'/'OpenMPController' control thread counts rather than provide
## parallelism.
## ---------------------------------------------------------------------
family <- c(
  snow             = "snow era",
  snowfall         = "snow era",
  Rmpi             = "snow era",
  multicore        = "snow era",
  nws              = "snow era",

  parallel         = "parallel (base R)",

  doParallel       = "foreach backends",
  doMC             = "foreach backends",
  doSNOW           = "foreach backends",
  doMPI            = "foreach backends",
  doRedis          = "foreach backends",
  doAzureParallel  = "foreach backends",

  batchtools       = "HPC schedulers",
  BatchJobs        = "HPC schedulers",
  clustermq        = "HPC schedulers",
  rslurm           = "HPC schedulers",
  batch            = "HPC schedulers",
  parallelMap      = "HPC schedulers",

  RcppParallel     = "C++ threading",
  RcppThread       = "C++ threading",

  mirai            = "mirai",
  crew             = "mirai",
  crew.cluster     = "mirai",

  future             = "Futureverse",
  future.apply       = "Futureverse",
  furrr              = "Futureverse",
  doFuture           = "Futureverse",
  parallelly         = "Futureverse",
  future.batchtools  = "Futureverse",
  future.callr       = "Futureverse",
  future.mirai       = "Futureverse",
  future.mapreduce   = "Futureverse",
  futureverse        = "Futureverse"
)

## doFuture and future.batchtools bridge two worlds; they are counted as
## Futureverse, since that is the API the author programs against.

families <- c("snow era", "parallel (base R)", "foreach backends",
              "HPC schedulers", "C++ threading", "mirai", "Futureverse")

## Seven hues, validated for colour-vision deficiency on the pairs that touch
## in the stack: worst adjacent CVD dE 16.2, normal-vision dE 22.9 (OKLab
## x100, light surface).  Three of them are held at the colour their leading
## package carries in the per-package figure - parallel amber, foreach green,
## Futureverse red - so the figures can be read together.
colors <- c(
  "snow era"          = "#2A78D6",
  "parallel (base R)" = "#EDA100",
  "foreach backends"  = "#008300",
  "HPC schedulers"    = "#5B8DEF",
  "C++ threading"     = "#1BAF7A",
  "mirai"             = "#4A3AA7",
  "Futureverse"       = "#E34948",
  "no dependency"     = "#E7E5E0"
)

## Multi-threading is excluded from the ecosystem figures: these present the
## multi-process parallelization ecosystems, where one R process farms work
## out to others.  RcppParallel/RcppThread run threads inside a single
## process, which is a different thing being measured, and 'LinkingTo' cannot
## be optional, so they also behave differently under the hard/soft split.
## The paradigms figures (R/parallel_paradigms_over_time.R) are where the two
## are compared; set this to character(0) to fold threading back in here.
exclude_families <- "C++ threading"

family   <- family[!family %in% exclude_families]
families <- setdiff(families, exclude_families)

surface <- "#FCFCFB"
image_dims <- c(10.0, 6.0)
