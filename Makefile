SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help verify fmt lint test docs-check open-pilot-check secrets-check xcode-note

help: ## Show commands
	@awk 'BEGIN {FS = ":.*##"; printf "Commands:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

verify: fmt lint test docs-check open-pilot-check secrets-check xcode-note ## Run all checks

fmt: ## Format files where repo tooling is available
	@echo 'skip fmt: no Swift formatter configured yet'

lint: ## Run lightweight lint checks
	@echo 'skip lint: no Swift linter configured yet'

test: ## Run deterministic tests available on this host
	@echo 'skip tests: Xcode tests require macOS runner'

docs-check: ## Verify required docs exist
	@test -f README.md
	@test -f AGENTS.md
	@test -f CONTRIBUTING.md
	@test -f SECURITY.md
	@test -f LICENSE
	@test -f docs/product/PRD.md
	@test -f docs/product/MVP_SCOPE.md
	@test -f docs/technical/API_SPEC.md
	@test -f docs/codebase/STACK.md

open-pilot-check: ## Verify Open Pilot templates exist
	@test -f .gitea/ISSUE_TEMPLATE/open-pilot-task.yaml
	@grep -q 'Test Command' .gitea/ISSUE_TEMPLATE/open-pilot-task.yaml
	@test -f .gitea/PULL_REQUEST_TEMPLATE.md

secrets-check: ## Check for common committed secret filenames
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		! git ls-files | grep -E '(^|/)(\.env|.*\.pem|.*\.key|.*\.p12|.*\.pfx|id_rsa|id_ed25519)$$'; \
	else \
		echo 'skip secrets-check: not a git repository yet'; \
	fi

xcode-note: ## Explain iOS verification status on non-macOS runners
	@echo 'iOS/Xcode tests are not part of Linux make verify yet; add xcodebuild checks when macOS runner is available.'
