# TOOL_s390_qethqoat

Testing the functionality of qethqoat command. This command is used to query the OSA address table and display physical and logical device information.

## Getting Started

The test case contains the following  scripts and configuration files:

- **10S_cleanup_qethqoat.sh** 			*basic script for cleaning the things up*
- **20S_prepare_qethqoat.sh** 			*script for preparation for the tests*
- **30S_test_qethqoat.sh**  	  		*script for the set of tests of the tool*
- **common.sh**   	            		*contains common functions which are used in various test cases*
- **qethoptGeneral** 				*configuration file which contains basic commands to verify*
- **x00_config-file_tool_s390_qethqoat**	*big configuration file which contains settings for the OSA cards and HS adapters of a particular test environment, as well as commands to verify*

## Prerequisites

z/VM guest must be prepared to be populated with SLES guest OS
all the files described above must be available on some local server via http to be fetched from zVM guest when ready.

## Installation

OpenQA deploys SLE onto a z/VM guest automatically.

## Running the tests

Transfer the scripts to the target system and run:

./10S_cleanup_qethqoat.sh

./20S_prepare_qethqoat.sh

./30S_test_qethqoat.sh

To run the test case using openQA, add `$TC_PATH` variable to download scripts, e.g.
TC_PATH="IP_ADDR/path_to_script_dir/"

## Versioning

Tested already on SLES12.3

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
