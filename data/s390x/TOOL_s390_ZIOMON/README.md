# TOOL_s390_ZIOMON

Testing the functionality of ziomon tool.

**ziomon** - Collect FCP performance data on Linux on IBM Z.

The monitor tool ziomon collects information and details about:

    The FCP configuration
    The system I/O traffic through FCP adapters
    The overall I/O latencies, adapter latencies, and fabric latencies
    The usage of the FCP resources


## Getting Started

The test case contains the following scripts:
- **ziomon_basic.pl**  -  main script which runs the whole test
- **debugfs_mount.sh** -  auxiliary script for debugfs mounting
- **scsi_remove.sh**   -  script to remove scsi device
- **scsi_setup.sh**    -  script to add scsi device

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS
the above scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run:

./ziomon_basic.pl 0.0.AAAA 0xBBBBBBBBBBBBBBBB 0xCCCCCCCCCCCCCCCC

where
0.0.AAAA is FCP adapter ID
0xBBBBBBBBBBBBBBBB is target WWPN
0xCCCCCCCCCCCCCCCC is target LUN


To run the test case using openQA, add the following variables to the job command line:
 PARM_ADAPTER=0.0.AAAA PARM_WWPN=0xBBBBBBBBBBBBBBBB PARM_LUN=0xCCCCCCCCCCCCCCCC


## Versioning

Tested already on SLES 12 SP3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
