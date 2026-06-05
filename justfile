# spark-agent-infra justfile
# Requires: just (https://github.com/casey/just), shellcheck, shfmt, jq, python3+jsonschema+pyyaml

set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes
default:
    @just --list

# Lint all shell scripts with shellcheck and check formatting with shfmt
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> shellcheck"
    shellcheck -x --source-path=scripts scripts/lib/common.sh scripts/*.sh
    echo "==> shfmt -d (diff mode)"
    shfmt -d scripts
    echo "lint: OK"

# Validate JSON files with jq and both configs against their JSON Schemas
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> jq empty (JSON validity)"
    for f in config/*.json; do
        echo "  jq empty: $f"
        jq empty "$f"
    done
    echo "==> schema validation"
    python3 scripts/validate-schemas.py
    echo "validate: OK"

# Auto-format all shell scripts with shfmt (write mode)
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> shfmt -w (write mode)"
    shfmt -w scripts
    echo "fmt: OK"
