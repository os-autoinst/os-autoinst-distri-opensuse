#! /bin/bash

function usage
{
  echo "Usage:" >&2
  echo "" >&2
  echo "  $1 testsuite [-i <identifier>] [-t <text>] [-h <hostname>]" >&2
  echo "      start test suite" >&2
  echo "" >&2
  echo "  $1 endsuite" >&2
  echo "      end test suite" >&2
  echo "" >&2
  echo "  $1 testcase [-i <identifier>] [-t <text>]" >&2
  echo "      start test case" >&2
  echo "" >&2
  echo "  $1 success" >&2
  echo "      end succesful test case" >&2
  echo "" >&2
  echo "  $1 failure [-T <type>] [-t <text>]" >&2
  echo "      end failed test case" >&2
  echo "" >&2
  echo "  $1 error [-T <type>] [-t <text>]" >&2
  echo "      end test case aborted due to internal error" >&2
  echo "" >&2
}

TIME=$(date +%Y-%m-%dT%H:%M:%S.%N | cut -c 1-23)
OUT="###junit $1 time=\"$TIME\""
HELPER=$(basename "$0")

case "$1" in
  "testsuite")
    shift
    while getopts "i:t:h:" OPT; do
      case "$OPT" in
        "i")
          OUT="$OUT id=\"$OPTARG\""
          ;;
        "t")
          OUT="$OUT text=\"$OPTARG\""
          ;;
        "h")
          OUT="$OUT host=\"$OPTARG\""
          ;;
        *)
          usage "$HELPER"
          exit 1
      esac
    done
    ;;
  "testcase")
    shift
    while getopts "i:t:" OPT; do
      case "$OPT" in
        "i")
          OUT="$OUT id=\"$OPTARG\""
          ;;
        "t")
          OUT="$OUT text=\"$OPTARG\""
          ;;
        *)
          usage "$HELPER"
          exit 1
      esac
    done
    ;;
  "endsuite"|"success")
    shift
    ;;
  "failure"|"error")
    shift
    while getopts "T:t:" OPT; do
      case "$OPT" in
        "T")
          OUT="$OUT type=\"$OPTARG\""
          ;;
        "t")
          OUT="$OUT text=\"$OPTARG\""
          ;;
        *)
          usage "$HELPER"
          exit 1
      esac
    done
    ;;
  *)
    usage "$HELPER"
    exit 1
esac

echo $OUT
