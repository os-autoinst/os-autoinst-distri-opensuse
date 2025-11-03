*** Settings ***
Documentation   Apply maintenance update and reboot.\n\n
...
...             This suite adds maintenance update repository *(MU repository)* on each system under test *(SUT)*\n\n
...             and preforms a reboot.\n\n
...             *Test settings* \n\n

Library  SSHLibrary
Library    OperatingSystem
Library    Collections
# This opens SSH connection to SUT and keeps it up during entire test suite progress
Suite Setup  Open SSH To SUT
Suite Teardown  Close All Connections
Test Tags   ${HOSTNAME}  IBSM  Maintenance Update  Azure  SDAF

*** Variables ***
${USERNAME}   azureadm
${REPO_MIRROR_HOST}  dist.suse.de

*** Test Cases ***
Test SSH tunnel
    [Documentation]  Test SSH command being executed on remote host.
    ${actual_hostname}=  Remote command   hostname
    Should Be Equal  ${actual hostname}  ${HOSTNAME}

Ping IBSm host '${REPO_MIRROR_HOST}' from '${HOSTNAME}'
    [Documentation]    Checks connection between SUT and IBSm mirror host using ping
    Remote command    ping -c3 -W1 ${REPO_MIRROR_HOST}

Check repository mirror '${INCIDENT_REPO}'
    [Documentation]    Verifies repository availability requesting 'repomd.xml' file.
    ${http_code}=  Remote command    curl -s -o /dev/null -w "\%{http_code}" "${INCIDENT_REPO}/repodata/repomd.xml"
    Should Be Equal As Integers  ${http_code}  200

Add Maintenance repository to SUT
    [Documentation]  Add and enable maintenance update repositories using zypper.
    ${repo_id}=  Get Repo ID  ${INCIDENT_REPO}
    Remote command    sudo zypper addrepo ${INCIDENT_REPO} ${repo_id}

Refresh all repositories
    [Documentation]  Refresh all repositories using zypper.
    Remote command    sudo zypper refresh

Apply all maintenance updates
    [Documentation]  Update system using zypper patch.
    Remote command   sudo zypper update -y

Remove Maintenance repository from SUT
    [Documentation]  Add and enable maintenance update repositories using zypper.
    ${repo_id}=  Get Repo ID  ${INCIDENT_REPO}
    Remote command    sudo zypper rr ${repo_id}

*** Keywords ***
Open SSH To SUT
    Enable Ssh Logging    ssh_debug_${HOSTNAME}.log
    Open Connection    ${HOST_IP}
    # Use the 'Login' keyword with the keyfile argument
    # If the key has a passphrase, include it as the third argument.
    Login With Public Key  ${USERNAME}  keyfile=${KEYFILE}
    ${rc}  ${output} =  Run And Return Rc And Output   hostname
    Log    CMD output: ${output}

Remote command
    [Documentation]  Executes command remotely using **SSHLibrary** keyword **Execute Command**
    [Arguments]  ${cmd}  ${expected_rc}=0  ${return_output}=1  ${return_rc}=0  ${quiet}=0
    # Execute command must be used here, the standard ones do not execute on remote host.
    ${output}  ${rc} =  Execute Command   ${cmd}  return_rc=True  return_stdout=True
    Should Be Equal As Integers    ${rc}  ${expected_rc}
    Log    CMD output: ${output}
    IF  ${return_rc}  RETURN  ${rc}  ELSE  RETURN  ${output}

Get Repo ID
    [Documentation]
    [Arguments]  ${repo_mirror}
    ${repo_id}=  Evaluate    re.search(r'Maintenance:\/(\\d+)\/', "${repo_mirror}").group(1)
    RETURN  ${repo_id}