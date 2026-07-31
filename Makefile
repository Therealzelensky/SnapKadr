.PHONY: app app-beta run run-beta clean keys test acceptance ship-beta

app:
	chmod +x scripts/build_app.sh
	./scripts/build_app.sh

app-beta:
	chmod +x scripts/build_beta_app.sh scripts/build_app.sh scripts/ensure_sparkle_keys.sh
	./scripts/ensure_sparkle_keys.sh
	./scripts/build_beta_app.sh

run: app
	open dist/SnapKadr.app

run-beta: app-beta
	killall SnapKadrBeta 2>/dev/null || true
	open dist/SnapKadrBeta.app

keys:
	chmod +x scripts/ensure_sparkle_keys.sh
	./scripts/ensure_sparkle_keys.sh

test: acceptance

acceptance:
	chmod +x scripts/acceptance_tests.sh
	./scripts/acceptance_tests.sh

ship-beta:
	chmod +x scripts/ship_beta.sh scripts/publish_beta_release.sh scripts/build_beta_app.sh scripts/build_app.sh scripts/ensure_sparkle_keys.sh
	./scripts/ship_beta.sh

clean:
	rm -rf .build dist
	@echo "Cleaned"
