SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)
MIX ?= /Users/abby/.local/share/mise/shims/mix

.PHONY: setup help deps test credo dialyzer coverage check format clean clean-releases release publish-release setup-hooks setup-db reset-db logs push-and-publish oauth-init test-analytics-fetch test-summary-generate schedule-daily-analytics

help:
	@echo "YouTube Manager Bot"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup           - Set up project (deps.get + install git hooks + setup database)"
	@echo "  make setup-hooks     - Install git hooks for pre-push validation"
	@echo "  make setup-db        - Create and migrate test database (required for testing)"
	@echo "  make reset-db        - Drop and recreate test database (useful for troubleshooting)"
	@echo "  make oauth-init      - Initialize YouTube OAuth 2.0 credentials (one-time setup)"
	@echo "                         Usage: make oauth-init CLIENT_ID=<id> CLIENT_SECRET=<secret>"
	@echo ""
	@echo "Development commands:"
	@echo "  make test            - Run all tests"
	@echo "  make credo           - Run linter"
	@echo "  make dialyzer        - Run static analysis"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make check           - Run all checks (test, credo, dialyzer)"
	@echo "  make format          - Format Elixir code"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Operations (production NATS :4222 - credentials on Air only):"
	@echo "  make logs                      - Tail server log"
	@echo "  make test-analytics-fetch      - Test analytics collection from YouTube (Air bot + :4222 NATS)"
	@echo "  make test-summary-generate     - Test weekly summary generation and PARA write (Air bot + :4222 NATS)"
	@echo "  make schedule-daily-analytics  - Schedule daily analytics via dispatcher (requires dispatcher bot)"
	@echo ""
	@echo "Release commands:"
	@echo "  make release         - Build OTP release locally"
	@echo "  make publish-release - Build, package, and publish to GitHub"
	@echo "  make clean-releases  - Remove old deployed releases, keep 3 latest"
	@echo ""
	@echo "Normal workflow:"
	@echo "  git push             - Fast compile+test validation"
	@echo "  make push-and-publish - Push then publish release asset"
	@echo ""

setup: init deps setup-hooks setup-db
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure .env with your database settings (if needed)"
	@echo "  2. Run: make test"
	@echo "  3. Start developing!"
	@echo ""

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"

setup-db:
	@echo "Setting up test database..."
	@MIX_ENV=test $(MIX) ecto.create || true
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database created and migrations applied"

reset-db:
	@echo "⚠️  Resetting test database (dropping and recreating)..."
	@MIX_ENV=test $(MIX) ecto.drop || true
	@MIX_ENV=test $(MIX) ecto.create
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database reset complete"

oauth-init:
	@if [ -z "$(CLIENT_ID)" ] || [ -z "$(CLIENT_SECRET)" ]; then \
		echo "ERROR: Missing OAuth credentials"; \
		echo ""; \
		echo "Usage: make oauth-init CLIENT_ID=<your_client_id> CLIENT_SECRET=<your_client_secret>"; \
		echo ""; \
		echo "To get credentials:"; \
		echo "  1. Go to https://console.cloud.google.com/apis/credentials"; \
		echo "  2. Create OAuth 2.0 Web Application credentials"; \
		echo "  3. Copy Client ID and Client Secret"; \
		exit 1; \
	fi
	@echo "Starting YouTube OAuth 2.0 initial authorization..."
	@YOUTUBE_OAUTH_CLIENT_ID="$(CLIENT_ID)" YOUTUBE_OAUTH_CLIENT_SECRET="$(CLIENT_SECRET)" $(MIX) oauth_init

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	$(MIX) deps.get

test:
	$(MIX) test

credo:
	$(MIX) credo

dialyzer: deps
	$(MIX) dialyzer

coverage:
	$(MIX) coveralls

check: test credo dialyzer
	@echo "All checks passed!"

format:
	$(MIX) format

clean:
	$(MIX) clean
	rm -rf _build cover

clean-releases:
	@echo "Cleaning old releases..."
	@if [ ! -d "/opt/ergon/releases/youtube_manager_bot/releases" ]; then \
		echo "No deployed releases found (not on Air node or not deployed yet)"; \
		exit 0; \
	fi
	@cd /opt/ergon/releases/youtube_manager_bot/releases && \
		ls -1d youtube_manager_bot-* 2>/dev/null | \
		grep -v '^youtube_manager_bot$$' | \
		sort -V -r | \
		tail -n +4 | \
		while read dir; do \
			echo "Removing $$dir"; \
			rm -rf "$$dir"; \
		done
	@echo "Done. Kept 3 latest releases."

release: test
	@echo "==============================================="
	@echo "Building OTP release"
	@echo "==============================================="
	rm -rf _build/prod
	MIX_ENV=prod $(MIX) compile --force
	MIX_ENV=prod $(MIX) release
	@echo ""
	@echo "✓ Release built successfully"
	@echo "Location: _build/prod/rel/youtube_manager_bot/"
	@echo ""

publish-release: release
	@echo "==============================================="
	@echo "Publishing release to GitHub"
	@echo "==============================================="
	@echo ""

	@set -e; \
	VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	if [ -z "$$VERSION" ]; then \
		echo "Failed to resolve version from mix.exs"; \
		exit 1; \
	fi; \
	TARBALL="youtube_manager_bot-$$VERSION.tar.gz"; \
	echo "Version: $$VERSION"; \
	echo "Creating release tarball..."; \
	cp -r _build/prod/rel/youtube_manager_bot _build/prod/rel/youtube_manager_bot-$$VERSION; \
	tar -czf "$$TARBALL" -C _build/prod/rel youtube_manager_bot-$$VERSION/; \
	rm -rf _build/prod/rel/youtube_manager_bot-$$VERSION; \
	echo "✓ Tarball created: $$TARBALL"; \
	echo ""; \
	echo "Creating GitHub release v$$VERSION..."; \
	if gh release view "v$$VERSION" >/dev/null 2>&1; then \
		gh release upload "v$$VERSION" "$$TARBALL" --clobber; \
	else \
		gh release create "v$$VERSION" "$$TARBALL" \
			--title "Release v$$VERSION" \
			--notes "YouTube Manager Bot Elixir release v$$VERSION. Download and deploy with Jenkins." \
			--draft=false; \
	fi; \
	echo "✓ Release published to GitHub"; \
	echo ""; \
	echo "Next steps:"; \
	echo "1. Jenkins will automatically detect the new release"; \
	echo "2. Trigger deployment in Jenkins UI or wait for auto-deployment"; \
	echo "3. Check deployment status: make jenkins-logs"

push-and-publish:
	@git push && $(MAKE) publish-release

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh

test-analytics-fetch:
	@echo "Testing analytics fetch request (production NATS - credentials on Air only)..."
	@nats request --server nats://localhost:4222 youtube.analytics.fetch '{}' --timeout 10s

test-summary-generate:
	@echo "Testing summary generation and PARA write (production NATS)..."
	@nats request --server nats://localhost:4222 youtube.summary.generate '{}' --timeout 5s

schedule-daily-analytics:
	@echo "Scheduling daily YouTube analytics collection via dispatcher (production NATS)..."
	@nats request --server nats://localhost:4222 dispatcher.schedule.job '{ \
		"job_id": "youtube-daily-analytics", \
		"subject": "youtube.analytics.fetch", \
		"schedule": "0 9 * * *", \
		"timezone": "America/Denver", \
		"payload": {} \
	}' --timeout 5s
