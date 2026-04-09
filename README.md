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
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.2.7/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^f2b93329e8b7ae59ec8901ce362c1a0492faeb54e60dbf6d0216ea81a1e5b1fe' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - npm run test
```

## Configuration

The script takes in the following environment variables:

| Name                           | Description                                                                                                                                                                                                                                                                                         | Required | Default       |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------- |
| LANGUAGES                      | List of languages to be instrumented. Can be either "all" or any of "java", "js", "python", "dotnet", "ruby" (multiple languages can be specified as a space-separated list).                                                                                                                       | true     |               |
| API_KEY                        | Datadog API key. Can be found at https://app.datadoghq.com/organization-settings/api-keys                                                                                                                                                                                                           | true     |               |
| SITE                           | Datadog site. See https://docs.datadoghq.com/getting_started/site for more information about sites.                                                                                                                                                                                                 | false    | datadoghq.com |
| SERVICE                        | The name of the service or library being tested.                                                                                                                                                                                                                                                    | false    |               |
| DOTNET_TRACER_VERSION          | The version of Datadog .NET tracer to use. Defaults to the latest release.                                                                                                                                                                                                                          | false    |               |
| JAVA_TRACER_VERSION            | The version of Datadog Java tracer to use. Defaults to the latest release.                                                                                                                                                                                                                          | false    |               |
| JS_TRACER_VERSION              | The version of Datadog JS tracer to use. Defaults to the latest release.                                                                                                                                                                                                                            | false    |               |
| PYTHON_TRACER_VERSION          | The version of Datadog Python tracer to use. Defaults to the latest release.                                                                                                                                                                                                                        | false    |               |
| PYTHON_COVERAGE_VERSION        | The version of the Python `coverage` package to install. Defaults to `7.13.5`.                                                                                                                                                                                                                      | false    | 7.13.5        |
| RUBY_TRACER_VERSION            | The version of datadog-ci gem to use. Defaults to the latest release.                                                                                                                                                                                                                               | false    |               |
| GO_TRACER_VERSION              | The version of Orchestrion automatic compile-time instrumentation of Go code (https://github.com/datadog/orchestrion) to use. Defaults to the latest release.                                                                                                                                       | false    |               |
| GO_MODULE_DIR                  | Path to the Go module root directory to instrument. Use this when the repository contains multiple Go modules or the Go module is not in the repository root.                                                                                                                                       | false    |               |
| JAVA_INSTRUMENTED_BUILD_SYSTEM | If provided, only the specified build systems will be instrumented (allowed values are `gradle`,`maven`,`sbt`,`ant`,`all`). `all` is a special value that instruments every Java process. If this property is not provided, all known build systems will be instrumented (Gradle, Maven, SBT, Ant). | false    |               |

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
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.2.7/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^f2b93329e8b7ae59ec8901ce362c1a0492faeb54e60dbf6d0216ea81a1e5b1fe' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - npm run test
```

### Go multi-module repositories

If your repository contains multiple Go modules, or the Go module you want to instrument is not at the repository root, set `GO_MODULE_DIR` to the module root directory that contains the target `go.mod` file:

```yaml
test_go:
  image: golang:1.25.0
  script:
    - |
      LANGUAGES="go" SITE="datadoghq.com" API_KEY="YOUR_API_KEY_SECRET" GO_MODULE_DIR="./services/payments" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.2.7/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^f2b93329e8b7ae59ec8901ce362c1a0492faeb54e60dbf6d0216ea81a1e5b1fe' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - cd services/payments
    - go test ./...
```

## Limitations

### Tracing vitest tests

ℹ️ This section is only relevant if you're running tests with [vitest](https://github.com/vitest-dev/vitest).

To use this script with vitest you need to modify the NODE_OPTIONS environment variable adding the `--import` flag with the value of the `DD_TRACE_ESM_IMPORT` environment variable.

```yaml
test_node_vitest:
  image: node:latest
  script:
    - |
      LANGUAGES="js" SITE="datadoghq.com" API_KEY="YOUR_API_KEY_SECRET" \
      SRC=$(curl -fsSL https://github.com/DataDog/test-optimization-gitlab-script/releases/download/v1.2.7/script.sh); \
      echo "$SRC" | sha256sum | grep -q '^f2b93329e8b7ae59ec8901ce362c1a0492faeb54e60dbf6d0216ea81a1e5b1fe' && \
        source <(echo "$SRC") || \
        echo "ERROR: SHA256 mismatch. Datadog Test Optimization autoinstrumentation not enabled." >&2
    - export NODE_OPTIONS="$NODE_OPTIONS --import $DD_TRACE_ESM_IMPORT"
    - npm run test
```

**Important**: `vitest` and `dd-trace` require Node.js>=18.19 or Node.js>=20.6 to work together.

### Tracing cypress tests

To instrument your [Cypress](https://www.cypress.io/) tests with Datadog Test Optimization, please follow the manual steps in the [docs](https://docs.datadoghq.com/tests/setup/javascript/?tab=cypress).
