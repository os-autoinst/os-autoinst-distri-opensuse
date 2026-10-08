# TOOL_s390_vmconvert

On z/VM : - Testing vmconvert, vmdump, vmur and lcrash a little bit
This test works with virtual unit record devices, is setting them online, then it purges all files from the z/VM reader. It creates a guest machine dump on the z/VM reader. It converts the dump using vmconvert and copies the dump to the Linux filesystem. It proves that the dump is valid by trying a few crash commands. It also converts a dump using vmur with the -c option. Finally it tries a few option of vmconvert (this was an outcome of code coverage analysis of vmconvert.

## Getting started

The test case contains the following scripts:

- **vmcon.sh** _vmconvert test case_

## Prerequisites

Make sure VM has enough memory.
Make sure system repository contains `kernel-default-debuginfo` package.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer test case to the target system and run:
`./vmcon.sh`

## Versioning

Tested already on SLES12.3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
