#!/usr/bin/env bash
# Decide whether a Linux CI build should create and upload packages.

set -euo pipefail

should_build_linux_packages() {
  local event_name=$1
  local ref=$2
  local full_ci=$3

  case "$event_name" in
    pull_request)
      [ "$full_ci" = true ]
      ;;
    push)
      [ "$ref" != "refs/heads/develop" ]
      ;;
    *)
      return 0
      ;;
  esac
}

expect_policy() {
  local expected=$1
  shift
  local actual=false
  if should_build_linux_packages "$@"; then
    actual=true
  fi
  if [ "$actual" != "$expected" ]; then
    echo "self-test failed: expected packaging=$expected for $*, got $actual" >&2
    exit 1
  fi
}

if [ "${1:-}" = "--self-test" ]; then
  expect_policy false pull_request refs/pull/581/merge false
  expect_policy true pull_request refs/pull/581/merge true
  expect_policy false push refs/heads/develop false
  expect_policy false push refs/heads/develop true
  expect_policy true push refs/heads/release/3.2 false
  expect_policy true workflow_dispatch refs/heads/develop false
  expect_policy true workflow_dispatch refs/heads/topic false
  expect_policy true schedule refs/heads/develop false

  echo "select-linux-packaging.sh self-test passed"
  exit 0
fi

build_packages=false
if should_build_linux_packages \
    "${EVENT_NAME:-}" "${GITHUB_REF:-}" "${FULL_CI:-false}"; then
  build_packages=true
fi

echo "Build Linux packages: $build_packages"
echo "Packaging policy: event=${EVENT_NAME:-unknown}, ref=${GITHUB_REF:-unknown}, full-ci=${FULL_CI:-false}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "build_packages=$build_packages" >> "$GITHUB_OUTPUT"
fi
