#!/bin/bash

set -e

test_result_wrapper(){
  local VERSION=$1
  local FILE=$2

  local NODE="/usr/bin/node$VERSION"
  local OUTPUT="/tmp/test_output"

  # Run the test (using common and custom flags if present) and save the output
  echo "Running $NODE $GLOBAL_FLAGS ${node_flags[$VERSION $FILE]}$FILE"
  set +e
  $NODE $GLOBAL_FLAGS ${node_flags[$VERSION $FILE]} $FILE &> $OUTPUT
  RESULT=$?
  set -e

  # If test failed, keep track of failure and print out its output
  if [ $RESULT -ne 0 ]; then
    TEST_RESULT="failed"
    echo "Node v$VERSION Test $FILE" >> $FAILED_TEST_LIST

    echo "FAILED"
    echo "Test Output:"
    cat $OUTPUT
  else
    echo "OK"
  fi
  rm $OUTPUT
}

test_node_version(){
  local VERSION="$1"

  echo "Starting to test node version $VERSION"

  # Get latest sources to make sure tests contain correct patches
  zypper -n --no-gpg-checks si --repo node_sources -D "nodejs$VERSION"

  local SOURCE_FILE=""
  SOURCE_FILE=$(cd /usr/src/packages/SOURCES/ && find . -type f -iname "node-v$VERSION*.tar.xz")
  SOURCE_FILE=${SOURCE_FILE:2} # strip ./ from name

  if [ -z "$SOURCE_FILE" ]; then
    echo "Can't find the sources of nodejs$VERSION"
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
      # Run all test-crypto and test-tls available
      for f in $(find test \( -path \*sequential\* -or -path \*parallel\* \) \( -name test-crypto-\* -or -name test-tls-\* \)); do
        test_result_wrapper $VERSION $f
      done
    popd
  popd

  # Cleanup sources
  rm -rf /usr/src/packages/SOURCES/*
  rm -rf /usr/src/packages/SPECS/* 
}

main(){

  local OS_VERSION="$1"

  # Install dependencies to apply source patches and run tests
  zypper -n in quilt rpm-build openssl-1_1

  # Get list of each nodejs version found from default repo
  local NODE_VERSIONS=$(zypper -n search nodejs | egrep -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | tr -d ' '| tr -d 'nodejs' | sort -h | uniq)
  local NODE_LATEST_VERSION=$(zypper -n search nodejs | egrep -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | tr -d ' '| tr -d 'nodejs' | sort -h | uniq | tail -n1)

  for v in $NODE_VERSIONS; do
    echo "Found node version: $v"
  done
  echo "Will test only latest version: $NODE_LATEST_VERSION" 

  # Install latest nodejs version
  zypper -n in --no-recommends "nodejs$NODE_LATEST_VERSION"

  # Trap for cleanup of repo
  trap 'zypper -n rr node_sources' EXIT
  # Add sources repo to have latest source patches
  zypper -n --gpg-auto-import-keys ar -f "http://download.suse.de/ibs/home:/adamm:/node_test/$OS_VERSION/" node_sources

  test_node_version $NODE_LATEST_VERSION
    
  # Fail if at least one test has failed. Print list of failed tests
  if [ "$TEST_RESULT" != "ok" ]; then
    echo "Some tests have failed:"
    cat $FAILED_TEST_LIST
    echo ""
    echo "Please look for 'FAILED' in the serial_terminal log for the full trace"
    exit 1
  else
    echo "ALL tests have passed."
  fi
}

# Hashmap of special flags required by some tests
# Usage:   ["$VERSION $FILE"]="FLAG"
# Example: ["10 test/directory/mytest.js"]="--myFlag"
declare -A node_flags
node_flags=(
  ["10 test/parallel/test-tls-cli-max-version-1.2.js"]="--tls-max-v1.2"
  ["10 test/parallel/test-tls-cli-min-version-1.0.js"]="--tls-min-v1.0 --tls-min-v1.1"
  ["10 test/parallel/test-tls-cli-min-version-1.1.js"]="--tls-min-v1.1"
  ["10 test/parallel/test-tls-cli-min-version-1.2.js"]="--tls-min-v1.2"
  ["10 test/parallel/test-tls-cnnic-whitelist.js"]="--use-bundled-ca"
  ["10 test/parallel/test-tls-dhe.js"]="--no-warnings"
  ["10 test/parallel/test-tls-legacy-deprecated.js"]="--no-warnings"
  ["10 test/parallel/test-tls-securepair-leak.js"]="--no-deprecation"
  ["10 test/parallel/test-crypto-dh-leak.js"]="--noconcurrent-recompilation"
)

# Common flags to use on each test
GLOBAL_FLAGS="--expose_gc --expose-internals"

# Use global variables to keep track if test some test fail and which one
FAILED_TEST_LIST="/tmp/failed_test_list"
TEST_RESULT="ok"

main "$@"

