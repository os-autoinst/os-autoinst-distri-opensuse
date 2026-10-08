# TOOL_s390_fcp

Testing the functionality of various tools for handling FCP tasks.


## Getting Started

The test case contains the following scripts:
- **fcp_test_rc.sh** *the main script which prepares things and runs all other scripts*
- **lsluns_rc.sh** *script for testing lsluns tool functionality*
- **lsscsi_rc.sh** *script for testing lsscsi tool functionality*
- **lszfcp_rc.sh** *script for testing lszfcp tool functionality*
- **scsi_logging_level_rc.sh** *script for testing scsi logging*
- **zfcpdbf_rc.sh** *script for testing zfcpdbf*

All scripts must be placed in the same folder.

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS
the above scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run:

  ./fcp_test_rc.sh $ADAPTER $WWPN $LUN

where ADAPTER, WWPN and LUN are the parameters to access a  LUN to run the test with.

To run the test case using openQA, put the scripts as TOOL_s390_fcp.tgz file into the data folder on openQA server


## Versioning

Tested already on SLES 12 SP3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
