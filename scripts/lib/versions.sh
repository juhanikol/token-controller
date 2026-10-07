#!/usr/bin/env bash

# Versions and JSON schema numbers, in one place. Sourced by workflow.sh, doctor.sh, and wx.sh.
# Plain variables (not readonly), so sourcing the file again is safe.
#
# Compatibility rule for JSON output (status --json, modes --json, doctor --json, report --json, version --json,
# the session.jsonl records) and for config/workflow_settings.json:
#   * Adding a field does not change the schema number. A consumer must ignore fields it does not know.
#   * Renaming or removing a field, or changing its type or meaning, bumps that schema number.
#   * A consumer checks the schema number it needs and refuses any other number.
#   * AIW_CLI_VERSION is for people and logs. It is changed by hand. It is not used to decide compatibility.

AIW_CLI_VERSION="0.1.0"
AIW_VERSION_SCHEMA_VERSION=1
AIW_STATUS_SCHEMA_VERSION=1
AIW_MODES_SCHEMA_VERSION=1
AIW_DOCTOR_SCHEMA_VERSION=1
AIW_REPORT_SCHEMA_VERSION=1
AIW_SESSION_SCHEMA_VERSION=2
