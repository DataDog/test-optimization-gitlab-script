#!/usr/bin/env bash
# Sources script.sh for Go in this shell, as a GitLab job does, and checks
# what the job's next commands get.
#
# Variables:
#   EXPECT_GO              instrumented or skipped
#   EXPECT_DDTEST_VERSION  for instrumented: a ddtest version, or latest
#   PROJECT_LAYOUT         root, or multiple_modules for two modules below it
#   EXPECT_STDERR          optional lines, each of which script.sh's stderr
#                          must contain
# and script.sh's own variables, such as GO_TRACER_VERSION.
#
# Each module declares go 1.22: ddtest builds with the image's toolchain and
# leaves go.mod as it is. SMOKE_FAIL=1 makes its test fail.
set -euo pipefail

fail() {
  echo "Error: $1" >&2
  exit 1
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
project_dir="$work_dir/project"
mkdir -p "$project_dir"
cd "$project_dir"

create_module() {
  local module_dir="$1"
  # A package name has no hyphen.
  local package_name
  package_name="$(basename "$module_dir" | tr -d -)"
  mkdir -p "$module_dir"
  printf 'module example.com/smoke/%s\n\ngo 1.22\n' "$package_name" > "$module_dir/go.mod"
  cat > "$module_dir/smoke_test.go" <<EOF
package $package_name

import (
	"os"
	"testing"
)

func TestSmoke(t *testing.T) {
	if os.Getenv("SMOKE_FAIL") == "1" {
		t.Fatal("SMOKE_FAIL is set")
	}
}
EOF
}

case "${PROJECT_LAYOUT:-root}" in
  root) modules=(go-smoke) ;;
  multiple_modules) modules=(go-smoke/services/payments go-smoke/services/orders) ;;
  *) fail "Unknown PROJECT_LAYOUT: $PROJECT_LAYOUT" ;;
esac
for module_dir in "${modules[@]}"; do
  create_module "$module_dir"
done
cp -R go-smoke "$work_dir/go-smoke.before"
toolchain_go="$(command -v go)"

# As the README shows, in the job's own shell. script.sh, like the jobs that
# source it, does not expect nounset.
stdout_file="$work_dir/script.stdout"
stderr_file="$work_dir/script.stderr"
set +u
# shellcheck source=/dev/null
if ! LANGUAGES="go" SERVICE="my-service" API_KEY="dummy" source "$repo_dir/script.sh" > "$stdout_file" 2> "$stderr_file"; then
  cat "$stdout_file"
  cat "$stderr_file" >&2
  fail "script.sh failed"
fi
set -u
cat "$stdout_file"
cat "$stderr_file" >&2

if [ -n "${EXPECT_STDERR:-}" ]; then
  while IFS= read -r expected_line; do
    [ -n "$expected_line" ] || continue
    grep -Fq -- "$expected_line" "$stderr_file" || fail "script.sh's stderr lacks: $expected_line"
  done <<< "$EXPECT_STDERR"
fi

go_path="$(command -v go)"
echo "go: $go_path (before script.sh: $toolchain_go)"
case "${EXPECT_GO:-}" in
  instrumented)
    reporting=reported
    [ "$go_path" != "$toolchain_go" ] || fail "go is still the toolchain's, $go_path, not ddtest's go command"
    expected_version="${EXPECT_DDTEST_VERSION:-latest}"
    if [ "$expected_version" = "latest" ]; then
      # GitHub redirects releases/latest to the newest release's tag.
      expected_version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/DataDog/ddtest/releases/latest)"
      expected_version="${expected_version##*/}"
    fi
    [ "${DD_TRACER_VERSION_GO:-}" = "$expected_version" ] || fail "ddtest ${DD_TRACER_VERSION_GO:-?} was installed, not $expected_version"
    ;;
  skipped)
    reporting=unreported
    [ "$go_path" = "$toolchain_go" ] || fail "go is $go_path, not the toolchain's $toolchain_go, though Go was skipped"
    [ -z "${DD_TRACER_VERSION_GO:-}" ] || fail "DD_TRACER_VERSION_GO is '$DD_TRACER_VERSION_GO', though Go was skipped"
    ;;
  *) fail "EXPECT_GO must be instrumented or skipped, got '${EXPECT_GO:-}'" ;;
esac

for module_dir in "${modules[@]}"; do
  # go test passes, and its test's event reaches the intake only when ddtest
  # instruments it.
  "$repo_dir/tests/go-reporting.sh" "$module_dir" TestSmoke "$reporting"
  if (cd "$module_dir" && SMOKE_FAIL=1 go test -count=1 ./...) > "$work_dir/failing.log" 2>&1; then
    cat "$work_dir/failing.log"
    fail "a failing test must fail go test in $module_dir"
  fi
done

# go test leaves the projects' files, go.mod included, as they were.
diff -r "$work_dir/go-smoke.before" go-smoke || fail "go test changed the projects' files"
echo "PASS: Go $EXPECT_GO (${PROJECT_LAYOUT:-root})"
