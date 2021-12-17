# Makefile for building CoreDNS
GITCOMMIT:=$(shell git describe --dirty --always)
BINARY:=coredns
SYSTEM:=
CHECKS:=check
BUILDOPTS:=-v
GOPATH?=$(HOME)/go
MAKEPWD:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
CGO_ENABLED?=0

IMAGE_NAME ?= ghcr.io/infonova/coredns
TEST_IMAGE = ${IMAGE_NAME}:${GITCOMMIT}
RELEASE_IMAGE = ${IMAGE_NAME}:$(subst refs/tags/,,${GITHUB_REF})

.PHONY: all
all: coredns

.PHONY: coredns
coredns: $(CHECKS)
	CGO_ENABLED=$(CGO_ENABLED) $(SYSTEM) go build $(BUILDOPTS) -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=$(GITCOMMIT)" -o $(BINARY)

.PHONY: check
check: core/plugin/zplugin.go core/dnsserver/zdirectives.go

core/plugin/zplugin.go core/dnsserver/zdirectives.go: plugin.cfg
	go generate coredns.go
	go get

.PHONY: gen
gen:
	go generate coredns.go
	go get

.PHONY: pb
pb:
	$(MAKE) -C pb

.PHONY: clean
clean:
	go clean
	rm -f coredns

.PHONY: build-image
build-image: SYSTEM := GOOS=linux
build-image: coredns
	docker build -t ${TEST_IMAGE} .

.PHONY: push-image
push-image:
	docker push ${TEST_IMAGE}

.PHONY: pull-image
pull-image:
	while true; do \
		docker pull ${TEST_IMAGE} || continue; \
		break; \
	done

.PHONY: promote-image
promote-image:
ifndef GITHUB_REF
	$(error GITHUB_REF is not set)
endif
	docker tag ${TEST_IMAGE} ${RELEASE_IMAGE}
	docker push ${RELEASE_IMAGE}