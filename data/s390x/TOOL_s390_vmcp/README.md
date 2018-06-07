# TOOL_s390_vmcp

Allows Linux users to send commands to the z/VM control program (CP).
The normal usage is to invoke vmcp with the command you want to execute.

## Getting Started

The test case contains one shell script:

- **vmcp_main.sh**: *basically executes the vmcp tool with different parameters and verifies that
              output and exitcodes are as expected*

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run:

./vmcp_main.sh

To run the test case using openQA, put the script vmcp_main.sh into into the data folder on openQA server


## Versioning

Tested already on SLES 12 SP3

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
