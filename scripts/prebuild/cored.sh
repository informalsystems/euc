#!/bin/sh
# Coreum wants their own build kit: https://github.com/CoreumFoundation/coreum/pull/454 .
# So we improvise.

set -eu

test ! -f "${REPO}/Makefile" || cat <<EOF > "${REPO}/Makefile"
BRANCH := \$(shell git rev-parse --abbrev-ref HEAD)
COMMIT := \$(shell git log -1 --format='%H')
VERSION := \$(shell git describe --tags)
TM_VERSION := \$(shell go list -m github.com/tendermint/tendermint | sed 's:.* ::') # grab everything after the space in "github.com/tendermint/tendermint v0.34.7"
BUILDDIR ?= \$(CURDIR)/build

export GO111MODULE = on

build_tags = netgo
build_tags += ledger

build_tags += \$(BUILD_TAGS)
build_tags := \$(strip \$(build_tags))

whitespace :=
whitespace += \$(whitespace)
comma := ,
build_tags_comma_sep := \$(subst \$(whitespace),\$(comma),\$(build_tags))

# process linker flags
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=coreum \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=cored \
		  -X github.com/cosmos/cosmos-sdk/version.Version=\$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=\$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=\$(build_tags_comma_sep)" \
			-X github.com/tendermint/tendermint/version.TMCoreSemVer=\$(TM_VERSION)

ldflags += \$(LDFLAGS)
ldflags := \$(strip \$(ldflags))

BUILD_FLAGS := -tags "\$(build_tags)" -ldflags '\$(ldflags)'

BUILD_TARGETS := build install

build: BUILD_ARGS=-o \$(BUILDDIR)/

\$(BUILD_TARGETS): go.sum \$(BUILDDIR)/
	go \$@ -mod=readonly \$(BUILD_FLAGS) \$(BUILD_ARGS) ./...

\$(BUILDDIR)/:
	mkdir -p \$(BUILDDIR)/
EOF
