# KERNEL_LSCPU_CHCPU
This testcase executes lscpu and chpu test scenarios.

## Getting started
The test case contains the following scripts:
- **lscpu_chcpu_kernel_parm.sh**  *kernel boot parameter test case*
- **test_chcpu.sh**  *chcpu test case*
- **test_lscpu.sh**  *lscpu test case*
- **test_lscpu_chcpu_invalid.sh**  *test case with invalid options of lscpu and chcpu*

## Prerequisites
z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.
Note: If you run this testcase on a native LPAR System, be sure to have 'Expanded storage' enabled in the LPAR 'Activation profile' of HMC

## Installation
OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests
Transfer test case to the target system and run:
`./test_lscpu.sh`
`./test_chcpu.sh`
`./test_lscpu_chcpu_invalid.sh`
`./lscpu_chcpu_kernel_parm.sh start`
`./lscpu_chcpu_kernel_parm.sh test1`
`./lscpu_chcpu_kernel_parm.sh test2`
reboot the system and run:
`./lscpu_chcpu_kernel_parm.sh check`
`./lscpu_chcpu_kernel_parm.sh test3`
`./lscpu_chcpu_kernel_parm.sh end`

## Versioning
Tested already on SLES12.3.

## License
The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
