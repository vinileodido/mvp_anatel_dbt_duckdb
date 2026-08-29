SHELL := /bin/bash

PROJECT_DIR := $(CURDIR)
PYTHON ?= python
DBT ?= dbt
DBT_PROFILES_DIR ?= $(PROJECT_DIR)
DBT_PROJECT_DIR ?= $(PROJECT_DIR)
DUCKDB_FILE ?= warehouse.duckdb
PROFILE_FILE ?= profiles.yml
PROFILE_EXAMPLE ?= profiles.yml.example
COLLECT_SCRIPT ?= scripts/collect_anatel_mvp.py

.DEFAULT_GOAL := help

.PHONY: help install init-profile collect debug run test build docs-generate docs-serve duckdb-shell clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[A-Za-z0-9_.-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install Python dependencies
	$(PYTHON) -m pip install -r requirements.txt

init-profile: ## Create local profiles.yml from the example if missing
	@if [ -f "$(PROFILE_FILE)" ]; then \
		echo "$(PROFILE_FILE) already exists"; \
	else \
		cp "$(PROFILE_EXAMPLE)" "$(PROFILE_FILE)"; \
		echo "Created $(PROFILE_FILE) from $(PROFILE_EXAMPLE)"; \
	fi

collect: ## Download Anatel/IBGE data and load DuckDB raw tables
	$(PYTHON) $(COLLECT_SCRIPT)

debug: ## Validate dbt profile and connection
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) debug --project-dir $(DBT_PROJECT_DIR)

run: collect ## Build models
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) run --project-dir $(DBT_PROJECT_DIR)

test: collect ## Run data tests
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) test --project-dir $(DBT_PROJECT_DIR)

build: collect ## Collect raw data, then build models and tests
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) build --project-dir $(DBT_PROJECT_DIR)

docs-generate: ## Generate dbt docs artifacts
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) docs generate --project-dir $(DBT_PROJECT_DIR)

docs-serve: ## Serve dbt docs locally
	DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) docs serve --project-dir $(DBT_PROJECT_DIR)

duckdb-shell: ## Open the DuckDB shell
	duckdb $(DUCKDB_FILE)

clean: ## Remove generated artifacts
	rm -rf target logs dbt_packages data $(DUCKDB_FILE) $(PROFILE_FILE) .user.yml
