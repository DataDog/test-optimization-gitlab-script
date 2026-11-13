# <img height="25" src="logos/test_visibility_logo.png" /> Datadog Test Optimization GitLab Script

Bash script that installs and configures [Datadog Test Optimization](https://docs.datadoghq.com/tests/) for GitLab.
Supported languages are .NET, Java, Javascript, Python, Ruby and Go.

## About Datadog Test Optimization

[Test Optimization](https://docs.datadoghq.com/tests/) provides a test-first view into your CI health by displaying important metrics and results from your tests.
It can help you investigate and mitigate performance problems and test failures that are most relevant to your work, focusing on the code you are responsible for, rather than the pipelines which run your tests.

## Usage

Execute this script in your GitLab CI's job YAML before running the tests. Pass the languages, api key and [site](https://docs.datadoghq.com/getting_started/site/) environment variables:

```yaml
test_node:
  image: node:latest
  script:
    - |
      LANGUAGES="js" SITE="datadoghq.com" API_KEY="YOUR_API_KEY_SECRET" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.3.0/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^94657425c864c4d2a2f73ba4805d10888e7b62e26a2fc191b7e8453581376002' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - npm run test
```

## Configuration

The script takes in the following environment variables:

| Name                           | Description                                                                                                                                                                                                                                                                                         | Required | Default       |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------- |
| LANGUAGES                      | List of languages to be instrumented. Can be either "all" or any of "java", "js", "python", "dotnet", "ruby", "go" (multiple languages can be specified as a space-separated list).                                                                                                                 | true     |               |
| API_KEY                        | Datadog API key. Can be found at https://app.datadoghq.com/organization-settings/api-keys                                                                                                                                                                                                           | true     |               |
| SITE                           | Datadog site. See https://docs.datadoghq.com/getting_started/site for more information about sites.                                                                                                                                                                                                 | false    | datadoghq.com |
| SERVICE                        | The name of the service or library being tested.                                                                                                                                                                                                                                                    | false    |               |
| DOTNET_TRACER_VERSION          | The version of Datadog .NET tracer to use. Defaults to the latest release.                                                                                                                                                                                                                          | false    |               |
| JAVA_TRACER_VERSION            | The version of Datadog Java tracer to use. Defaults to the latest release.                                                                                                                                                                                                                          | false    |               |
| JAVA_TRACER_REPOSITORY_URL     | Base URL of a Maven repository (or proxy/mirror) used to download the Java tracer JAR and its `.sha256`. The path under the base must follow the standard Maven layout for `com.datadoghq:dd-java-agent`. Defaults to `https://repo1.maven.org/maven2/com/datadoghq/dd-java-agent`.                  | false    |               |
| JAVA_AUTH_HEADER               | HTTP header used to authenticate against `JAVA_TRACER_REPOSITORY_URL`, provided as a complete `Name: Value` string (e.g. `Authorization: Bearer <token>`). Requires `JAVA_TRACER_REPOSITORY_URL` to be set to a custom repository URL. Redirects are followed by default; the header will be re-sent on each redirect hop. `curl` strips `Authorization` and `Cookie` headers on cross-origin redirects (different host, port, or scheme), but `wget` does not strip any header. Custom header names (e.g. `X-API-Key`) are never stripped by either tool — prefer the `Authorization: …` form when possible. | false    |               |
| JAVA_AUTH_DISABLE_REDIRECTS    | When set to any non-empty value, disables HTTP redirect following for Java tracer downloads that send `JAVA_AUTH_HEADER`. Use this if your repository never redirects and you want to guarantee the auth header is only ever sent to the configured `JAVA_TRACER_REPOSITORY_URL` host.                                                                                                                                                                                                                                                                                                                  | false    |               |
| JS_TRACER_VERSION              | The version of Datadog JS tracer to use. Defaults to the latest release.                                                                                                                                                                                                                            | false    |               |
| PYTHON_TRACER_VERSION          | The version of Datadog Python tracer to use. Defaults to the latest release.                                                                                                                                                                                                                        | false    |               |
| RUBY_TRACER_VERSION            | The version of datadog-ci gem to use. Defaults to the latest release.                                                                                                                                                                                                                               | false    |               |
| GO_TRACER_VERSION              | The version of [ddtest](https://github.com/DataDog/ddtest) to use for Go, `v1.14.0` or newer. Defaults to the latest release. See [Tracing Go tests](#tracing-go-tests).                                                                                                                            | false    |               |
| JAVA_INSTRUMENTED_BUILD_SYSTEM | If provided, only the specified build systems will be instrumented (allowed values are `gradle`,`maven`,`sbt`,`ant`,`all`). `all` is a special value that instruments every Java process. If this property is not provided, all known build systems will be instrumented (Gradle, Maven, SBT, Ant). | false    |               |

The deprecated variables `GO_MODULE_DIR` and `PYTHON_COVERAGE_VERSION` are still accepted, with a warning, and have no effect: ddtest instruments `go test` in every Go module, and the Python tracer no longer needs the `coverage` package, which the script no longer installs.

### Additional configuration

Any [additional configuration values](https://docs.datadoghq.com/tracing/trace_collection/library_config/) can be added directly to the job that runs your tests:

```yaml
test_node:
  image: node:latest
  script:
    - export DD_API_KEY="YOUR_API_KEY_SECRET"
    - export DD_ENV="staging-tests"
    - export DD_TAGS="layer:api,team:intake,key:value"
    - |
      LANGUAGES="js" SITE="datadoghq.com" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.3.0/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^94657425c864c4d2a2f73ba4805d10888e7b62e26a2fc191b7e8453581376002' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - npm run test
```

## Limitations

### Tracing vitest tests

ℹ️ This section is only relevant if you're running tests with [vitest](https://github.com/vitest-dev/vitest). Vitest is ESM first and requires the additional `--import` flag shown below.

To use this script with vitest you need to modify the NODE_OPTIONS environment variable adding the `--import` flag with the value of the `DD_TRACE_ESM_IMPORT` environment variable.

```yaml
test_node_vitest:
  image: node:latest
  script:
    - |
      LANGUAGES="js" SITE="datadoghq.com" API_KEY="YOUR_API_KEY_SECRET" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.3.0/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^94657425c864c4d2a2f73ba4805d10888e7b62e26a2fc191b7e8453581376002' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - export NODE_OPTIONS="$NODE_OPTIONS --import $DD_TRACE_ESM_IMPORT"
    - npm run test
```

**Important**: `vitest` and `dd-trace` require Node.js>=18.19 or Node.js>=20.6 to work together.

### Tracing Cypress tests

Cypress uses the standard JavaScript auto-instrumentation setup shown above. No changes to the Cypress configuration or support file are required.

### Tracing Go tests

Go tests report through [`ddtest instrument`](https://github.com/DataDog/ddtest/blob/main/ddto/README.md). The script puts ddtest's `go` command first on `PATH` in the job's shell. That `go` runs `go test` through ddtest, also when `make`, a script or [gotestsum](https://github.com/gotestyourself/gotestsum) starts it, and runs every other `go` command unchanged. The script does not modify your `go.mod`, and a repository with several Go modules needs no configuration.

```yaml
test_go:
  image: golang:1.25
  script:
    - |
      LANGUAGES="go" SITE="datadoghq.com" API_KEY="YOUR_API_KEY_SECRET" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.3.0/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^94657425c864c4d2a2f73ba4805d10888e7b62e26a2fc191b7e8453581376002' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - go test ./...
```

- The job's image needs Go 1.25 or newer. With an older Go, the script prints a warning and skips Go instrumentation, and the job continues. Your `go.mod` can still declare an older Go version.
- The job downloads ddtest from `github.com`.
- Run the tests later in the same job, after the script. ddtest's `go` command lives in the job user's cache directory and is a link to the executable in the `.datadog` folder that the script creates. If a later command deletes that folder or puts another `go` first on `PATH`, `go test` runs without Test Optimization.
- With Test Impact Analysis, build the tests with coverage in count or atomic mode, such as `go test -cover -covermode=atomic ./...`, so each test reports the code it ran.
- `GO_TRACER_VERSION` selects a ddtest release. It used to select an Orchestrion version, so a value set then no longer installs that version. A value that names no ddtest release from `v1.14.0` on, such as `v1.8.0`, installs the latest ddtest with a warning, and a version from `v1.14.0` on installs the ddtest release with the same number. To keep Orchestrion, use release v1.2.10 of this script or earlier.
