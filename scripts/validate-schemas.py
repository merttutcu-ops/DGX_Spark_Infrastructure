#!/usr/bin/env python3
"""Validate config files against their JSON Schemas. Called by `just validate`."""
import json
import sys

import jsonschema
import yaml

errors = []

try:
    oc = json.load(open("config/openclaw.json"))
    jsonschema.validate(oc, json.load(open("config/openclaw.schema.json")))
    print("  openclaw.json validates against schema: OK")
except Exception as exc:
    errors.append(f"  openclaw.json FAILED: {exc}")

try:
    p = yaml.safe_load(open("config/openshell-policy.yaml"))
    jsonschema.validate(p, json.load(open("config/openshell-policy.schema.json")))
    print("  openshell-policy.yaml validates against schema: OK")
except Exception as exc:
    errors.append(f"  openshell-policy.yaml FAILED: {exc}")

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
