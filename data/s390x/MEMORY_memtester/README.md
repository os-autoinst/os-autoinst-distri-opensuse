# MEMORY_memtester
On LPAR and z/VM:
- Prepare memtester
- Run memtester with specified parameters
- 70% - 80% of max. main memory of a system is a good choice
- n loops result in n times the runtime (calculated with loop = 1)
- m times memory usage result in m times the runtime

## Getting started
The test case contains the following script and tar:

- **runMemtester.sh**  *Memtester runner*
- **memtester-4.1.3.tar.gz** *Memtester tar*

## Prerequisites
z/VM guest must be prepared to be populated with SLES guest OS, all scripts must be available on some local server via http to be fetched from zVM guest when ready.

## Installation
OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests
Transfer test case to the target system and run:
`tar -xzf memtester*tar.gz && rm -rf memtester*tar.gz`
`cd memtester*&& make && make install`
`./runMemtester.sh <memory> <loops>`, e.g. ./runMemtester.sh 800M 100
`rm -f /usr/bin/memtester; rm -rf /root/MEMORY_memtester`

## Versioning
Tested already on SLES12.3.

## License
The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
