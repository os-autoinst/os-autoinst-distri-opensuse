# TOOL_s390_chzdev_lsdev

chzdev: Tool to modify the persistent configuration of devices and device drivers which are specific to the s390 platform.
lszdev: Tool to display the persistent configuration of devices and device drivers which are specific to the s390 platform.

## Getting started

The test case contains the following scripts:

- **09_WRITE_CONFIG.sh** _writes a new configuration File for all Devices needed in test_
- **100_CTC.sh** _CTC test_
- **10_Pre_Ipl_Tests.sh** _pre Ipl Tests and Preperation_
- **110_LCS.sh** _LCS test_
- **120_GCCW.sh** _GCCW test_
- **130_ZDEV_DPM.sh** _verifies that devices can be configured using the device pre-configurations on DPM LPARs_
- **130_ZDEV_DPM_CONFIG.sh** _device configurations_
- **200_Clean_Target.sh** _clean target system_
- **20_DASD.sh** _DASD test_
- **30_DASD_ECKD.sh** _DASD test_
- **40_DASD_FBA.sh** _DASD test_
- **50_ZFCP_H.sh** _ZFCP test_
- **60_ZFCP_L.sh** _ZFCP test_
- **70_ZFCP_HOST.sh** _ZFCP test_
- **80_ZFCP_LUN.sh** _ZFCP test_
- **90_QETH.sh** _QETH test_
- **CONFIG.sh** _configuration file_
- **omit** _provides list of tests to skip e.g: 20_DASD 50_ZFCP_H 120_GCCW_

## Prerequisites

Modify `CONFIG.sh` according to your test environment

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer test case to the target system and run:
`./200_Clean_Target.sh`
`./10_Pre_Ipl_Tests.sh`
`./20_DASD.sh`
`./30_DASD_ECKD.sh`
`./50_ZFCP_H.sh`
`./120_GCCW.sh`

## Versioning

Tested already on SLES12.3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
