# MEMORY_chmem
Switching on and off 256MB memory blocks in a randomized manner by using chmem -e and chmem -d

## Getting started
The test case contains the following scripts:
- **chmem.test.sh**  *script to do fix check for offline memory blocks*
- **checksum.chmemtest.sh**  *script to copy and check with md5sum*

## Prerequisites
z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.
Note: If you run this testcase on a native LPAR System, be sure to have 'Expanded storage' enabled in the LPAR 'Activation profile' of HMC

## Installation
OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests
Transfer test case to the target system and run:
`./chmem.test.sh`
`./checksum.chmemtest.sh`

## Versioning
Tested already on SLES12.3.

## License
The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
