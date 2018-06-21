# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
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
use version_utils qw(is_sle is_leap is_tumbleweed);
use y2logsstep;

my %ldap_directives = (
    fqdn                => 'openqa.ldaptest.org',
    dir_instance        => 'openqatest',
    dir_suffix          => 'dc=ldaptest,dc=org',
    dn_container        => 'dc=ldaptest,dc=org',
    dir_manager_dn      => 'cn=root',
    dir_manager_passwd  => 'openqatest',
    ca_cert_pem         => '/root/samba_ca_cert.pem',
    srv_cert_key_pkcs12 => '/root/samba_server_cert.p12'
);

my %samba_directives = (
    workgroup              => 'QA-Workgroup',
    comment                => 'html docs for share',
    path                   => '/home/html_public',
    usershare_max_shares   => '90',
    usershare_allow_guests => 'Yes',
    netbios_name           => 'QA-Samba',
    logon_drive            => 'C:',
    wins_support           => 'Yes',
    inherit_acls           => 'Yes',
    read_only              => 'Yes'
);

sub smb_conf_checker {
    my $error = "";
    # select global & add share sections
    my $select_script = get_test_data('console/yast2_samba_share_section_selection.sh');

    die 'Updated smb.conf section is missing' if script_run($select_script);
    foreach (sort keys %samba_directives) {
        (my $new_key = $_) =~ s/_/ /g;
        if (script_run("grep \"^$new_key [[:space:]]* = $samba_directives{$_}\$\" /tmp/smb.txt")) {
            $error .= "smb directive \"$new_key = $samba_directives{$_}\" not found in \/etc\/samba\/smb\.conf\n";
        }
    }

    if ($error ne "") {
        assert_script_run("echo \"$error\" > /tmp/failed_smb_directives.log");
        die 'Missing smb.conf directives';
    }
}

sub setup_yast2_ldap_server {
    my %ldap_options_to_dirs = (
        f => 'fqdn',
        i => 'dir_instance',
        t => 'dir_suffix',
        d => 'dir_manager_dn',
        r => 'dir_manager_passwd',
        e => 'dir_manager_passwd',
        s => 'ca_cert_pem',
        v => 'srv_cert_key_pkcs12'
    );

    assert_script_run 'wget ' . data_url('console/samba_ca_cert.pem');
    assert_script_run 'wget ' . data_url('console/samba_server_cert.p12');

    # setup FQDN hostname
    assert_script_run("hostname $ldap_directives{fqdn}");
    assert_script_run("echo \"127.0.0.1 $ldap_directives{fqdn} openqa\" > /etc/hosts");
    assert_script_run("echo \"$ldap_directives{fqdn}\" > /etc/hostname");

    script_run("yast2 ldap-server; echo yast2-ldap-server-status-\$? > /dev/$serialdev ", 0);

    # setup LDAP
    wait_still_screen(2);
    foreach (sort keys %ldap_options_to_dirs) {
        wait_screen_change { send_key "alt-$_" };
        type_string($ldap_directives{$ldap_options_to_dirs{$_}} . "\n");
    }
    assert_screen 'yast2_samba-389ds-setup';
    send_key "alt-o";
    # workaround for cert name issue
    assert_screen 'yast2_samba-389ds-setup-error-workaround', 90;
    send_key 'ret';
    wait_screen_change { send_key "alt-c" };
    die "'yast2 ldap-server' didn't finish with zero exit code" unless wait_serial("yast2-ldap-server-status-0");
    assert_script_run('certutil -d /etc/dirsrv/slapd-openqatest --rename -n "openqa.ldaptest.org - Suse" --new-n Server-Cert');
    systemctl 'start dirsrv@' . $ldap_directives{dir_instance};
    systemctl 'status dirsrv@' . $ldap_directives{dir_instance};
}

sub setup_ldap_in_samba {
    ## swith to LDAP Settings
    send_key 'alt-l';
    assert_screen 'yast2_samba-server_ldap-settings';
    send_key 'alt-b';
    assert_screen 'yast2_samba-server_ldap_value_rewritten';
    send_key 'alt-y';
    assert_screen 'yast2_samba-server_ldap_passwd_checked';
    send_key 'alt-e';
    type_string 'ldap://localhost:389';
    # set admin password and search base dn
    wait_screen_change { send_key 'alt-a' };
    type_string(is_sle('<15') ? $ldap_directives{dir_manager_dn} . ",$ldap_directives{dir_suffix}" : $ldap_directives{dir_manager_dn});
    wait_screen_change { send_key 'alt-p' };
    type_string($ldap_directives{dir_manager_passwd});
    wait_screen_change { send_key 'alt-g' };
    type_string($ldap_directives{dir_manager_passwd});
    wait_screen_change { send_key 'alt-n' };
    type_string($ldap_directives{dn_container});
    # check advanced settings befor run test connection to ldap server
    wait_screen_change { send_key 'alt-v' };
    send_key 'ret';
    # enter expert ldap settings
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings';

    ## expert ldap settings
    # change replication sleep and time-out
    wait_screen_change { send_key 'alt-p' };
    type_string "990\n";
    wait_screen_change { send_key 'alt-t' };
    type_string "7\n";

    # change to not use SSL or TLS
    wait_screen_change { send_key 'alt-u' };
    send_key 'up';
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings_not-use-ssl';
    send_key 'ret';
    wait_screen_change { send_key 'alt-o' };

    # now run test connection
    send_key 'alt-t';
    assert_screen 'yast2_samba-server_ldap_test-connection';
    wait_screen_change { send_key 'alt-o' };
}

sub setup_samba {
    script_run("yast2 samba-server; echo yast2-samba-server-status-\$? > /dev/$serialdev", 0);

    # samba-server configuration for SLE older than 15 or opensuse TW
    assert_screen([qw(yast2_samba_installation yast2_still_susefirewall2)], 60);
    if (match_has_tag 'yast2_still_susefirewall2') {
        send_key 'alt-c';
    }

    wait_screen_change { send_key 'alt-w' };
    for (1 .. 12) { send_key 'backspace'; }
    # give a new name for Workgroup
    type_string($samba_directives{workgroup});
    assert_screen 'yast2_samba-server_workgroup_new';
    send_key 'alt-n';

    ## Handle Domain Controller in sle12
    if (is_sle('<15') || is_leap('<15.0')) {
        # select "Not a Domain Controller"
        assert_screen 'yast2_samba_server_selection';
        send_key 'alt-c';

        # check "Not a DC" is select
        assert_screen 'yast2_samba-server_not-a-dc_selected';
        send_key 'alt-n';
    }

    # service starts during boot, wait to load default data
    assert_screen 'yast2_samba-startup-configuration';
    send_key 'alt-r';
    assert_screen 'yast2_samba-server_start-during-boot';
    # open firewalld port
    send_key 'alt-f';
    assert_screen 'yast2_samba_open_port_firewall';

    ## switch to Samba Configuration - Shares
    send_key 'alt-s';
    wait_still_screen(2);
    assert_screen 'yast2_samba-server_shares';
    # add a shares config html_public
    send_key 'alt-a';
    assert_screen 'yast2_samba-server_new-share';
    # enter share details
    send_key 'alt-n';
    type_string('html_public');
    wait_screen_change { send_key 'alt-a' };    # set share description
    type_string($samba_directives{comment});
    wait_screen_change { send_key 'alt-s' };
    for (1 .. 5) { send_key 'backspace'; }
    type_string($samba_directives{path});       # set share path to /home/html_public
    send_key 'alt-r';                           # set read-only

    # check config before confirm new share with ok, confirm to create new share path
    assert_screen 'yast2_samba-server_new-share_create';
    send_key 'alt-o';
    assert_screen 'yast2_samba-server_new-share-path';
    send_key 'alt-y';                           # confirm new path

    # back to samba configuration and make some changes to share directories
    assert_screen 'yast2_samba-added_html_share';
    send_key 'alt-w';                           # allow users to share directories
    wait_screen_change { send_key 'alt-g' };    # allow guest access
    send_key 'alt-m';
    type_string($samba_directives{usershare_max_shares} . "\n");    # Maximum number of shares

    ## switch to identity configuration
    send_key 'alt-d';
    assert_screen 'yast2_samba-server_identity';

    ## domain controller in sle15
    # select "Not a Domain Controller"
    if (is_sle('>=15') || is_leap('>=15.0') || is_tumbleweed) {
        wait_screen_change { send_key 'alt-a' };
        send_key 'ret';
        # check "Not a DC" is select
        assert_screen 'yast2_samba-server_not-a-dc_selected';
    }

    # use wins server support and check NetBIOS hostname Advanced settings
    wait_screen_change { send_key 'alt-i' };
    wait_screen_change { send_key 'alt-e' };
    type_string($samba_directives{netbios_name});
    send_key 'alt-v';
    assert_screen 'yast2_samba-server_identity_netbios_advanced_expert';
    send_key 'ret';
    assert_screen 'yast2_samba-server_netbios_name_change_warning';
    wait_screen_change { send_key 'alt-o' };
    # change logon drive to C:
    send_key_until_needlematch 'yast2_samba-server_netbios_logon-drive', 'down';
    wait_screen_change { send_key 'ret' };
    for (1 .. 2) { send_key 'backspace'; }
    type_string($samba_directives{logon_drive});
    wait_screen_change { send_key 'alt-o' };
    send_key 'alt-o';

    ## swith to Trusted Domains
    # add a trusted domain, wait while all data is properly loaded
    wait_still_screen(2);
    send_key 'alt-t';
    assert_screen 'yast2_samba-server_trusted-domains';
    wait_screen_change { send_key 'alt-a' };
    type_string('suse.de');
    wait_screen_change { send_key 'alt-p' };
    type_string('testing');
    send_key 'alt-o';
    assert_screen 'yast2_samba-server_trusted-domains_error';
    wait_screen_change { send_key 'alt-o' };
    assert_screen 'yast2_samba-server_trusted-domains_cancel_configuration';
    wait_screen_change { send_key 'alt-c' };

    #setup samba
    setup_ldap_in_samba;

    # finally, close with OK
    send_key 'alt-o';
    wait_serial('yast2-samba-server-status-0', 60) || die "'yast2 samba-server' didn't finish";
}

sub setup_yast2_auth_server {
    # workaround kernel message floating over console
    assert_script_run "dmesg -n 4";
    record_soft_failure 'bsc#1011815';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # SLE12SP4 still uses old yast2-auth-server-3.1.18, which does not contain ldap-server.rb
    script_run("yast2 auth-server; echo yast2-auth-server-status-\$? > /dev/$serialdev ", 0);

    #confirm offered rpms to install
    assert_screen('yast2_install_packages');
    send_key 'ret';

    # check ldap server configuration started
    assert_screen([qw(yast2_ldap_configuration_startup yast2_still_susefirewall2)], 60);

    # only older version like SLES 12, Leap 42.3 as well as TW should still check the needle
    assert_screen 'yast2_ldap_configuration_general-setting_firewall', 60;
    send_key 'alt-e';

    # configure stand-alone ldap server
    assert_screen 'yast2_ldap_configuration_stand-alone';
    send_key 'alt-n';

    assert_screen 'yast2_ldap_configuration_stand-alone_tls';
    # move to next page basic database settings and set base dn, ldap admin password
    wait_screen_change { send_key 'alt-n' };
    wait_screen_change { send_key 'alt-s' };
    type_string($ldap_directives{dn_container});
    wait_screen_change { send_key 'alt-a' };
    for (1 .. 20) { send_key 'backspace'; }
    type_string($ldap_directives{dir_manager_dn});
    wait_screen_change { send_key 'alt-l' };
    type_string($ldap_directives{dir_manager_passwd});
    wait_screen_change { send_key 'alt-v' };
    type_string($ldap_directives{dir_manager_passwd});
    # use database as default for ldap client
    wait_screen_change { send_key 'alt-u' };
    send_key 'alt-n';
    assert_screen 'yast2_ldap_configuration_kerberos';
    send_key 'alt-x';
    assert_screen 'yast2_ldap_configuration_summary';

    # finish ldap server configuration
    send_key 'alt-f';
    wait_serial("yast2-auth-server-status-0") || die "'yast2 auth server' failed to finish";
    assert_screen 'yast2_console-finished';
    # check ldap server status at first, a local ldap server is needed in the test case
    systemctl "show -p ActiveState slapd.service | grep ActiveState=active";
}

sub run {
    select_console 'root-console';
    zypper_call('in samba yast2-samba-server yast2-auth-server');

    # setup ldap instance (openldap or 389-ds) for samba
    if (is_sle('<15') || is_leap('<15.0')) {
        setup_yast2_auth_server;
    }
    else {
        # dirsrv@openqa cannot be restarted due to dependency issues
        record_soft_failure "bsc#1088152";
        setup_yast2_ldap_server;
    }
    setup_samba;
    # check samba server status
    # samba doesn't start up correctly on TW, so add record soft failure here
    if (script_run('systemctl show -p ActiveState smb.service | grep ActiveState=active')) {
        record_soft_failure "bsc#1068900";
    }
    smb_conf_checker;
    set_hostname(get_var('HOSTNAME', 'susetest'));
}

sub post_fail_hook {
    my $self = shift;
    $self->save_upload_y2logs();
    upload_logs('/etc/samba/smb.conf');
    upload_logs('/tmp/failed_smb_directives.log');
}

1;
