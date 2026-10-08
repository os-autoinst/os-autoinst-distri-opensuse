# TOOL_s390_kernel_1

cpuplugd: Daemon that manages CPU and memory resources based on a set of rules.
Depending on the workload CPUs can be enabled or disabled.
The amount of memory can be increased or decreased exploiting the Cooperative Memory Management (CMM1) feature.

## Getting started

The test case contains the following scripts:

- **cmm.conf** _configuration file_
- **cpu.conf** _configuration file_
- **cpuplugd.conf** _configuration file_
- **cpuplugd.sh** _verification of cpuplugd tool_
- **cpuplugdcmm.conf** _configuration file_
- **cpuplugdtemp.conf** _configuration file_
- **mon_fsstatd.sh** _mon tool tests_

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer test case to the target system and run locally:
`./cpuplugd.sh`
`./mon_fsstatd.sh`

## Versioning

Tested already on SLES12.3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
