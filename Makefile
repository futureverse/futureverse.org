SHELL=bash

FILES ?= about.Rmd blog.Rmd index.Rmd packages-overview.Rmd publications.Rmd roadmap.Rmd statistics.Rmd talks.Rmd usage.Rmd quality.Rmd

PACKAGES ?= BiocParallel.FutureParam doFuture future future.apply future.batchtools future.callr future.tests globals listenv parallelly progressr


all: spell build

spell:
	hunspell -H $(FILES)

build:
	Rscript -e R.rsp::rfile blog.Rmd.rsp --postprocess=FALSE
	module load pandoc; \
	Rscript -e "rmarkdown::render_site()"

view:
	xdg-open docs/index.html


stats: stats-revdeps stats-downloads

stats-revdeps:
	Rscript R/revdep_over_time.R

stats-downloads:
	Rscript R/cran_stats.R

images/favicon.ico: images/logo.png
	cd images/; \
	convert $(<F) -resize 256x256 -transparent white favicon-256.png; \
	convert favicon-256.png -resize   16x16 favicon-16.png;  \
	convert favicon-256.png -resize   32x32 favicon-32.png;  \
	convert favicon-256.png -resize   64x64 favicon-64.png;  \
	convert favicon-256.png -resize 128x128 favicon-128.png; \
	convert favicon-16.png favicon-32.png favicon-64.png favicon-128.png favicon-256.png -colors 256 $(@F)

pkgdown-build:
	@export R_PROGRESSR_DEMO_DELAY=0; \
	for pkg in $(PACKAGES); do \
	    echo "Package $$pkg:"; \
	    (cd "../$${pkg}"; Rscript -e pkgdown.extras::build_site); \
	done

pkgdown-deploy:
	@source ~/.bashrc.d/interactive=true/git-rpkgs.sh; \
	for pkg in $(PACKAGES); do \
	    echo "Package $$pkg:"; \
	    (cd "../$${pkg}"; pkgdown_deploy) \
	done

pkgdown-cname:
	@for pkg in $(PACKAGES); do \
	    printf "Package $$pkg: "; \
	    (cd "../$${pkg}"; cat docs/CNAME) \
	done

pkgdown-favicon:
	@for pkg in $(PACKAGES); do \
	    if [ ! -d "../$$pkg/pkgdown/favicon" ]; then \
	        cp -R ".pkgdown/favicon" "../$$pkg/pkgdown/favicon"; \
	        (cd "../$$pkg"; git add "pkgdown/favicon/"; git commit pkgdown/favicon -m "pkgdown: add favicon"; git push); \
	    fi; \
	done

pkgdown-ymlrsp: .pkgdown/_pkgdown.yml.rsp
	for pkg in $(PACKAGES); do \
            cp "$<" "../$$pkg/pkgdown/_pkgdown.yml.rsp"; \
	done
