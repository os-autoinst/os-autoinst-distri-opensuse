# DASD_LVM_Regression
This test case can be used to test basic LVM functionalities like:
Case 1: Check return code of LVM commands
Case 2: Test Basic Functions of LVM (pvcreate, vgcreate, lvcreate, vgdisplay, vgscan, pvdisplay, pvscan, lvscan,lvremove, vgremove, pvremove) using DASD/SCSI
Case 3: Perform LVM resizing ( Resize: pvresize, vgreduce, vgextend, lvextend, lvreduce )
Case 4: Setup all types of LVM and Perform IO stress test:
- Linear logical volume
- Striped logical volume
- Mirrored logical volume

Case 5: Test parallel snapshot and compare
Test can be performed for LPARs and VM guests. Required DASD will be attached/online devices will be created as well as formating and mounting to the system is done by scripts itself (not used dynamic resource file)

Steps:
1. DASDs will be attached to system
2. required scripts and programms will be downloaded to testsystem
3. DASD devices will be created, formated and mounted automatically
4. Physical volumes are created out of the devices and use to create volume groups and from each volume groups a logical volume is created and mounted
5. I/O will be started automatically (warming up for 5min)
6. Unmount lvm, remove the basic lvm setup, remove volume groups and remove physical volumes.
7. Setup a detailed stress test lvm setup with all types of lvm and start stress test for specified hrs in regman

## Getting started
The test case contains the following scripts:

- **00_LVM_TOOLS.sh**  *LOGICAL VOLUME MANAGER TOOLS*
- **01_LVM_Basic_test.sh**  *LOGICAL VOLUME MANAGER*
- **02_LVM_Resize_test.sh**  *LVM RESIZE TEST*
- **03_LVM_Types_stress.sh**  *LVM Linear, Striped & Mirrored test*
- **04_LVM_snapshot_backup.sh** *LVM Snapshot & backup test*
- **export_variables.sh**  *export variables*

## Prerequisites
z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation
OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests
Transfer test case to the target system and run:
`./01_LVM_Basic_test.sh <BASE_PAV> <ALIAS_PAV>`, e.g. ./01_LVM_Basic_test.sh AAA1-AAA3 BBB1-BBB3
`./02_LVM_Resize_test.sh`
`./03_LVM_Types_stress.sh`
`./04_LVM_snapshot_backup.sh`
To run test case using openQA, add `$BASE_PAV`, `$ALIAS_PAV`

## Versioning
Tested already on SLES12.3.

## License
The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
