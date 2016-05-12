# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;



sub run() {
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    # install local ldap server
    assert_script_run("/usr/bin/zypper -n -q in yast2-auth-server yast2-ldap openldap2 openldap2-client krb5-server krb5-client tdb-tools");

    script_run("/sbin/yast2 auth-server; echo yast2-auth-server-status-\$? > /dev/$serialdev", 0);
    # check ldap server configuration started
    assert_screen 'yast2_ldap_configuration_startup';
    send_key 'alt-f';
    assert_screen 'yast2_ldap_configuration_general-setting_firewall';
    wait_still_screen;
    send_key 'alt-e';

    # configure stand-alone ldap server
    assert_screen 'yast2_ldap_configuration_stand-alone';
    send_key 'alt-n';
    wait_still_screen;
    assert_screen 'yast2_ldap_configuration_stand-alone_tls';

    # move to next page basic database settings and set base dn, ldap admin password
    send_key 'alt-n';
    wait_still_screen;
    send_key 'alt-s';
    wait_still_screen;
    type_string 'dc=qa, dc=suse, dc=de';
    wait_still_screen;
    send_key 'alt-a';
    wait_still_screen;
    for (1 .. 20) { send_key 'backspace'; }
    type_string 'cn=admin';
    send_key 'alt-l';
    type_string 'testing';
    wait_still_screen;
    send_key 'alt-v';
    type_string 'testing';
    wait_still_screen;
    # use database as default for ldap client
    send_key 'alt-u';
    wait_still_screen;
    send_key 'alt-n';
    wait_still_screen;
    assert_screen 'yast2_ldap_configuration_kerberos';
    send_key 'alt-x';
    wait_still_screen;
    assert_screen 'yast2_ldap_configuration_summary';

    # finish ldap server configuration
    send_key 'alt-f';
    wait_still_screen;

    # check ldap server status at first, a local ldap server is needed in the test case
    assert_script_run "systemctl show -p ActiveState slapd.service | grep ActiveState=active";

    # install samba stuffs at first
    assert_script_run("/usr/bin/zypper -n -q in samba yast2-samba-server");

    # start samba server configuration
    script_run("/sbin/yast2 samba-server; echo yast2-samba-server-status-\$? > /dev/$serialdev", 0);

    # check Samba-Server Configuration got started
    assert_screen 'yast2_samba_installation';
    send_key 'alt-w';
    for (1 .. 12) { send_key 'backspace'; }
    # give a new name for Workgroup
    type_string 'QA-Workgroup';
    assert_screen 'yast2_samba-server_workgroup_new';
    send_key 'alt-n';

    # select "Not a Domain Controller"
    assert_screen 'yast2_samba_server_selection';
    send_key 'alt-p';
    wait_still_screen;
    send_key 'alt-a';
    wait_still_screen;
    send_key 'alt-c';

    # check "Not a DC" is select
    assert_screen 'yast2_samba-server_not-a-dc_selected';
    send_key 'alt-n';
    wait_still_screen;
    # now move to Samba configuration and check enable service start during boot
    send_key 'alt-r';
    assert_screen 'yast2_samber-server_start-during-boot';

    # open port in firewall if it is enabled and check network interfaces, check long text by send key right.
    if (assert_screen 'yast2_samba_open_port_firewall') {
        send_key 'alt-f';
        wait_still_screen;
        send_key 'alt-i';
        assert_screen 'yast2_samba_firewall_port_details';
        send_key 'alt-e';
        for (1 .. 5) { send_key 'right'; }
        send_key 'alt-a';
        send_key 'alt-o';
    }

    # switch to Samba Configuration - Shares
    send_key 'alt-s';
    assert_screen 'yast2_samba-server_shares';

    # add a shares config html_public
    send_key 'alt-a';
    assert_screen 'yast2_samba-server_new-share';
    send_key 'alt-n';
    type_string 'html_public';
    wait_still_screen;
    send_key 'alt-a';
    type_string 'html docs for share';

    # select share type as directory and give a new share path /home/html_public
    send_key 'alt-d';
    wait_still_screen;
    send_key 'alt-s';
    for (1 .. 8) { send_key 'backspace'; }
    type_string '/home/html_public';

    # set read-only and utilize brtfs features
    send_key 'alt-r';
    wait_still_screen;

    # check config before confirm new share with ok, confirm to create new share path
    assert_screen 'yast2_samba-server_new-share_create';
    send_key 'alt-o';
    if (assert_screen 'yast2_samba-server_new-share-path') { send_key 'alt-y'; }
    wait_still_screen;

    # back to samba configuration and make some changes to share directories
    send_key 'alt-w';
    wait_still_screen;
    send_key 'alt-g';
    for (1 .. 8) { send_key 'backspace'; }
    type_string 'windows_users';
    wait_still_screen;
    send_key 'alt-m';
    for (1 .. 10) { send_key 'down'; }

    # switch to identity configuration
    send_key 'alt-d';
    assert_screen 'yast2_samba-server_identity';

    # use wins server support and check NetBIOS hostname Advanced settings
    send_key 'alt-i';
    wait_still_screen;
    send_key 'alt-e';
    type_string 'QA-Samba';
    wait_still_screen;
    send_key 'alt-v';
    assert_screen 'yast2_samba-server_identity_netbios_advanced_expert';
    wait_still_screen;
    send_key 'ret';
    if (assert_screen 'yast2_samba-server_netbios_name_change_warning') { send_key 'alt-o'; }
    wait_still_screen;

    # change logon drive to C:
    send_key_until_needlematch 'yast2_samba-server_netbios_logon-drive', 'down';
    send_key 'ret';
    wait_still_screen;
    send_key 'alt-l';
    for (1 .. 5) { send_key 'backspace'; }
    type_string 'C:';
    send_key 'alt-o';
    wait_still_screen;
    send_key 'alt-o';
    wait_still_screen;

    # swith to Trusted Domains
    # add a trusted domain
    send_key 'alt-t';
    assert_screen 'yast2_samba-server_trusted-domains';
    send_key 'alt-a';
    send_key 'alt-d';
    type_string 'suse.de';
    wait_still_screen;
    send_key 'alt-p';
    type_string 'testing';
    wait_still_screen;
    send_key 'alt-o';
    wait_still_screen;
    assert_screen 'yast2_samba-server_trusted-domains_error';
    send_key 'alt-o';
    wait_still_screen;

    # cancel trusted domain configuration
    send_key 'alt-c';
    wait_still_screen;

    # swith to LDAP Settings
    send_key 'alt-l';
    assert_screen 'yast2_samba-server_ldap-settings';
    send_key 'alt-b';
    if (assert_screen 'yast2_samba-server_ldap_value_rewritten') { send_key 'alt-y'; }
    wait_still_screen;
    send_key 'alt-e';
    type_string 'ldap://localhost:389';
    wait_still_screen;

    # set admin password and search base dn
    send_key 'alt-a';
    wait_still_screen;
    type_string 'cn=admin,dc=qa,dc=suse,dc=de';
    wait_still_screen;
    send_key 'alt-p';
    wait_still_screen;
    type_string 'testing';
    wait_still_screen;
    send_key 'alt-g';
    type_string 'testing';
    wait_still_screen;
    send_key 'alt-n';
    wait_still_screen;
    type_string 'dc=qa, dc=suse, dc=de';

    # check advanced settings befor run test connection to ldap server
    wait_still_screen;
    send_key 'alt-v';
    wait_still_screen;
    send_key 'ret';
    wait_still_screen;

    # enter expert ldap settings
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings';

    # change replication sleep and time-out
    send_key 'alt-p';
    for (1 .. 10) { send_key 'down'; }
    send_key 'alt-t';
    wait_still_screen;
    for (1 .. 2) { send_key 'up'; }

    # change to not use SSL or TLS
    send_key 'alt-u';
    wait_still_screen;
    for (1 .. 2) { send_key 'up'; }
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings_not-use-ssl';
    send_key 'ret';
    wait_still_screen;
    send_key 'alt-o';

    # now run test connection
    wait_still_screen;
    send_key 'alt-t';
    wait_still_screen;
    assert_screen 'yast2_samba-server_ldap_test-connection';
    send_key 'alt-o';
    wait_still_screen;

    # finally, close with OK
    send_key 'alt-o';

    wait_serial('yast2-samba-server-status-0', 60) || die "'yast2 samba-server' didn't finish";

    # check samba server status
    assert_script_run("systemctl show -p ActiveState smb.service | grep ActiveState=active");

}
1;

# vim: set sw=4 et:
