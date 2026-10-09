# Settings for builds of the girtsf fork (gf branch). Included by the Makefile.
# Jag version: <version in main.go>-gf.<JAG_GF_BUILD>; CI sets the build number.
JAG_BASE_VERSION := $(shell sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' $(CURDIR)/cmd/jag/main.go)
$(if $(JAG_BASE_VERSION),,$(error could not read version from cmd/jag/main.go))
JAG_GF_BUILD ?= dev
JAG_VERSION ?= $(JAG_BASE_VERSION)-gf.$(JAG_GF_BUILD)
JAG_SDK_VERSION ?= v2.0.0-alpha.199-gf.1
JAG_TOIT_GITHUB_REPO ?= girtsf/toit
JAG_ENVELOPES_GITHUB_REPO ?= girtsf/toit-envelopes
JAG_JAGUAR_GITHUB_REPO ?= girtsf/jaguar
