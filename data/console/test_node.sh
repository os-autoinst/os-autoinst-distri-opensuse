#!/bin/bash

test_result_wrapper(){
  local VERSION=$1
  local FILE=$2

  local NODE="/usr/bin/node$VERSION"
  local GLOBAL_FLAGS="--expose_gc --expose-internals"

  local OUTPUT="/tmp/test_output"

  # Run the test (using custom flags if present) and save the output, print it only if it fails
  echo "Running $NODE $GLOBAL_FLAGS $FILE ${node_flags[$VERSION $FILE]}"
  $NODE $GLOBAL_FLAGS $FILE ${node_flags[$VERSION $FILE]} > $OUTPUT 2>&1
  if [ $? -ne 0 ]; then
    # Update global vars to track failed tests
    TEST_RESULT="failed"
    echo "Node v$VERSION Test $FILE" >> $FAILED_TEST_LIST
    # Print info about failure
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

  echo "Start testing node version $VERSION"
  zypper -n si -D "nodejs$VERSION" > /dev/null 2>&1
  zypper -n in --no-recommends "nodejs$VERSION" > /dev/null 2>&1


  local SOURCE_FILE
  SOURCE_FILE=$(cd /usr/src/packages/SOURCES/ && find . -type f -iname "node-v$VERSION*.tar.xz")
  SOURCE_FILE=${SOURCE_FILE:2} # strip ./ from name

  if [ -z "$SOURCE_FILE" ]
  then
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
  # Install dependencies to apply source patches
  zypper -n in quilt rpm-build > /dev/null 2>&1

  # Make sure there are at least 2 nodejs versions available
  ###############     List all node packages  | get only nodejsX or nodejsXX | filter out rest|   sort    | unique |   keep   only   number | count ###
  NUM_NODE_VERSIONS=$(zypper -n search nodejs | egrep -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | sort -h -r | uniq | tr -d ' '| tr -d 'nodejs'| wc -l)
  if (( NUM_NODE_VERSIONS < 2 )); then
    echo "Expected more than 2 nodejs versions available. Found $NUM_NODE_VERSIONS"
    exit 1
  fi

  # Run test for each nodejs version found
  NODE_VERSIONS=$(zypper -n search nodejs | egrep -i 'nodejs[0-9]{1,2} ' | cut -d'|' -f 2 | sort -h -r | uniq | tr -d ' '| tr -d 'nodejs')
  for v in $NODE_VERSIONS; do
    test_node_version $v
  done
    
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
  ["10 test/parallel/test-tls-cli-min-version-1.0.js"]="--tls-min-v1.0"
  ["10 test/parallel/test-tls-cli-min-version-1.1.js"]="--tls-min-v1.1"
  ["10 test/parallel/test-tls-cli-min-version-1.2.js"]="--tls-min-v1.2"
  ["10 test/parallel/test-tls-cnnic-whitelist.js"]="--use-bundled-ca"
  ["10 test/parallel/test-tls-dhe.js"]="--no-warnings"
  ["10 test/parallel/test-tls-legacy-deprecated.js"]="--no-warnings"
  ["10 test/parallel/test-tls-securepair-leak.js"]="--no-deprecation"
  ["10 test/parallel/test-crypto-dh-leak.js"]="--noconcurrent-recompilation"
)


# Use global variables to keep track if test some test fail and which one
FAILED_TEST_LIST="/tmp/failed_test_list"
TEST_RESULT="ok"

main

