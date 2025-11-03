*** Settings ***
Library  SSHLibrary
Library    OperatingSystem
# This opens SSH connection to SUT and keeps it up during entire test suite progress
Suite Setup  Open SSH To SUT
Suite Teardown  Close All Connections

*** Variables ***
${USERNAME}   azureadm
${REPO_MIRROR_HOST}  dist.suse.de

*** Keywords ***
Open SSH To SUT
    Enable Ssh Logging    ssh_debug_${HOSTNAME}.log
    Open Connection    ${HOST_IP}
    # Use the 'Login' keyword with the keyfile argument
    # If the key has a passphrase, include it as the third argument.
    Login With Public Key  ${USERNAME}  keyfile=${KEYFILE}
    ${rc}  ${output} =  Run And Return Rc And Output   hostname
    Log    CMD output: ${output}

Assert Script Run
    [Arguments]  ${cmd}  ${expected_rc}=0
    # Execute command must be used here, the standard ones do not execute on remote host.
    ${output}  ${rc} =  Execute Command   ${cmd}  return_rc=True  return_stdout=True
    Should Be Equal As Integers    ${rc}  ${expected_rc}
    Log    CMD output: ${output}


*** Test Cases ***
Test SSH tunnel
    [Documentation]  Test SSH command being executed on remote host.
    Assert Script Run   hostname

Ping IBSm host '${REPO_MIRROR_HOST}' from '${HOSTNAME}'
    [Documentation]    Checks connection between SUT and IBSm mirror host using ping
    Assert Script Run    ping -c3 -W1 ${REPO_MIRROR_HOST}
    Assert Script Run    hostname

#Add Maintenance repositories to SUT
#    [Documentation]  Add and enable maintenance update repositories using zypper.
#    ${rc}  ${output} =  Run And Return Rc And Output   sudo zypper addrepo

Refresh all repositories
    [Documentation]  Refresh all repositories using zypper.
    Assert Script Run    sudo zypper refresh
    Assert Script Run    hostname

#Apply all maintenance updates
#    [Documentation]  Update system using zypper patch.
#    Assert Script Run   sudo zypper update -y
#
