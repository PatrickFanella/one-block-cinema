SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help verify fmt lint test ios-build ios-test archive-check docs-check templates-check privacy-check migrations-check backend-check open-pilot-check secrets-check xcode-note

help: ## Show commands
	@awk 'BEGIN {FS = ":.*##"; printf "Commands:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

verify: fmt lint test docs-check templates-check privacy-check migrations-check backend-check open-pilot-check secrets-check xcode-note ## Run all checks

fmt: ## Format files where repo tooling is available
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat --lint ios/OneBlockCinema ios/OneBlockCinemaTests ios/OneBlockCinemaUITests; \
	else \
		echo 'skip fmt: install SwiftFormat to run the configured check'; \
	fi

lint: ## Run lightweight lint checks
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --strict; \
	else \
		echo 'skip lint: install SwiftLint to run the configured check'; \
	fi

test: ## Run deterministic tests available on this host
	@if command -v xcodebuild >/dev/null 2>&1; then \
		$(MAKE) ios-build; \
	else \
		echo 'skip tests: Xcode tests require a macOS runner'; \
	fi

ios-build: ## Compile the app and all test bundles without signing
	@xcodebuild build-for-testing -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

ios-test: ## Execute tests on the first available iPhone simulator
	@scripts/xcode_test.sh

archive-check: ## Create an unsigned archive to validate release packaging
	@xcodebuild archive -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'generic/platform=iOS' -archivePath build/OneBlockCinema.xcarchive CODE_SIGNING_ALLOWED=NO

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
	@test -f docs/legal/PRIVACY_POLICY.md
	@test -f docs/legal/TERMS.md
	@test -f docs/legal/SUPPORT.md
	@test -f docs/legal/RETENTION_SCHEDULE.md
	@test -f docs/legal/APP_STORE_PRIVACY.md

templates-check: ## Validate product template data
	@python3 scripts/validate_templates.py

privacy-check: ## Validate the bundled Apple privacy manifest
	@python3 scripts/check_privacy_manifest.py

migrations-check: ## Validate required tables and RLS coverage
	@python3 scripts/check_migrations.py

backend-check: ## Typecheck and test backend/console workspaces when pnpm is available
	@if command -v pnpm >/dev/null 2>&1; then \
		pnpm check; \
	else \
		echo 'skip backend-check: install pnpm to typecheck TypeScript workspaces'; \
	fi

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
	@if command -v xcodebuild >/dev/null 2>&1; then \
		echo 'iOS test bundles compiled; run make ios-test with a healthy CoreSimulator service to execute them.'; \
	else \
		echo 'iOS/Xcode tests require the macOS CI job; Linux verification covers repository contracts.'; \
	fi
