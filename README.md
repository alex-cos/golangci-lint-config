# golangci-lint-config

[![Go Version](https://img.shields.io/badge/go-1.24-blue)](https://go.dev)
[![golangci-lint](https://img.shields.io/badge/golangci%20lint-2.13-blue)](https://golangci-lint.run)

Shared [golangci-lint](https://golangci-lint.run/) v2 configuration.

The goal: a strict baseline for code correctness (unchecked errors, contexts, security, concurrency, SQL/HTTP) while staying deliberately tolerant of subjective style rules.

## Requirements

- **golangci-lint ≥ 2.13** — the config uses `exhaustruct_v5` (added in 2.13) and `clickhouselint` (2.12+).
- A recent Go toolchain: `usetesting` (`context-background` / `context-todo`) and some `modernize` analyzers require Go ≥ 1.24.

Check the installed version:

```bash
golangci-lint --version
```

## Installation

Copy `.golangci.yml` to the root of the Go repository (next to `go.mod`):

```bash
cp .golangci.yml /path/to/my-project/.golangci.yml
```

golangci-lint automatically discovers `.golangci.yml` / `.golangci.yaml` by walking up from the analyzed directory. For a multi-module monorepo, keep the file at the root and run the tool module by module (`relative-path-mode: gomod` resolves paths against `go.mod`).

## Usage

```bash
# Analysis
golangci-lint run ./...

# Analysis + automatic fixes (formatters and autofix linters)
golangci-lint run --fix ./...

# Checkstyle output (uses the severities defined in the config)
golangci-lint run --output.checkstyle.path=report.xml ./...

# SARIF output (GitHub code scanning)
golangci-lint run --output.sarif.path=report.sarif ./...
```

Verify the configuration itself:

```bash
golangci-lint config verify          # validates the schema and linter names
golangci-lint config path            # the file actually used
golangci-lint linters                # linters enabled / disabled by this config
```

## What the configuration contains

### Linters

- Base: `linters.default: standard` (`errcheck`, `govet`, `ineffassign`, `staticcheck`, `unused`).
- ~65 additional linters (71 in total), mainly: bugs (`bodyclose`, `errorlint`, `nilerr`, `nilnesserr`, `contextcheck`, `containedctx`, `fatcontext`), security (`gosec`, `bidichk`), SQL (`sqlclosecheck`, `rowserrcheck`) and tests (`paralleltest`, `tparallel`, `thelper`, `testifylint`, `usetesting`).
- Some stack-specific linters (`clickhouselint`, `promlinter`, `zerologlint`, `sloglint`, `protogetter`): they stay silent as long as the matching libraries are not used.
- `exhaustive` only checks `switch` statements, on package-scope enums, and a `default` case counts as exhaustive.

### Main thresholds

| Linter | Threshold |
| --- | --- |
| `cyclop` / `gocyclo` | complexity 25 |
| `gocognit` | complexity 25 |
| `funlen` | 120 lines (statement count disabled) |
| `dupl` | 200 tokens |
| `lll` | 120 characters |
| `nestif` | disabled (covered by `gocognit`) |

### Exclusions

- Presets: `comments`, `common-false-positives`, `legacy`, `std-error-handling`.
- Test files: relaxed on `errcheck`, complexity, `dupl`, `lll`, `gosec`, `forbidigo`, etc.
- `*mock.go` files: `dupl`, `errcheck`, complexity, `gosec`.
- Ignored directories: `vendor/`, `services/`, `tmp/` (adapt to your project).
- Generated files: `lax` mode.

### Severities

`severity.default: error`, with 71 linters spread across three levels:

| Level | Count | Purpose |
| --- | --- | --- |
| `error` | 14 | proven bugs, security, contexts, SQL |
| `warning` | 17 | quality, unchecked errors, dead code, tests |
| `info` | 40 | style, naming, modernization |

Severities are only used by output formats that support them (checkstyle, SARIF, code-climate). **They do not change the exit code**: any issue still makes `golangci-lint run` fail.

<details>
<summary>Full list</summary>

- **error**: `clickhouselint`, `containedctx`, `contextcheck`, `copyloopvar`, `cyclop`, `forbidigo`, `gocritic`, `gosec`, `govet`, `mirror`, `noctx`, `rowserrcheck`, `sqlclosecheck`, `zerologlint`
- **warning**: `bidichk`, `bodyclose`, `errcheck`, `errchkjson`, `fatcontext`, `funlen`, `gocheckcompilerdirectives`, `gocognit`, `gocyclo`, `ineffassign`, `nosprintfhostport`, `paralleltest`, `reassign`, `sloglint`, `tparallel`, `unused`, `usetesting`
- **info**: `asasalint`, `asciicheck`, `canonicalheader`, `dogsled`, `dupl`, `durationcheck`, `embeddedstructfieldcheck`, `errname`, `errorlint`, `exhaustive`, `exptostd`, `gochecknoinits`, `godot`, `godox`, `goprintffuncname`, `iface`, `inamedparam`, `intrange`, `lll`, `loggercheck`, `makezero`, `modernize`, `musttag`, `nilerr`, `nilnesserr`, `nilnil`, `nonamedreturns`, `perfsprint`, `prealloc`, `predeclared`, `promlinter`, `protogetter`, `staticcheck`, `testifylint`, `testpackage`, `thelper`, `unconvert`, `unparam`, `wastedassign`, `whitespace`

</details>

### Formatters

No formatter is enabled (`formatters.enable: []`): formatting must be handled elsewhere (IDE, pre-commit, `gofmt`). To integrate it into golangci-lint:

```yaml
formatters:
  enable:
    - gofumpt
    - goimports
```

then `golangci-lint fmt`.

### Intentionally disabled linters

| Linter | Reason |
| --- | --- |
| `wrapcheck`, `err113`, `wsl_v5`, `nlreturn`, `varnamelen` | too strict or too subjective |
| `revive` | largely covered by `staticcheck` |
| `godoclint` | documentation is not enforced |
| `goconst`, `mnd` | noise with no real benefit |
| `decorder`, `importas`, `nakedret`, `nestif` | redundant or ineffective without dedicated configuration |
| `forcetypeassert` | covered by `errcheck` (`check-type-assertions: true`) |
| `arangolint`, `ginkgolinter` | enable only when ArangoDB / Ginkgo are used |

## Runtime behavior

- `run.timeout: 0s`: no internal timeout — configure one on the CI side.
- `run.allow-parallel-runners: true`: allows simultaneous runs (IDE + terminal + CI).
- `issues.max-same-issues: 0`: no limit on duplicate issues (watch the output volume on a large codebase).
- Fails on the first issue (`issues-exit-code: 1`).

## CI integration (GitHub Actions example)

```yaml
- uses: golangci/golangci-lint-action@v8
  with:
    version: v2.13.2
    args: --output.checkstyle.path=report.xml ./...
```

Pin the golangci-lint version in CI: any version older than 2.13 rejects this configuration.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `unknown linters: clickhouselint` | golangci-lint older than 2.12 |
| Useless `//nolint` directives are not reported | `nolintlint` is intentionally disabled |
| No formatting issue is reported | no formatter enabled (see above) |
| A directory is not analyzed | it is listed in `linters.exclusions.paths` |
| Duplicate issues on the same function | both `gocyclo` and `cyclop` are enabled |

## Maintenance

- After any change to the file: `golangci-lint config verify`.
- After adding or removing a linter: `golangci-lint linters`, and remember to update the `severity` section (linters not listed there inherit `default: error`).
- References: [linter list](https://golangci-lint.run/docs/linters/) and [per-linter settings](https://golangci-lint.run/docs/linters/configuration/).
