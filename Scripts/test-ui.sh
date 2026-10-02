#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project 'RAW Photo Studio.xcodeproj' -scheme 'RAW Photo Studio' -destination 'platform=macOS' \
  -parallel-testing-enabled NO -collect-test-diagnostics never -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 -derivedDataPath build -resultBundlePath build/Workflow-$(date +%s).xcresult test
