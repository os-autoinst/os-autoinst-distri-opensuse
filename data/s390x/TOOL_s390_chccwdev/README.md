# TOOL_s390_chccwdev

Test script for setting devices online, offline via chccwdev in a loop (controlled by a parameter for short/long runs),
lscss is used to verify the results of chccwdev.

## Getting started

The test case contains nine different scripts:

- **ccwdev_list_create.sh** _creates device list_
- **chccwdev_main.sh** _verifies the functioning of CHCCWDEV Tool. Focus on chccwdev -e/-a/-d/-v on DASD, zfcp, qeth._
- **cleanup.sh** _clean up the test directory_
- **ipl_tools_common.sh** _setup environment for the test_
- **lib_soffline.sh** _checks fba and PAV/HYPER PAV_
- **lscss_common.sh** _checks tools like lscss and chccwdev_
- **safeoffline.sh** _safe offline tests_
- **safeoffline_1.sh** _safe offline advance tests_

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer test case to the target system and run:
`./chccwdev_main.sh <DASD1> <DASD2>`, e.g. chccwdev_main.sh aaaa bbbb
`./safeoffline.sh <DASD1> tbd`, e.g. safeoffline.sh aaaa tbd
To run test case using openQA, add `$DASD1`, `$DASD2`

## Versioning

Tested already on SLES12.3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
