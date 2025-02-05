#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/)
# Copyright 2024-present Datadog, Inc.

mkdir .datadog

# $LANGUAGES or $DD_CIVISIBILITY_INSTRUMENTATION_LANGUAGES are required
if [[ -z "$LANGUAGES" && -z "$DD_CIVISIBILITY_INSTRUMENTATION_LANGUAGES" ]]; then
	>&2 echo "LANGUAGES is not set"
	exit 1
fi

# $API_KEY or $DD_API_KEY are required
if [[ -z "$API_KEY" && -z "$DD_API_KEY" ]]; then
	>&2 echo "API_KEY is not set"
	exit 1
elif [ -n "$API_KEY" ]; then
	export DD_API_KEY=${API_KEY}
fi

# $SITE or $DD_SITE are optional
if [[ -z "$SITE" && -z "$DD_SITE" ]]; then
	export DD_SITE=datadoghq.com
elif [ -n "$SITE" ]; then
	export DD_SITE=${SITE}
fi

# $SERVICE or $DD_SERVICE are optional
if [ -n "$SERVICE" ]; then
	export DD_SERVICE=${SERVICE}
fi

# $DOTNET_TRACER_VERSION or $DD_SET_TRACER_VERSION_DOTNET are optional
if [ -n "$DOTNET_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_DOTNET=${DOTNET_TRACER_VERSION}
fi

# $JAVA_TRACER_VERSION or $DD_SET_TRACER_VERSION_JAVA are optional
if [ -n "$JAVA_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_JAVA=${JAVA_TRACER_VERSION}
fi

# $JS_TRACER_VERSION or $DD_SET_TRACER_VERSION_JS are optional
if [ -n "$JS_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_JS=${JS_TRACER_VERSION}
fi

# $PYTHON_TRACER_VERSION or $DD_SET_TRACER_VERSION_PYTHON are optional
if [ -n "$PYTHON_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_PYTHON=${PYTHON_TRACER_VERSION}
fi

# $RUBY_TRACER_VERSION or $DD_SET_TRACER_VERSION_RUBY are optional
if [ -n "$RUBY_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_RUBY=${RUBY_TRACER_VERSION}
fi

# $GO_TRACER_VERSION or $DD_SET_TRACER_VERSION_GO are optional
if [ -n "$GO_TRACER_VERSION" ]; then
	export DD_SET_TRACER_VERSION_GO=${GO_TRACER_VERSION}
fi

# $JAVA_INSTRUMENTED_BUILD_SYSTEM or $DD_INSTRUMENTATION_BUILD_SYSTEM_JAVA are optional
if [ -n "$JAVA_INSTRUMENTED_BUILD_SYSTEM" ]; then
	export DD_INSTRUMENTATION_BUILD_SYSTEM_JAVA=${JAVA_INSTRUMENTED_BUILD_SYSTEM}
fi

export DD_CIVISIBILITY_AUTO_INSTRUMENTATION_PROVIDER="gitlab"

installation_script_url="https://install.datadoghq.com/scripts/install_test_visibility_v6.sh"
installation_script_checksum="23c0bbba82ee72342dd3967c3147d1086debf6482e8fd729e226d051dd152cd4"
script_filepath="install_test_visibility.sh"

if command -v curl >/dev/null 2>&1; then
	curl -Lo "$script_filepath" "$installation_script_url"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$script_filepath" "$installation_script_url"
else
	>&2 echo "Error: Neither wget nor curl is installed."
	exit 1
fi

if ! echo "$installation_script_checksum $script_filepath" | sha256sum --quiet -c -; then
	>&2 echo "Error: The checksum of the downloaded script does not match the expected checksum."
        exit 1
fi

chmod +x ./install_test_visibility.sh

while IFS='=' read -r name value; do
  if [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    export "$name=$value"
  fi
done < <(DD_CIVISIBILITY_INSTRUMENTATION_LANGUAGES="${LANGUAGES}" ./install_test_visibility.sh)

echo "---"
echo "Installed Test Optimization libraries:"

if [ ! -z "$DD_TRACER_VERSION_DOTNET" ]; then
  echo "- __.NET:__ $DD_TRACER_VERSION_DOTNET"
fi
if [ ! -z "$DD_TRACER_VERSION_JAVA" ]; then
  echo "- __Java:__ $DD_TRACER_VERSION_JAVA"
fi
if [ ! -z "$DD_TRACER_VERSION_JS" ]; then
  echo "- __JS:__ $DD_TRACER_VERSION_JS"
fi
if [ ! -z "$DD_TRACER_VERSION_PYTHON" ]; then
  echo "- __Python:__ $DD_TRACER_VERSION_PYTHON"
fi
if [ ! -z "$DD_TRACER_VERSION_RUBY" ]; then
  echo "- __Ruby:__ $DD_TRACER_VERSION_RUBY"
fi
if [ ! -z "$DD_TRACER_VERSION_GO" ]; then
  echo "- __Go:__ $DD_TRACER_VERSION_GO"
fi
echo "---"
