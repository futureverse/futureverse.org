SHELL=bash

FILES ?= about.Rmd backends.Rmd blog.Rmd index.Rmd packages-overview.Rmd publications.Rmd roadmap.Rmd talks.Rmd usage.Rmd quality.Rmd tutorials.Rmd

PACKAGES ?= BiocParallel.FutureParam doFuture future future.apply future.batchtools future.callr future.mirai future.mapreduce future.tests future.tools futureverse globals listenv marshal parallelly progressr

DOMAIN ?= futureverse.org


all: spell build

spell:
	hunspell -H $(FILES)

build:
	Rscript -e R.rsp::rfile blog.Rmd.rsp --postprocess=FALSE
	module load pandoc; \
	Rscript -e "rmarkdown::render_site()"

view:
	xdg-open docs/index.html


stats: stats-revdep-over-time stats-downloads

stats-revdep-over-time:
	R_PROGRESSR_ENABLE=true Rscript R/revdep_over_time.R

stats-downloads:
	R_PROGRESSR_ENABLE=true Rscript R/cran_stats.R

stats-revdep:
	R_PROGRESSR_ENABLE=true Rscript R/revdep.R

images/favicon.ico: images/logo.png
	cd $(<D); \
	convert $(<F) -resize 256x256 -transparent white favicon-256.png; \
	convert favicon-256.png -resize   16x16 favicon-16.png;  \
	convert favicon-256.png -resize   32x32 favicon-32.png;  \
	convert favicon-256.png -resize   64x64 favicon-64.png;  \
	convert favicon-256.png -resize 128x128 favicon-128.png; \
	convert favicon-16.png favicon-32.png favicon-64.png favicon-128.png favicon-256.png -colors 256 $(@F)

## INSTRUCTIONS:
## 1. Download first slide of Google Slides 'futureverse.org-site_preview_text' as a PNG (https://docs.google.com/presentation/d/1IE6--kN7ZrLutcroxvUrtu-2Fnr139iELN6R6fbwkeE/edit#slide=id.p)
## 2. Move file to images/
## 3. Call 'make site_preview'
site_preview: images/site_preview.png

images/site_preview.png: images/logo.png images/futureverse.org-site_preview_text.png
	tf1=$$(mktemp --suffix=.png); \
	tf2=$$(mktemp --suffix=.png); \
	tf3=$$(mktemp --suffix=.png); \
	convert "$(word 2,$^)" -trim "$$tf1"; \
	h=$$(identify -format "%[fx:h]" "$$tf1") ;\
	convert "$<" -trim -resize "x$${h}" "$$tf2"; \
	montage "$$tf2" "$$tf1" -tile 2x1 -geometry +30+30 "$$tf3"; \
	montage "$$tf3" -geometry 1200x628 "$$tf1"; \
	mv "$$tf1" "$@"; \
	rm "$$tf2" "$$tf3"


docsearch: .docsearch/futureverse.json

.docsearch/futureverse.json: .docsearch/futureverse.json.rsp
	cd "$(@D)"; \
	Rscript -e R.rsp::rfile "$(<F)"

pkgdown-refresh:
	@source ~/.bashrc.d/interactive=true/git-rpkgs.sh; \
	for pkg in $(PACKAGES); do \
	    echo "Package $$pkg:"; \
	    (cd "../$${pkg}"; pkgdown_refresh); \
	done

pkgdown-build: pkgdown-ymlrsp
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
	    (cd "../$${pkg}"; echo "$$pkg.$(DOMAIN)" > docs/CNAME) \
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
	    mkdir -p "../$$pkg/pkgdown"; \
            cp "$<" "../$$pkg/pkgdown/_pkgdown.yml.rsp"; \
	done
