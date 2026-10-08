# TOOL_s390_CHCHP

Testing the functionality of lschp and chchp.

**chchp** - modify channel-path state.
The chchp command modifies the state of one or more channel-paths. Channel-path identifiers are specified in hexadecimal notation either simply as the CHPID-number (e.g. e0) or in the form

          <cssid>.<id>

where is the channel-subsystem identifier and is the CHPID-number (e.g. 0.7e). An operation can be performed on more than one channel-path by specifying multiple identifiers as a comma-separated list or a range or a combination of both.

Note that modifying the state of channel-paths can affect the availability of I/O devices as well as trigger associated functions (e.g. channel-path verification or device scanning) which in turn can result in a temporary increase in processor, memory and I/O load.

**lschp** - list information about available channel-paths.
The lschp command lists status and type information about available channel-paths.


## Getting Started

The test case contains the following scripts:

- **chchpmain.sh**		*script for testing chchp tool*
- **lschp-main.sh**		*script for testing lschp tool*

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run:

./lschp-main.sh

./chchpmain.sh 0.36

To run the test case using openQA, add `$TC_PATH` variable to download scripts, e.g.
TC_PATH="IP_ADDR/path_to_script_dir/"


## Versioning

Tested already on SLES 12 SP3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
