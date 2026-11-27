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

# Format the code (gofmt + gofumpt + gci + golines)
golangci-lint fmt ./...

# Show what the formatters would change without writing anything
golangci-lint fmt --diff ./...
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
- 66 additional linters (71 in total, counting the five from `standard`), mainly: bugs (`bodyclose`, `errorlint`, `nilerr`, `nilnesserr`, `contextcheck`, `containedctx`, `fatcontext`), security (`gosec`, `bidichk`), SQL (`sqlclosecheck`, `rowserrcheck`) and tests (`paralleltest`, `tparallel`, `thelper`, `testifylint`, `usetesting`).
- Standard library usage and modernization: `usestdlibvars` (`http.StatusOK`, `http.MethodGet`, ...), `modernize`, `intrange`, `exptostd`.
- `govet` runs with `enable-all: true`, except `fieldalignment` and `shadow` (too noisy).
- `errcheck` is strict (`check-type-assertions`, `check-blank`) but keeps its built-in exclusion list (`Close`, `Flush`, ...), consistent with the `std-error-handling` preset.
- Some stack-specific linters (`clickhouselint`, `promlinter`, `zerologlint`, `sloglint`, `protogetter`): they stay silent as long as the matching libraries are not used.
- `exhaustive` only checks `switch` statements, on package-scope enums, and a `default` case counts as exhaustive.

### Main thresholds

| Linter | Threshold |
| --- | --- |
| `cyclop` | complexity 25 (package average 10) |
| `gocognit` | complexity 25 |
| `funlen` | 120 lines (statement count disabled) |
| `dupl` | 200 tokens |
| `lll` | 120 characters (tab counted as 1) |
| `golines` (formatter) | 120 characters (tab counted as 1, same as `lll`) |
| `gocyclo`, `nestif` | disabled (covered by `cyclop` and `gocognit`) |

### Exclusions

- Presets: `common-false-positives` and `std-error-handling` only. `comments` and `legacy` are intentionally not used: `revive` is disabled so `comments` has nothing to hide, and `legacy` masks too much.
- Test files: relaxed on `errcheck`, complexity (`cyclop`, `gocognit`, `funlen`), `dupl`, `lll`, `gosec`, `forbidigo`, etc.
- Ignored directories: none (`linters.exclusions.paths: []`); add the paths specific to your project there. `vendor/` is already left out of `./...` when using Go modules.
- Generated files: `lax` mode. This covers generated mocks (`mockgen`, `mockery`, ...) as long as they carry a "Code generated" header; hand-written mocks are linted like any other file.
- `warn-unused: true` on both `linters.exclusions` and `formatters.exclusions`: golangci-lint warns when an exclusion rule or path no longer matches anything, so stale rules do not pile up.

### Severities

`severity.default: warning` (a new linter or formatter that is not classified yet never shows up as a blocker by accident), with the 71 enabled linters spread across three levels:

| Level | Count | Purpose |
| --- | --- | --- |
| `error` | 18 + `staticcheck` (`SA*`) | probable bugs, resource leaks, security, unchecked errors, contexts, SQL |
| `warning` | 32 | code smells: complexity, dead code, test hygiene, API design |
| `info` | 20 + `staticcheck` (`S1*`, `ST*`, `QF*`) | style, naming, modernization |

`staticcheck` is split by check ID using the `text` field of the severity rules: `SA*` checks are bugs (`error`), `S1*` / `ST*` / `QF*` are simplifications and style (`info`).

Severities are only used by output formats that support them (checkstyle, SARIF, code-climate), for example to rank issues once imported into SonarQube. **They do not change the exit code**: any issue still makes `golangci-lint run` fail.
<details>
<summary>Full list</summary>

- **error**: `bodyclose`, `clickhouselint`, `contextcheck`, `durationcheck`, `errcheck`, `errchkjson`, `errorlint`, `fatcontext`, `gosec`, `govet`, `makezero`, `musttag`, `nilerr`, `nilnesserr`, `noctx`, `rowserrcheck`, `sqlclosecheck`, `zerologlint`, and `staticcheck` for `SA*` checks
- **warning**: `asasalint`, `bidichk`, `containedctx`, `copyloopvar`, `cyclop`, `dupl`, `exhaustive`, `exptostd`, `forbidigo`, `funlen`, `gocheckcompilerdirectives`, `gochecknoinits`, `gocognit`, `gocritic`, `ineffassign`, `loggercheck`, `mirror`, `nilnil`, `nonamedreturns`, `nosprintfhostport`, `paralleltest`, `promlinter`, `protogetter`, `reassign`, `sloglint`, `testifylint`, `testpackage`, `tparallel`, `unparam`, `unused`, `usetesting`, `wastedassign`
- **info**: `asciicheck`, `canonicalheader`, `dogsled`, `embeddedstructfieldcheck`, `errname`, `godot`, `godox`, `goprintffuncname`, `iface`, `inamedparam`, `intrange`, `lll`, `modernize`, `perfsprint`, `prealloc`, `predeclared`, `thelper`, `unconvert`, `usestdlibvars`, `whitespace`, and `staticcheck` for `S1*`, `ST*` and `QF*` checks

</details>

### Formatters

Four formatters are enabled:

| Formatter | Settings | Role |
| --- | --- | --- |
| `gofmt` | `simplify: true`, rewrite rules `interface{}` → `any` and `a[b:len(a)]` → `a[b:]` | standard formatting plus simplifications |
| `gofumpt` | `extra-rules: true` | stricter `gofmt` (also groups adjacent parameters of the same type) |
| `gci` | sections `standard`, `default`, `localmodule`, `custom-order: true` | deterministic import grouping: standard library, then third-party, then your own module |
| `golines` | `max-len: 120`, `tab-len: 1` | wraps long lines, aligned with the `lll` linter |

Apply them with `golangci-lint fmt ./...` (or `golangci-lint run --fix ./...`).

Things to know:

- `golines` does not wrap comments or long string literals, so `lll` stays enabled for those.
- `gci` puts imports of your own module (read from `go.mod`) in a separate last group, after the third-party ones.
- `gofumpt` is a superset of `gofmt`: keeping `gofmt` is harmless and is what provides the rewrite rules.

### Intentionally disabled linters

| Linter | Reason |
| --- | --- |
| `wrapcheck`, `err113`, `wsl_v5`, `nlreturn`, `varnamelen` | too strict or too subjective |
| `revive` | largely covered by `staticcheck` |
| `godoclint` | documentation is not enforced |
| `goconst`, `mnd` | noise with no real benefit |
| `decorder`, `importas`, `nakedret`, `nestif` | redundant or ineffective without dedicated configuration |
| `gocyclo` | duplicates `cyclop` (same metric); `cyclop` and `gocognit` are kept |
| `forcetypeassert` | covered by `errcheck` (`check-type-assertions: true`) |
| `arangolint`, `ginkgolinter` | enable only when ArangoDB / Ginkgo are used |

## Runtime behavior

- `run.timeout: 0s`: no internal timeout — configure one on the CI side.
- `run.allow-parallel-runners: true`: allows simultaneous runs (IDE + terminal + CI).
- `issues.max-same-issues: 0`: no limit on duplicate issues (watch the output volume on a large codebase).
- Exit code 1 as soon as at least one issue is reported (`issues-exit-code: 1`), whatever its severity.

## CI integration (GitHub Actions example)

```yaml
- uses: golangci/golangci-lint-action@v8
  with:
    version: v2.13.2
    args: --output.checkstyle.path=report.xml ./...
```

Pin the golangci-lint version in CI: any version older than 2.13 rejects this configuration.

### SonarQube

The checkstyle report carries the `severity` attribute defined in the `severity` section, and can be imported with the Sonar Go analyzer:

```properties
sonar.go.golangci-lint.reportPaths=report.xml
```

How Sonar maps `error` / `warning` / `info` to its own severities is not documented in the official docs: check the result on a first import.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `unknown linters: clickhouselint` | golangci-lint older than 2.12 |
| Useless `//nolint` directives are not reported | `nolintlint` is intentionally disabled |
| Formatting issues reported (`gofmt`, `gofumpt`, `gci`, `golines`) | run `golangci-lint fmt ./...` |
| Long lines still reported by `lll` | comments and string literals are not wrapped by `golines` |
| A directory is not analyzed | it is listed in `linters.exclusions.paths` |
| `t.Setenv` / `t.Chdir` panics with `t.Parallel()` | `usetesting` (`os-setenv`, `os-chdir`) and `paralleltest` cannot both be satisfied in a test that touches the environment: use a targeted `//nolint:paralleltest // reason` |

## Maintenance

- After any change to the file: `golangci-lint config verify`.
- After adding or removing a linter: `golangci-lint linters`, and remember to update the `severity` section (linters not listed there inherit `default: warning`).
- References: [linter list](https://golangci-lint.run/docs/linters/) and [per-linter settings](https://golangci-lint.run/docs/linters/configuration/).
