#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/adaptive-chat-checks.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
xcrun --sdk macosx swiftc -parse-as-library -swift-version 5 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -module-cache-path "$build_dir/modules" \
  "$project_dir/AdaptiveChat/Models/Conversation.swift" \
  "$project_dir/AdaptiveChat/Services/ChatStore.swift" \
  "$project_dir/AdaptiveChat/ViewModels/ChatListViewModel.swift" \
  "$project_dir/AdaptiveChat/ViewModels/ChatDetailViewModel.swift" \
  "$project_dir/Tests/StateChecks.swift" \
  -o "$build_dir/StateChecks"
"$build_dir/StateChecks"
