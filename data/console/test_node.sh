#!/bin/bash

declare -A node_flags
# Usage:   ["$VERSION $FILE"]="FLAG"
# Example: ["10 test/directory/mytest.js"]="--myFlag"
node_flags=(
  ["10 test/parallel/test-tls-cli-max-version-1.2.js"]="--tls-max-v1.2"
  ["10 test/parallel/test-tls-cli-min-version-1.0.js"]="--tls-min-v1.0"
  ["10 test/parallel/test-tls-cli-min-version-1.1.js"]="--tls-min-v1.1"
  ["10 test/parallel/test-tls-cli-min-version-1.2.js"]="--tls-min-v1.2"
  ["10 test/parallel/test-tls-cnnic-whitelist.js"]="--use-bundled-ca"
  ["10 test/parallel/test-tls-dhe.js"]="--no-warnings"
  ["10 test/parallel/test-tls-legacy-deprecated.js"]="--no-warnings"
  ["10 test/parallel/test-tls-securepair-leak.js"]="--no-deprecation"
  ["10 test/parallel/test-crypto-dh-leak.js"]="--noconcurrent-recompilation"
)

FAILED_TEST_LIST="/tmp/failed_test_list"

test_wrapper(){
  local VERSION=$1
  local FILE=$2

  local NODE="/usr/bin/node$VERSION"
  local GLOBAL_FLAGS="--expose_gc --expose-internals"

  local OUTPUT="/tmp/test_output"

  echo "Running $NODE $GLOBAL_FLAGS $FILE ${node_flags[$VERSION $FILE]}"

  # Run the test (using custom flags if present) and save the output, print it only if it fails
  $NODE $GLOBAL_FLAGS $FILE ${node_flags[$VERSION $FILE]} > $OUTPUT 2>&1
  if [ $? -ne 0 ]; then
    TEST_RESULT="failed"
    echo "FAILED"
    echo "Test Output:"
    cat $OUTPUT
    echo "Node v$VERSION Test $FILE" >> $FAILED_TEST_LIST
  else
    echo "OK"
  fi
  rm $OUTPUT

}

test_node_version(){
  local VERSION
  VERSION="$1"

  echo "Start testing node version $VERSION"
  
  zypper -n si -D "nodejs$VERSION" > /dev/null 2>&1
  zypper -n in --no-recommends "nodejs$VERSION" > /dev/null 2>&1


  local SOURCE_FILE
  SOURCE_FILE=$(cd /usr/src/packages/SOURCES/ && find . -type f -iname "node-v$VERSION*.tar.xz")
  SOURCE_FILE=${SOURCE_FILE:2} # strip ./ from name

  if [ -z "$SOURCE_FILE" ]
  then
    echo "\$SOURCE_FILE is empty"
    exit 1
  fi

  local SOURCE_DIR
  SOURCE_DIR=${SOURCE_FILE%.tar.xz} #remove extension from filename to get directory

  # Unpack and apply patches to source
  # Run the tests on the source using the installed binary
  pushd "/usr/src/packages/SOURCES"
    quilt setup "../SPECS/nodejs$VERSION.spec"
    pushd "$SOURCE_DIR"
      quilt push -a
      for f in $(find test \( -path \*sequential\* -or -path \*parallel\* \) \( -name test-crypto-\* -or -name test-tls-\* \)); do
        test_wrapper $VERSION $f
      done
    popd
  popd

  #TODO: should I delete all content of SOURCES-SPEC before next round?

  # Cleanup:
  rm -rf /usr/src/packages/SOURCES/*
  rm -rf /usr/src/packages/SPECS/* 
}

# Use a global variable to keep track of failures
TEST_RESULT="ok"

# Install dependencies to apply source patches
zypper -n in quilt rpm-build > /dev/null 2>&1

# Run test
test_node_version 8
test_node_version 10
test_node_version 12
#TODO: should I get the list of available versions and test all of them?

if [ "$TEST_RESULT" != "ok" ]; then
  echo "Some tests have failed"
  cat $FAILED_TEST_LIST
  echo ""
  echo "Please look for 'FAILED' in the serial_terminal log for the full trace"
  exit 1
else
  echo "ALL tests have passed."
fi

