# TOOL_s390_qetharp

Testing the functionality of qetharp tool.

**qetharp** - querying and modifying ARP data.


       qetharp queries ARP data, such as MAC and IP addresses, from an OSA hardware ARP cache or a HiperSockets ARP cache. For OSA hardware, qetharp can also modify the cache.

       The command applies only to devices in layer3 mode. It supports IPv6 for HiperSockets only.


## Getting Started

The test case contains the following scripts:
- **10S_cleanup_s390_qetharp.sh** *cleanup script to clean the system after any previous runs*
- **20S_prepare_s390_qetharp.sh** *preparation for the planned execution*
- **30S_qetharp_test.sh**  	  *the test suite itself*
- **40S_Ping_Test.sh** 		  *test with sending pings to neigbour LPAR*

And the configuration file which must be filled with the actual environment data, OSA and hipersocket adapter ids and so on
- **00_config-file_TOOL_s390_qetharp**

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS
the above scripts must be available on some local server via http to be fetched from zVM guest when ready.

an LPAR must be prepared and configured with the IP address which is defined in the config file as cE1ip and cE2ip

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run them sequentially:
./10S_cleanup_s390_qetharp.sh

./20S_prepare_s390_qetharp.sh

./30S_qetharp_test.sh

./40S_Ping_Test.sh


To run the test case using openQA, add `$TC_PATH` variable to download scripts, e.g.
TC_PATH="IP_ADDR/path_to_script_dir/"


## Versioning

Tested already on SLES 12 SP3.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
