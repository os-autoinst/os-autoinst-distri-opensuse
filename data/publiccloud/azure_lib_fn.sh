##################################################################################
# File: azure_lib_fn.sh
# Description: Holds shared functions for azcli testing
# Functions:
#   cmd_status: executes the given command and stores the status of the
#               execution in test_status array.
#   cli_test_report: create azure_cli testing report from test_status array.
##################################################################################

# GLOBAL VARIABLES
# TEST_STATUS stores testname and pass/fail status
declare -A TEST_STATUS

##################################################################################
# Globals : TEST_STATUS
# Description: save pass/fail status result in global TEST_STATUS associative array
# Arguments : test_name and command
# Outputs: save pass/fail to TEST_STATUS array
#          prints test name and test command
# Errors: None
# Exits : when passed fewer than two parameter
##################################################################################
cmd_status()
{ 
 if (( $# < 2 )); then
    echo "illegal number of parameter"
    echo "Usage: cmd_status <test nameG> <test command>"
    echo "Example: cmd_status az_account_set az account set -s account"
    exit 0
 fi

 local test_name="${1}"
 shift 1 # consume the first argument
 echo "[Running test: '${test_name}' and command : '${@}']"
 # Executing command 
 "${@}"
 exit_status=$?
 TEST_STATUS[${test_name}]=${exit_status}
}

########################################################################
# Description: print azure_cli tests report status
# Globals : TEST_STATUS
# Arguments : none
# Outputs: Report cli command test status
# Errors: None
# Exits : 0 if all test pass
#         1 if any test fails
########################################################################
cli_test_report()
{
tcmd=0
pcmd=0
fcmd=0
final_exit_status=0
 for ind in "${!TEST_STATUS[@]}"
 do 
    let "tcmd+=1"
    if  (( ${TEST_STATUS[${ind}]} > 0 ))
    then
      echo "  Test ${ind} FAILED "
      let "fcmd+=1"
      final_exit_status=1
    else
      echo "  Test ${ind} Passed "
      let "pcmd+=1"
    fi
 done
echo "${tcmd} tests run, ${pcmd} tests passed and ${fcmd} failed"
exit ${final_exit_status}
}
