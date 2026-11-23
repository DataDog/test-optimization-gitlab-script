#!/usr/bin/env bash
# Sources script.sh for Rust in this shell, as a GitLab job does, and checks
# what the job's next commands get.
#
# Variables:
#   EXPECT_RUST                instrumented or unavailable
#   EXPECT_DD_TEST_RS_VERSION  for instrumented: a dd-test-rs version, or latest
#   EXPECT_STDERR              optional lines, each of which script.sh's stderr
#                              must contain
# and script.sh's own variables, such as RUST_TRACER_VERSION.
#
# The project's test, test_smoke, reaches the intake only when the wrapper
# instruments it: each case checks what a local stand-in for the intake
# receives, not the wrapper's log messages. SMOKE_FAIL=1 makes the test fail.
set -euo pipefail

fail() {
  echo "Error: $1" >&2
  exit 1
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
project_dir="$work_dir/project"
mkdir -p "$project_dir/src"
cd "$project_dir"

cat > Cargo.toml <<'EOF'
[package]
name = "rust-smoke"
version = "0.1.0"
edition = "2021"
EOF

cat > src/lib.rs <<'EOF'
pub fn add(left: u32, right: u32) -> u32 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::add;

    #[test]
    fn test_smoke() {
        if std::env::var("SMOKE_FAIL").as_deref() == Ok("1") {
            panic!("SMOKE_FAIL is set");
        }
        assert_eq!(add(1, 2), 3);
    }
}
EOF

# As the README shows, in the job's own shell. script.sh, like the jobs that
# source it, does not expect nounset.
stdout_file="$work_dir/script.stdout"
stderr_file="$work_dir/script.stderr"
set +u
# shellcheck source=/dev/null
if ! LANGUAGES="rust" SERVICE="my-service" API_KEY="dummy" source "$repo_dir/script.sh" > "$stdout_file" 2> "$stderr_file"; then
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

case "${EXPECT_RUST:-}" in
  instrumented)
    reporting=reported
    wrapper="${RUSTC_WORKSPACE_WRAPPER:-}"
    [ -n "$wrapper" ] || fail "script.sh did not export RUSTC_WORKSPACE_WRAPPER"
    [ "${wrapper#/}" != "$wrapper" ] || fail "RUSTC_WORKSPACE_WRAPPER is not absolute: $wrapper"
    [ -x "$wrapper" ] || fail "RUSTC_WORKSPACE_WRAPPER is not an executable: $wrapper"
    [ "$(dirname "$wrapper")" = "$project_dir/.datadog" ] || fail "RUSTC_WORKSPACE_WRAPPER is $wrapper, outside the .datadog folder the script creates"
    expected_version="${EXPECT_DD_TEST_RS_VERSION:-latest}"
    if [ "$expected_version" = "latest" ]; then
      # GitHub redirects releases/latest to the newest release's tag.
      expected_version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/DataDog/dd-test-rs/releases/latest)"
      expected_version="${expected_version##*/}"
    fi
    [ "${DD_TRACER_VERSION_RUST:-}" = "$expected_version" ] || fail "dd-test-rs ${DD_TRACER_VERSION_RUST:-?} was installed, not $expected_version"
    grep -Fq -- "- __Rust:__ $expected_version" "$stdout_file" || fail "script.sh's output lacks the installed Rust version, $expected_version"
    ;;
  unavailable)
    reporting=unreported
    [ -z "${RUSTC_WORKSPACE_WRAPPER:-}" ] || fail "RUSTC_WORKSPACE_WRAPPER is '$RUSTC_WORKSPACE_WRAPPER', though Rust was skipped"
    [ -z "${DD_TRACER_VERSION_RUST:-}" ] || fail "DD_TRACER_VERSION_RUST is '$DD_TRACER_VERSION_RUST', though Rust was skipped"
    ;;
  *) fail "EXPECT_RUST must be instrumented or unavailable, got '${EXPECT_RUST:-}'" ;;
esac

# The case that checks the missing-cargo error has no test to run.
if ! command -v cargo >/dev/null 2>&1; then
  echo "PASS: Rust $EXPECT_RUST, and cargo is not installed, so there is no test to run"
  exit 0
fi

# The intake's own folder, outside the project, for every run: an earlier
# run's events must not count for this one.
intake_dir="$(mktemp -d)"
python_bin=""
for candidate in python3 python; do
  if "$candidate" -c 'import sys' >/dev/null 2>&1; then
    python_bin="$candidate"
    break
  fi
done
[ -n "$python_bin" ] || fail "The intake needs Python."

intake_pid=""
stop_intake() {
  if [ -n "$intake_pid" ]; then
    kill "$intake_pid" 2>/dev/null || true
    wait "$intake_pid" 2>/dev/null || true
    intake_pid=""
  fi
}
trap stop_intake EXIT

# Without the step's output streams: on Windows, a background process that
# holds them keeps the GitHub Actions step running.
(cd "$intake_dir" && exec "$python_bin" "$repo_dir/tests/intake.py" "$intake_dir/port" \
  "$intake_dir/requests.log") > "$intake_dir/intake.out" 2>&1 &
intake_pid=$!
for _ in $(seq 1 300); do
  [ -s "$intake_dir/port" ] && break
  sleep 0.1
done
if [ ! -s "$intake_dir/port" ]; then
  cat "$intake_dir/intake.out" >&2 2>/dev/null || true
  fail "The intake did not start."
fi

log="$intake_dir/cargo-test.log"
intake_url="http://127.0.0.1:$(cat "$intake_dir/port")"
if ! DD_CIVISIBILITY_AGENTLESS_URL="$intake_url" cargo test > "$log" 2>&1; then
  cat "$log"
  fail "cargo test failed in $project_dir."
fi
cat "$log"

if SMOKE_FAIL=1 DD_CIVISIBILITY_AGENTLESS_URL="$intake_url" cargo test > "$intake_dir/failing.log" 2>&1; then
  cat "$intake_dir/failing.log"
  fail "a failing test must fail cargo test"
fi
stop_intake

echo "--- requests that reached the intake:"
cat "$intake_dir/requests.log" 2>/dev/null || echo "(none)"

# The test's own event names it; a session or module event does not. The
# payloads are binary, which grep matches in the C locale.
actual=unreported
if LC_ALL=C grep -a -q "test_smoke" "$intake_dir/requests.log.payloads" 2>/dev/null; then
  actual=reported
fi
[ "$actual" = "$reporting" ] || fail "The event of test_smoke is $actual, expected $reporting."

echo "PASS: Rust $EXPECT_RUST, and the event of test_smoke is $reporting"
