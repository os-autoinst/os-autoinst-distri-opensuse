# File: azure_lib_fn.sh
# Description: Holds shared functions for azcli testing
# Funtions:
#   cmd_status: executes the given command and stores the status of the
#               execution in test_status array.
#   final_exit: create azure_cli testing report from test_status array.
#
# GLOBAL VARIABLES
declare -A TEST_STATUS
final_exit_status=0

##################################################################################
#Description: save pass/fail status result in global TEST_STATUS associative array
#Globals : TEST_STATUS
#Arguments : test_name and command
#Outputs: save pass/fail to TEST_STATUS array
#Errors: None
#Exits : when no parameter
##################################################################################
cmd_status()
{ 
 if (( $# < 0 )); then
    echo "illegal number of parameter"
    echo "Usage: cmd_status <test nameG> <test command>"
    echo "Example: cmd_status az_account_set az account set -s account"
    exit 0
 fi

 local test_name="${1}"
 shift 1 # consume the first argument
 echo "[Running test: '${test_name}' and command : '${@}']"
 "${@}"
 exit_status=$?
 if (( exit_status > 0 )); then
    echo EXIT_STATUS: ${exit_status}
    final_exit_status=1
 fi
TEST_STATUS[${test_name}]=${exit_status}
}

########################################################################
#Description: print azure_cli tests report status
#Arguments : none
#Outputs: Report cli command test status
########################################################################
cli_test_report()
{
tcmd=0
pcmd=0
fcmd=0
 for ind in "${!TEST_STATUS[@]}"
 do 
    let "tcmd+=1"
    if  (( ${TEST_STATUS[${ind}]} > 0 ))
    then
      echo "  Test ${ind} FAILED "
      let "fcmd+=1"
    else
      echo "  Test ${ind} Passed "
      let "pcmd+=1"
    fi
 done
echo "${tcmd} tests run, ${pcmd} tests passed and ${fcmd} failed"
exit $final_exit_status
}
