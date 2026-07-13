#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${APP_DIR}/config/local.json"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

show_help() {
  cat <<'USAGE'
Usage:
  ./scripts/run_app.sh [flutter run options]
  ./scripts/run_app.sh --config config/local.json [flutter run options]

Examples:
  ./scripts/run_app.sh              Auto-select the first iPhone from flutter devices.
  ./scripts/run_app.sh -d chrome
  ./scripts/run_app.sh -d ios --debug

Environment:
  FLUTTER_BIN=/path/to/flutter  Override flutter executable.
USAGE
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      if [[ $# -lt 2 ]]; then
        echo "error: --config requires a file path" >&2
        exit 64
      fi
      CONFIG_FILE="$2"
      shift 2
      ;;
    --config=*)
      CONFIG_FILE="${1#--config=}"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

has_device_arg() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      -d|--device-id|--device-id=*|-d*)
        return 0
        ;;
    esac
  done
  return 1
}

find_iphone_device_id() {
  "${FLUTTER_BIN}" devices 2>/dev/null | awk -F '•' '
    /iPhone/ && NF >= 2 {
      id = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
      if (id != "") {
        print id
        exit
      }
    }
  '
}

if [[ "${CONFIG_FILE}" != /* ]]; then
  CONFIG_FILE="${APP_DIR}/${CONFIG_FILE}"
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "error: config file not found: ${CONFIG_FILE}" >&2
  echo "copy config/local.example.json to config/local.json and fill local values." >&2
  exit 66
fi

cd "${APP_DIR}"
needs_auto_device=false
if [[ ${#args[@]} -eq 0 ]]; then
  needs_auto_device=true
elif ! has_device_arg "${args[@]}"; then
  needs_auto_device=true
fi

if [[ "${needs_auto_device}" == true ]]; then
  IPHONE_DEVICE_ID="$(find_iphone_device_id || true)"
  if [[ -n "${IPHONE_DEVICE_ID}" ]]; then
    echo "Using iPhone device: ${IPHONE_DEVICE_ID}"
    args+=("-d" "${IPHONE_DEVICE_ID}")
  fi
fi

if [[ ${#args[@]} -eq 0 ]]; then
  exec "${FLUTTER_BIN}" run --dart-define-from-file="${CONFIG_FILE}"
fi

exec "${FLUTTER_BIN}" run --dart-define-from-file="${CONFIG_FILE}" "${args[@]}"
