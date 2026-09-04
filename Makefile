# see https://makefiletutorial.com/

SHELL := /bin/bash -eu -o pipefail

# ---------------------------------------------------------------------------
# Required environment variables for BDD test targets (run_cat_bdd_*).
# Source env.sh before running:  source env.sh
# ---------------------------------------------------------------------------
REQUIRED_BDD_VARS := CAT_FC_HOST CAT_KEYCLOAK_URL CAT_KEYCLOAK_CLIENT_ID CAT_KEYCLOAK_CLIENT_SECRET CAT_KEYCLOAK_REALM CAT_TEST_USER CAT_TEST_PASSWORD

define check_bdd_env
$(foreach var,$(REQUIRED_BDD_VARS),\
  $(if $($(var)),,$(error $(var) is not set. On local dev stage: run `source env.sh` (see env.sample.sh) or set these manually in your environment.)))
endef

PYTHON_3 ?= python3
PYTHON_D ?= $(HOME)/.python.d
SOURCE_PATHS := "src"

VENV_PATH_DEV := $(PYTHON_D)/dev/eclipse/xfsc/dev-ops/testing/bdd-executor/cat
VENV_PATH_PROD := $(PYTHON_D)/prod/eclipse/xfsc/dev-ops/testing/bdd-executor/cat

# Path to bdd-executor repository root (set via env.sh or override here)
# Default: ../.. (assumes cat-integration-tests is in bdd-executor/implementations/)
EU_XFSC_BDD_CORE_PATH ?= ../..

setup_dev: $(VENV_PATH_DEV)
	mkdir -p .tmp/

$(VENV_PATH_DEV):
	$(PYTHON_3) -m venv $(VENV_PATH_DEV)
	"$(VENV_PATH_DEV)/bin/pip" install -U pip wheel
	cd "$(EU_XFSC_BDD_CORE_PATH)" && "$(VENV_PATH_DEV)/bin/pip" install -e ".[dev]"
	"$(VENV_PATH_DEV)/bin/pip" install -e ".[dev]"
	"$(VENV_PATH_DEV)/bin/pip" freeze > requirements.txt

setup_prod: $(VENV_PATH_PROD)

$(VENV_PATH_PROD):
	$(PYTHON_3) -m venv $(VENV_PATH_PROD)
	"$(VENV_PATH_PROD)/bin/pip" install -U pip wheel
	cd "$(EU_XFSC_BDD_CORE_PATH)" && "$(VENV_PATH_PROD)/bin/pip" install "."
	"$(VENV_PATH_PROD)/bin/pip" install .

isort: setup_dev
	"$(VENV_PATH_DEV)/bin/isort" $(SOURCE_PATHS) tests

pylint: setup_dev
	"$(VENV_PATH_DEV)/bin/pylint" $${ARG_PYLINT_JUNIT:-} $(SOURCE_PATHS) tests

coverage_run: setup_dev
	"$(VENV_PATH_DEV)/bin/coverage" run -m pytest $${ARG_COVERAGE_PYTEST:-} -m "not integration" tests/ src/

coverage_report: setup_dev
	"$(VENV_PATH_DEV)/bin/coverage" report

mypy: setup_dev
	"$(VENV_PATH_DEV)/bin/mypy" $${ARG_MYPY_SOURCE_XML:-} -p eu.xfsc.bdd.cat
	"$(VENV_PATH_DEV)/bin/mypy" $${ARG_MYPY_STEPS_XML:-} steps/ --disable-error-code=misc

code_check: \
	setup_dev \
	isort \
	pylint \
	coverage_run coverage_report \
	mypy

# --- Config-aware BDD targets ---
# MODE selects which server profile the tests run against.
# Usage:
#   make run_cat_bdd_dev MODE=default   # excludes @cfg.strict
#   make run_cat_bdd_dev MODE=strict    # excludes @cfg.default
#   make run_cat_bdd_dev                # default mode
#
# See docs/adr/003-interim-two-config-test-strategy.md

MODE ?= default

# v1 tag syntax: comma = OR, multiple --tags = AND.
# Each negation must be a separate --tags flag for AND semantics.
BEHAVE_TAGS_default := --tags='-@wip' --tags='-@cfg.strict'
BEHAVE_TAGS_strict  := --tags='-@wip' --tags='-@cfg.default'
BEHAVE_TAG_FILTER   := $(BEHAVE_TAGS_$(MODE))
ifeq ($(BEHAVE_TAG_FILTER),)
  $(error Unknown MODE "$(MODE)". Use MODE=default or MODE=strict)
endif

run_cat_bdd_dev: setup_dev
	$(call check_bdd_env)
	source "$(VENV_PATH_DEV)/bin/activate" && \
		"$(VENV_PATH_DEV)/bin/coverage" run -m behave $(BEHAVE_TAG_FILTER) $${ARG_BDD_JUNIT:-}

run_cat_bdd_dev_html: setup_dev
	$(call check_bdd_env)
	mkdir -p .tmp/behave
	source "$(VENV_PATH_DEV)/bin/activate" && \
		"$(VENV_PATH_DEV)/bin/coverage" run -m behave $(BEHAVE_TAG_FILTER) -f html -o .tmp/behave/behave-report.html

run_cat_bdd_prod: setup_prod
	$(call check_bdd_env)
	source "$(VENV_PATH_PROD)/bin/activate" && behave $(BEHAVE_TAG_FILTER) features/

run_all_test_coverage: coverage_run run_cat_bdd_dev coverage_report

clean_dev:
	rm -rfv "$(VENV_PATH_DEV)"

clean_prod:
	rm -rfv "$(VENV_PATH_PROD)"

activate_env_prod: setup_prod
	@echo "source \"$(VENV_PATH_PROD)/bin/activate\""

activate_env_dev: setup_dev
	@echo "source \"$(VENV_PATH_DEV)/bin/activate\""

licensecheck: setup_dev
	"$(VENV_PATH_DEV)/bin/pip" freeze > ".tmp/requirements.txt"
	cd .tmp/ && "$(VENV_PATH_DEV)/bin/licensecheck" -u requirements > THIRD-PARTY.txt

# --- JWT Fixture Signing (dev-only, rare) ---
# Signs Loire/VC2 JSON-LD payloads as JWT fixtures using Ed25519/EdDSA.
# Prerequisites: pip install PyJWT[crypto] cryptography
#
# Usage:
#   make sign-jwt-fixtures                    # re-sign all Loire fixtures
#   make sign-jwt-fixtures KEY=keys/jwt.pem   # use existing key
#
# See scripts/generate-jwt-fixture.py --help for all options.
# After generating a new key, update the DID document (see script output).

JWT_SIGNER := python3 scripts/generate-jwt-fixture.py
JWT_KEY_ARG := $(if $(KEY),--key $(KEY),)

sign-jwt-fixtures:
	@echo "Signing standalone Loire VC fixtures..."
	@for f in $$(find fixtures/loire/valid -name '*.jsonld' ! -name '*-vp*' ! -name '*.vp2*'); do \
		echo "  $$f"; \
		$(JWT_SIGNER) $(JWT_KEY_ARG) --payload "$$f"; \
	done
	@echo "Signing Loire VP fixtures (with embedded VC)..."
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/loire/valid/participant-vp.loire.jsonld \
		--embed-vc fixtures/loire/valid/participant.loire.jsonld
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/loire/valid/participant.vp2.jwt.jsonld \
		--embed-vc fixtures/loire/valid/participant.vc2.jsonld \
		--out fixtures/loire/valid/participant.vp2.signed.jwt
	@echo "Signing Enveloped fixtures..."
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/loire/valid/participant.loire.jsonld \
		--wrap-as evc --out fixtures/enveloped/valid/participant.evc.jsonld
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/loire/valid/participant-vp.loire.jsonld \
		--embed-vc fixtures/loire/valid/participant.loire.jsonld \
		--wrap-as evp --out fixtures/enveloped/valid/participant.evp.jsonld
	@echo "Signing vc20/invalid negative fixtures..."
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/vc20/invalid/participant-expired.vc2.jwt.jsonld \
		--out fixtures/vc20/invalid/participant-expired.vc2.jwt
	$(JWT_SIGNER) $(JWT_KEY_ARG) --payload fixtures/vc20/invalid/vp-iss-holder-mismatch.jwt.jsonld \
		--embed-vc fixtures/loire/valid/participant.vc2.jsonld \
		--out fixtures/vc20/invalid/vp-iss-holder-mismatch.jwt
	@echo "Done."
	@echo "NOTE: fixtures/mock-attestation.jwt and fixtures/loire/valid/participant.vc2.jwt"
	@echo "      are NOT signed by this target — they are alg:none / dummy-signature stubs"
	@echo "      used for signature-skip scenarios, not real Ed25519 fixtures."
