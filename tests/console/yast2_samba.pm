# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST2 Samba functionality
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    # workaround kernel message floating over console
    assert_script_run "dmesg -n 4";

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    # install local ldap server

    if (is_sle && sle_version_at_least('15')) {
        my $ret = zypper_call('in yast2-auth-server openldap2-client tdb-tools', exitcode => [0, 104], timeout => 240);
        return record_soft_failure 'bsc#1060870' if $ret == 104;
    }

    zypper_call("in yast2-auth-server yast2-ldap openldap2 openldap2-client krb5-server krb5-client tdb-tools", timeout => 240);

    script_run("yast2 auth-server; echo yast2-auth-server-status-\$? > /dev/$serialdev ", 0);
    # check ldap server configuration started
    assert_screen([qw(yast2_ldap_configuration_startup yast2_still_susefirewall2)], 60);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure 'bsc#1064405';
        send_key 'alt-c';
    }
    send_key 'alt-f';

    assert_screen([qw(yast2_ldap_configuration_general-setting_firewall yast2_still_susefirewall2)], 60);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure 'bsc#1064405';
        send_key 'alt-e';
    }

    # configure stand-alone ldap server
    assert_screen 'yast2_ldap_configuration_stand-alone';
    send_key 'alt-n';

    assert_screen 'yast2_ldap_configuration_stand-alone_tls';
    # move to next page basic database settings and set base dn, ldap admin password
    wait_screen_change { send_key 'alt-n' };
    wait_screen_change { send_key 'alt-s' };
    type_string 'dc=qa, dc=suse, dc=de';
    wait_screen_change { send_key 'alt-a' };
    for (1 .. 20) { send_key 'backspace'; }
    type_string 'cn=admin';
    wait_screen_change { send_key 'alt-l' };
    type_string 'testing';
    wait_screen_change { send_key 'alt-v' };
    type_string 'testing';
    # use database as default for ldap client
    wait_screen_change { send_key 'alt-u' };
    send_key 'alt-n';
    assert_screen 'yast2_ldap_configuration_kerberos';
    wait_screen_change { send_key 'alt-x' };
    assert_screen 'yast2_ldap_configuration_summary';

    # finish ldap server configuration
    wait_screen_change { send_key 'alt-f' };
    wait_serial("yast2-auth-server-status-0") || die "'yast2 auth server' failed";
    assert_screen 'yast2_console-finished';

    # check ldap server status at first, a local ldap server is needed in the test case
    assert_script_run "systemctl show -p ActiveState slapd.service | grep ActiveState=active";

    # install samba stuffs at first
    zypper_call("in samba yast2-samba-server");

    # start samba server configuration
    script_run("yast2 samba-server; echo yast2-samba-server-status-\$? > /dev/$serialdev", 0);

    # check Samba-Server Configuration got started
    assert_screen([qw(yast2_samba_installation yast2_still_susefirewall2)], 60);
    if (match_has_tag 'yast2_still_susefirewall2') {
        send_key 'alt-c';
    }
    wait_screen_change { send_key 'alt-w' };
    for (1 .. 12) { send_key 'backspace'; }
    # give a new name for Workgroup
    type_string 'QA-Workgroup';
    assert_screen 'yast2_samba-server_workgroup_new';
    send_key 'alt-n';

    # select "Not a Domain Controller"
    assert_screen 'yast2_samba_server_selection';
    send_key 'alt-c';

    # check "Not a DC" is select
    assert_screen 'yast2_samba-server_not-a-dc_selected';
    send_key 'alt-n';
    wait_still_screen;
    # now move to Samba configuration and check enable service start during boot
    send_key 'alt-r';
    assert_screen 'yast2_samber-server_start-during-boot';

    # open port in firewall if it is enabled and check network interfaces, check long text by send key right.
    assert_screen 'yast2_samba_open_port_firewall';
    wait_screen_change { send_key 'alt-f' };
    send_key 'alt-i';

    assert_screen 'yast2_samba_firewall_port_details';
    wait_screen_change { send_key 'alt-e' };
    wait_screen_change { send_key 'alt-a' };
    wait_screen_change { send_key 'alt-o' };

    # switch to Samba Configuration - Shares
    send_key 'alt-s';
    assert_screen 'yast2_samba-server_shares';

    # add a shares config html_public
    wait_screen_change { send_key 'alt-a' };
    assert_screen 'yast2_samba-server_new-share';

    type_string 'html_public';
    wait_screen_change { send_key 'alt-a' };    # set share description
    type_string 'html docs for share';
    wait_screen_change { send_key 'alt-s' };
    type_string '/html_public';                 # set share path to /home/html_public
    wait_screen_change { send_key 'alt-r' };    # set read-only

    # check config before confirm new share with ok, confirm to create new share path
    assert_screen 'yast2_samba-server_new-share_create';
    wait_screen_change { send_key 'alt-o' };
    assert_screen 'yast2_samba-server_new-share-path';
    wait_screen_change { send_key 'alt-y' };

    # back to samba configuration and make some changes to share directories
    wait_screen_change { send_key 'alt-w' };    # allow users to share directories
    wait_screen_change { send_key 'alt-g' };    # allow guest access
    wait_screen_change { send_key 'alt-m' };
    for (1 .. 10) { send_key 'down'; }          # Maximum number of shares

    # switch to identity configuration
    send_key 'alt-d';
    assert_screen 'yast2_samba-server_identity';

    # use wins server support and check NetBIOS hostname Advanced settings
    wait_screen_change { send_key 'alt-i' };
    wait_screen_change { send_key 'alt-e' };
    type_string 'QA-Samba';
    send_key 'alt-v';
    assert_screen 'yast2_samba-server_identity_netbios_advanced_expert';
    send_key 'ret';
    assert_screen 'yast2_samba-server_netbios_name_change_warning';
    wait_screen_change { send_key 'alt-o' };

    # change logon drive to C:
    send_key_until_needlematch 'yast2_samba-server_netbios_logon-drive', 'down';
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'alt-l' };
    for (1 .. 5) { send_key 'backspace'; }
    type_string 'C:';
    wait_screen_change { send_key 'alt-o' };
    wait_screen_change { send_key 'alt-o' };

    # swith to Trusted Domains
    # add a trusted domain
    send_key 'alt-t';
    assert_screen 'yast2_samba-server_trusted-domains';
    wait_screen_change { send_key 'alt-a' };
    type_string 'suse.de';
    wait_screen_change { send_key 'alt-p' };
    type_string 'testing';
    send_key 'alt-o';
    assert_screen 'yast2_samba-server_trusted-domains_error';
    wait_screen_change { send_key 'alt-o' };

    # cancel trusted domain configuration
    wait_screen_change { send_key 'alt-c' };

    # swith to LDAP Settings
    send_key 'alt-l';
    assert_screen 'yast2_samba-server_ldap-settings';
    wait_screen_change { send_key 'alt-b' };
    assert_screen 'yast2_samba-server_ldap_value_rewritten';
    wait_screen_change { send_key 'alt-y' };
    wait_screen_change { send_key 'alt-e' };
    type_string 'ldap://localhost:389';

    # set admin password and search base dn
    wait_screen_change { send_key 'alt-a' };
    type_string 'cn=admin,dc=qa,dc=suse,dc=de';
    wait_screen_change { send_key 'alt-p' };
    type_string 'testing';
    wait_screen_change { send_key 'alt-g' };
    type_string 'testing';
    wait_screen_change { send_key 'alt-n' };
    type_string 'dc=qa, dc=suse, dc=de';

    # check advanced settings befor run test connection to ldap server
    wait_screen_change { send_key 'alt-v' };
    send_key 'ret';

    # enter expert ldap settings
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings';

    # change replication sleep and time-out
    wait_screen_change { send_key 'alt-p' };
    for (1 .. 10) { send_key 'down'; }
    wait_screen_change { send_key 'alt-t' };
    for (1 .. 2) { send_key 'up'; }

    # change to not use SSL or TLS
    wait_screen_change { send_key 'alt-u' };
    for (1 .. 2) { send_key 'up'; }
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings_not-use-ssl';
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'alt-o' };

    # now run test connection
    send_key 'alt-t';
    assert_screen 'yast2_samba-server_ldap_test-connection';
    wait_screen_change { send_key 'alt-o' };

    # finally, close with OK
    send_key 'alt-o';

    wait_serial('yast2-samba-server-status-0', 60) || die "'yast2 samba-server' didn't finish";

    # check samba server status
    assert_script_run("systemctl show -p ActiveState smb.service | grep ActiveState=active");
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
}

1;

# vim: set sw=4 et:
