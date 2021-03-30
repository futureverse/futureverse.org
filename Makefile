SHELL=bash

FILES ?= about.Rmd blog.Rmd index.Rmd packages-overview.Rmd publications.Rmd roadmap.Rmd statistics.Rmd talks.Rmd usage.Rmd quality.Rmd

PACKAGES ?= globals listenv parallelly future future.apply future.tests future.callr future.batchtools doFuture progressr

all: spell build

spell:
	hunspell -H $(FILES)

build:
	module load pandoc; \
	Rscript -e "rmarkdown::render_site()"

view:
	xdg-open docs/index.html

images/favicon.ico: images/future.20200115.300dpi.png
	cd images/; \
	convert $< -resize 256x256 -transparent white favicon-256.png; \
	convert favicon-256.png -resize   16x16 favicon-16.png;  \
	convert favicon-256.png -resize   32x32 favicon-32.png;  \
	convert favicon-256.png -resize   64x64 favicon-64.png;  \
	convert favicon-256.png -resize 128x128 favicon-128.png; \
	convert favicon-16.png favicon-32.png favicon-64.png favicon-128.png favicon-256.png -colors 256 $@

pkgdown-build:
	@export R_PROGRESSR_DEMO_DELAY=0; \
	for pkg in $(PACKAGES); do \
	    echo "Package $$pkg:"; \
	    (cd "../$${pkg}"; Rscript -e pkgdown.extras::build_site) \
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
	        cp -R "../future/pkgdown/favicon" "../$$pkg/pkgdown/favicon"; \
	        (cd "../$$pkg"; git add "pkgdown/favicon/"; git commit pkgdown/favicon -m "pkgdown: add favicon"; git push); \
	    fi; \
	done
