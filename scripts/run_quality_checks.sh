#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-/tmp/DailyTodosChecks}"

cd "$ROOT_DIR"

swiftc -parse-as-library \
  Sources/DailyTodos/TodoItem.swift \
  Sources/DailyTodos/HandbookItem.swift \
  Sources/DailyTodos/TodoQuickInputParser.swift \
  Sources/DailyTodos/AppStateModels.swift \
  Sources/DailyTodos/ViewDerivedModels.swift \
  Sources/DailyTodos/HandbookRepository.swift \
  Sources/DailyTodos/HandbookWorkspaceViewModel.swift \
  Sources/DailyTodos/PerformanceMonitor.swift \
  Sources/DailyTodos/TodoStore.swift \
  Sources/DailyTodos/AppUpdateAvailability.swift \
  Sources/DailyTodos/AppUpdateDownloadProgress.swift \
  Sources/DailyTodos/HandbookEditorPlaceholderPolicy.swift \
  Sources/DailyTodos/HandbookEditorSyncPolicy.swift \
  Sources/DailyTodos/CredentialModels.swift \
  Sources/DailyTodos/CredentialCrypto.swift \
  Sources/DailyTodos/CredentialBreachChecker.swift \
  Sources/DailyTodos/CredentialImportParser.swift \
  Sources/DailyTodos/CredentialStore.swift \
  scripts/quality_checks.swift \
  -o "$OUTPUT"

"$OUTPUT"
