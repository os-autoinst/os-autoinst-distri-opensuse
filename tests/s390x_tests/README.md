# TOOL_s390_kernel_1
cpuplugd: Daemon that manages CPU and memory resources based on a set of rules.
Depending on the workload CPUs can be enabled or disabled.
The amount of memory can be increased or decreased exploiting the Cooperative Memory Management (CMM1) feature.

## Getting started
The test case contains the following scripts:
- **cmm.conf**  *configuration file*
- **common.sh**  *set of functions for running tests and analyzing results*
- **cpu.conf**  *configuration file*
- **cpuplugd.conf**  *configuration file*
- **cpuplugd.sh**  *verification of cpuplugd tool*
- **cpuplugdcmm.conf**  *configuration file*
- **cpuplugdtemp.conf**  *configuration file*
- **mon_fsstatd.sh**  *mon tool tests*

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
