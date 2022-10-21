#!/bin/bash

set -e

test_result_wrapper(){
  local VERSION=$1
  local FILE=$2

  local NODE="/usr/bin/node$VERSION"
  local OUTPUT="/tmp/test_output"
  local RESULT=0;

  # Try same test 3 times before giving up
  local i=0;
  while [ $i -le 2 ]
  do
    # Run the test (using common and custom flags if present) and save the output
    echo "Running $NODE_FULL_VERSION $NODE $GLOBAL_FLAGS ${node_flags[$VERSION $FILE]}$FILE - Try #$i"
    set +e
    $NODE $GLOBAL_FLAGS ${node_flags[$VERSION $FILE]} $FILE &> $OUTPUT
    RESULT=$?
    set -e
    if [ $RESULT -eq 0 ]; then
      break
    fi
    echo "Did not work out this time."
    ((i+=1))
  done

  # If test failed, keep track of failure and print out its output
  if [ $RESULT -ne 0 ]; then
    echo "FAILED"
    echo "Test Output:"
    cat $OUTPUT

    if [ "${skip_test[$NODE_FULL_VERSION $FILE $OS_VERSION]}X" = "skipX" ]; then
      echo "Test was in the exclusion list. Failed result will be SKIPPED."
      echo "Node v$NODE_FULL_VERSION Test $FILE" >> $SKIPPED_TEST_LIST
    else
      echo "Node v$NODE_FULL_VERSION Test $FILE" >> $FAILED_TEST_LIST
    fi
  else
    echo "OK"
  fi
  rm $OUTPUT
}

test_node_version(){
  local VERSION="$1"

  echo "Starting to test node version $VERSION"

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

  OS_VERSION="$1"
  echo "OS_VERSION: $OS_VERSION"

  # Install dependencies to apply source patches and run tests
  zypper -n in quilt rpm-build  libopenssl1_1-hmac

  if [ "$OS_VERSION" = "SLE_12_SP5" ]; then
    zypper -n in openssl-1_1
  fi

  # Get list of each nodejs version found from default repo
  local NODE_VERSIONS=$(zypper -n search nodejs | grep -E -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | tr -d ' '| tr -d 'nodejs' | sort -h -u)
  local NODE_LATEST_VERSION=$(zypper -n search nodejs | grep -E -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | tr -d ' '| tr -d 'nodejs' | sort -h -u | tail -n1)

  for v in $NODE_VERSIONS; do
    echo "Found node version: $v"
  done
  echo "Will test only latest version: $NODE_LATEST_VERSION" 

  # Install latest nodejs version and sources
  zypper -n in --no-recommends "nodejs$NODE_LATEST_VERSION"
  NODE_FULL_VERSION=$(rpm -q nodejs${NODE_LATEST_VERSION} --qf '%{version}-%{release}')

  zypper -n si -D "nodejs$NODE_LATEST_VERSION"

  test_node_version $NODE_LATEST_VERSION

  # Print out info in case of skipped tests
  if [ -s "$SKIPPED_TEST_LIST" ]; then
    echo "Some tests have been skipped:"
    cat $SKIPPED_TEST_LIST
    echo ""
    echo "Please look for 'SKIPPED' in the serial_terminal log for the full trace"
  fi

  # Fail if at least one test has failed. Print list of failed tests
  if [ -s "$FAILED_TEST_LIST" ]; then
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

# Hashmap of tests that need to be skipped for a specific SLE version
# Usage:   ["$VERSION $FILE" "$OS_VERSION"]="skip"
# Example: ["14 tests/directory/mytest.js SLE_15"]="skip"
declare -A skip_test
skip_test=(
  ["16.13.2-8.3.1 test/parallel/test-crypto-engine.js SLE_12_SP5"]="skip" # This should be skipped also on future versions
  ["16.13.2-150300.7.3.1 test/parallel/test-crypto-engine.js SLE_15_SP3"]="skip" # This should be skipped also on future versions
  ["14.15.1-6.3.1 test/sequential/test-tls-securepair-client.js SLE_12_SP5"]="skip"
  ["14.15.1-6.3.1 test/sequential/test-tls-session-timeout.js SLE_12_SP5"]="skip"
  ["10.22.1-1.27.1 test/parallel/test-crypto-dh.js SLE_15"]="skip"
  ["10.22.1-1.27.1 test/parallel/test-crypto-dh.js SLE_15_SP1"]="skip"
  ["10.24.1-1.36.1 test/parallel/test-tls-passphrase.js SLE_15"]="skip"
  ["10.24.1-1.36.1 test/parallel/test-tls-passphrase.js SLE_15_SP1"]="skip"
)

# Common flags to use on each test
GLOBAL_FLAGS="--expose_gc --expose-internals"

# Use global variables to keep track if test some test fail and which one
FAILED_TEST_LIST="/tmp/failed_test_list"
SKIPPED_TEST_LIST="/tmp/skipped_test_list"

OS_VERSION=""
NODE_FULL_VERSION=""
main "$@"

