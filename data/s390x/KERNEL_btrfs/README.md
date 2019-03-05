# KERNEL_btrfs

Stress the btrfs filesystem and perform a minimum test on LPAR and z/VM.
This test case is testing basic functionality of btrfs. This was created on an early state of development of btrfs, for that reason it does not cover RAID5 support as this was not implemented at that time yet.
The test is using DASDs for test (at least 6). You can let it run in a loop - please specify with variable ITERATIONS. The test is using Blast - you might define the number of loops Blast is being executed.
The test case is setting the DASDs online, there is no need for other intervention (hopefully :-).
The test creates a RAID10 cluster, is tesiting readonly mode as well as creating/removing snapshots.

## Getting started

The test case contains the following script and tar:

- **btrfs.eckd.sh** _KERNEL_btrfs test case_

## Prerequisites

**The test case reuires minimum 6 DASDs!**
z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer test case to the target system and run:
`./btrfs.eckd.sh "XXXX XXXX XXXX XXXX XXXX XXXX"`
`XXXX` - DASD disk
To run test case using openQA, add `$DASD_LIST` with at least 6 space-separated DASDs.

## Versioning

Tested already on SLES12.3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
