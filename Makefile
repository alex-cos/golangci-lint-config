GO             := go
GOLINT         := golangci-lint
MAINMODULE     := mymodule
GOOS           := $(shell go env GOOS)
GIT_TAG_NAME   ?= $(shell git describe --abbrev=1 --tags 2>/dev/null || git describe --always)
SHORT_TAG_NAME ?= $(shell git describe --abbrev=0 --tags 2>/dev/null | sed -rn 's/(v)?([0-9]+(.[0-9]+){2}).*/\2/p')
BRANCH_NAME    ?= $(shell git rev-parse --abbrev-ref HEAD)
BUILDDATE      ?= $(shell date '+%Y-%m-%d')
TARGET_DIR     ?= ./bin
TEST_TIMEOUT   ?= 900s
BUILD_VERSION  ?= 0.0.0
BINARY_EXT     := ""

ifeq ($(BUILD_VERSION), 0.0.0)
	ifneq ($(SHORT_TAG_NAME),)
		BUILD_VERSION = $(SHORT_TAG_NAME)
	else 
	  BUILD_VERSION = 1.0.0
	endif
endif

ifeq ($(GOOS),windows)
	BINARY_EXT = ".exe"
endif

LDFLAGS := -s \
					 -w \
					 -X main.version=$(BUILD_VERSION) \
					 -X main.buildDate=$(BUILDDATE)
VENDOR := vendor/modules.txt

default: build

.PHONY: clean
clean:
	$(GO) clean -i ./...
	rm -rf vendor 2>/dev/null
	rm -f $(TARGET_DIR)/*$(BINARY_EXT) 2>/dev/null

.PHONY: install-tools
install-tools:
	$(GO) install golang.org/x/tools/cmd/godoc@latest
	$(GO) install github.com/go-delve/delve/cmd/dlv@latest
	$(GO) install github.com/go-critic/go-critic/cmd/gocritic@latest
	$(GO) install golang.org/x/tools/cmd/deadcode@latest
	$(GO) install github.com/chmouel/go-better-html-coverage@latest
	curl -sSfL https://golangci-lint.run/install.sh | \
		sh -s -- -b $$(go env GOPATH)/bin latest

$(VENDOR):
	$(GO) mod vendor

.PHONY: build
build: $(VENDOR)
	echo "Building ..."; \
	$(GO) build -ldflags '$(LDFLAGS)' -o "$(TARGET_DIR)/$(MAINMODULE)$(BINARY_EXT)" ".";

.PHONY: lint
lint: $(VENDOR)
	mkdir -p ./tmp 2>/dev/null
	$(GOLINT) run \
	  --allow-parallel-runners \
		--output.text.path=stdout \
		--output.checkstyle.path=./tmp/lintreport.xml \
		--output.html.path=./tmp/lintreport.html \
		--show-stats=true \
		./...

.PHONY: test
test: $(VENDOR)
	$(GO) clean -testcache
	$(GO) test \
		-timeout $(TEST_TIMEOUT) \
		./...

.PHONY: test-short
test-short: $(VENDOR)
	$(GO) clean -testcache
	$(GO) test \
		-short \
		-timeout $(TEST_TIMEOUT) \
		./...

.PHONY: test-cover
test-cover: $(VENDOR)
	mkdir -p ./tmp 2>/dev/null
	$(GO) clean -testcache
	$(GO) test \
		-timeout $(TEST_TIMEOUT) \
		-coverprofile ./tmp/coverage.out \
		-covermode=count \
		-json \
		$(MAINMODULE)/... 1>./tmp/report.json
	go-better-html-coverage -n \
		-profile ./tmp/coverage.out \
		-o ./tmp/coverage.html

.PHONY: critic
critic: $(VENDOR)
	gocritic check \
		-enableAll \
		-disable=#experimental,whyNoLint,importShadow \
		./...

.PHONY: deadcode
deadcode: $(VENDOR)
	deadcode -test ./...

.PHONY: print-%
print-%:
	@echo '$($*)'
