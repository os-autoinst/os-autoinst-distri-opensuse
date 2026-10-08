# TOOL_s390_hyptop

Hyptop Tool: The Linux tool "hyptop" provides a dynamic real-time view of a System z hypervisor environment.
Depending on the available data it shows for example CPU and memory consumption of active LPARs or z/VM guests.
It provides a curses based user interface similar to the popular Linux "top" command.

Idea of this test case is to automate the verification of hyptop tool.

It divided into two phase:
- first phase is just checking the valid and invalid options for hyptop tool
- second phase verifies the output which hyptop tool produces.

Both can be merged into sigle test suite. But we are only able to verify the batch mode options.


## Getting Started

The test case contains one script:

- **hyptop.sh** *Basically the script just executes the hyptop tool with different parameters and verifies that output and exitcodes are as expected*

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS
hyptop.sh file must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.


## Running the tests

Transfer the scripts to the target system and run:

./hyptop.sh

To run the test case using openQA, add `$TC_PATH` variable to download scripts, e.g.
TC_PATH="IP_ADDR/path_to_script_dir/"

## Versioning

Tested already on SLES12.3

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
