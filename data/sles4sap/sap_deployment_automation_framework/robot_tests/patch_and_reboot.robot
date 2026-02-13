*** Settings ***
Documentation   Apply maintenance patches and reboot.
...
...     = Maintainer =
...     QE-SAP <qe-sap@suse.de>
...
...     = Suite description: =
...     This suite adds maintenance update repository *(MU repository)* on each system under test *(SUT)* and preforms a reboot.
...
...     = Suite settings =
...
...         - *HOSTNAME* : SUT hostname
...         - *KEYFILE* : SSH keyfile path
...         - *USERNAME* : (optional) SUT SSH Username. Default: azureadm
...         - *REPO_MIRROR_HOST* : (optional) IBSm FQDN. Default: dist.suse.de
...         - *INCIDENT_REPO* : IBSm maintenance update repository

Library  SSHLibrary
Library  OperatingSystem
Library  Collections
Library  XML
Test Timeout  600
Suite Setup  Open SSH To SUT
Suite Teardown  Close All Connections
Test Tags   ${HOSTNAME}  IBSM  Maintenance Update  Azure  SDAF

*** Variables ***
${USERNAME}   azureadm
${REPO_MIRROR_HOST}  dist.suse.de
${REPO_ID}  ${EMPTY}
${ZYPPER_PATCH_CMD}  sudo zypper patch -y --with-interactive -l --with-optional timeout=600

*** Test Cases ***
Test SSH tunnel
    [Documentation]  Test SSH command being executed on correct SUT by comparing suite setting \${HOSTNAME} against actual hostname.
    ${actual_hostname}=  Remote Command   hostname
    Should Be Equal  ${actual hostname}  ${HOSTNAME}

Ping IBSm host '${REPO_MIRROR_HOST}' from '${HOSTNAME}'
    [Documentation]    Checks connection between SUT and IBSm mirror host using ping
    Remote Command    ping -c3 -W1 ${REPO_MIRROR_HOST}

Check repository mirror '${INCIDENT_REPO}'
    [Documentation]    Verifies repository availability requesting 'repomd.xml' file.
    ${http_code}=  Remote Command    curl -s -o /dev/null -w "\%{http_code}" "${INCIDENT_REPO}/repodata/repomd.xml"
    Should Be Equal As Integers  ${http_code}  200

Make system up to date without maintenance repositories
    [Documentation]  Bring system up to date with officially released updates only.
    Remote Command   sudo zypper refresh  timeout=300
    ${zypper_xml}=  Remote Command    zypper --xmlout lu  quiet=1
    ${pending_updates}=  Zypper Get Updates  ${zypper_xml}
    ${zypper_update}=  Get Match Count    ${pending_updates}    zypper
    IF    ${zypper_update}
        Log  Zypper update available
        Remote Command   ${ZYPPER_PATCH_CMD}
    END
    Remote Command   ${ZYPPER_PATCH_CMD}
    Reboot And Connect

Apply all maintenance updates and reboot
    [Documentation]  Add maintenance update repository, patch the system and reboot.
    ${repo_id}=  Get Repo ID  ${INCIDENT_REPO}
    Log    Indicent repository ID: ${repo_id}
    Set Suite Variable    ${REPO_ID}  ${repo_id}
    Remote Command   sudo zypper addrepo ${INCIDENT_REPO} ${REPO_ID}
    Remote Command   sudo zypper refresh  timeout=300
    Remote Command   ${ZYPPER_PATCH_CMD}
    Reboot And Connect

Remove maintenance repository
    [Documentation]  Remove maintenance repository
...     Removing repository will prevent zypper failure after IBSm peering is torn down and repository is not available anymore
    Remote Command   sudo zypper removerepo ${REPO_ID}
    Remote Command   sudo zypper refresh  timeout=300

*** Keywords ***
Open SSH To SUT
    [Timeout]  10
    [Documentation]  Opens SSH connection to sut (_\${HOSTNAME}:\${HOST_IP}_) and logs in as _\${USERNAME}_ using SSH keyfile _\${KEYFILE}_
    Enable Ssh Logging    ssh_debug_${HOSTNAME}.log
    Open Connection    ${HOST_IP}
    Login With Public Key  ${USERNAME}  keyfile=${KEYFILE}
    ${rc}  ${output} =  Run And Return Rc And Output   hostname
    Log    CMD output: ${output}

Remote Command
    [Documentation]  Executes command remotely using **SSHLibrary** keyword **Execute Command**
...     = Arguments =
...     *cmd:* Command to be executed
...     *expected_rc:*  Expected command return code. If undefined, there will be no assertion done.
...     *return_output:* Function will return command output. Default: true
...     *return_rc:* Function will return command exit code only. Default: false
...     *quiet:* No logging is done.
...     *timeout:* Command timeout. Test will fail if command does not finish within timeout limit.
    [Arguments]  ${cmd}  ${expected_rc}=${None}  ${return_output}=1  ${return_rc}=0  ${quiet}=${None}  ${timeout}=90
    # Execute command must be used here, the standard ones do not execute on remote host.
    ${output}  ${rc} =  Execute Command   ${cmd}  return_rc=True  return_stdout=True  timeout=${timeout}
    IF  ${expected_rc}  Should Be Equal As Integers    ${rc}  ${expected_rc}
    IF  not $quiet or str($quiet) == "0"  Log    CMD output: ${output}
    IF  ${return_rc}  RETURN  ${rc}  ELSE  RETURN  ${output}

Get Repo ID
    [Documentation]  Function extracts and returns repository ID from repository URL.
...     = Arguments =
...     *repo_mirror:* Repository mirror URL
    [Arguments]  ${repo_mirror}
    ${repo_id}=  Evaluate    re.search(r'Maintenance:\/(\\d+)\/', "${repo_mirror}").group(1)
    RETURN  ${repo_id}

Reboot And Connect 
    [Documentation]  Reboots host and reconnects back the console. Test fails after number of retries
...     = *Arguments* =
...     *retries:* Repository mirror URL
...     *retry_delay:* Repository mirror URL
    [Arguments]  ${retries}=12  ${retry_delay}=20
    Set Client Configuration    timeout=300s
    Write  sudo shutdown -r +1
    Write    sudo tail -f /var/log/messages
    ${output}=  Read Until Regexp  reboot
    Log    ${output}
    Sleep    30
    Wait Until Keyword Succeeds    ${retries}x    ${retry_delay}s    Open SSH To SUT

Zypper Get Updates
    [Documentation]  Parses zypper xml output and returns list of packages with new pending updates
...     = *Arguments* =
...     *zypper_xml:* Output from zypper in XML format (--xmlout argument).
    [Arguments]  ${zypper_xml}
    ${parsed_xml}=  Parse XML    ${zypper_xml}
    ${packages}=  Create List
    ${update_elements}=  Get Elements  ${parsed_xml}  .//update

    FOR  ${element}  IN  @{update_elements}
        ${package_name}=  Get Element Attribute    ${element}    name
        Append To List  ${packages}  ${package_name}
    END
    RETURN  ${packages}

