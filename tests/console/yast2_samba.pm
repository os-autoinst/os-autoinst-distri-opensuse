# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: samba yast2-samba-server yast2-auth-server
# Summary: YaST2 Samba functionality
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "y2_module_consoletest";

use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed is_opensuse);
use yast2_widget_utils 'change_service_configuration';

my %ldap_directives = (
    fqdn => 'openqa.ldaptest.org',
    dir_instance => 'openqatest',
    dir_suffix => 'dc=ldaptest,dc=org',
    dn_container => 'dc=ldaptest,dc=org',
    dir_manager_dn => 'cn=Directory Manager',
    dir_manager_passwd => 'openqatest',
    ca_cert_pem => '/root/samba_ca_cert.pem',
    srv_cert_key_pkcs12 => '/root/samba_server_cert.p12'
);

my %samba_directives = (
    workgroup => 'QA-Workgroup',
    comment => 'html docs for share',
    path => '/home/html_public',
    usershare_max_shares => '90',
    usershare_allow_guests => 'Yes',
    netbios_name => 'QA-Samba',
    logon_drive => 'C:',
    wins_support => 'Yes',
    inherit_acls => 'Yes',
    read_only => 'Yes'
);

sub smb_conf_checker {
    my $error = "";
    # Select global & add share sections
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
        return record_soft_failure "bsc#1106876 - Missing smb.conf directives" if (is_sle('>=15') || is_opensuse);
        die 'Missing smb.conf directives';
    }
}

sub setup_yast2_ldap_server {
    my %ldap_options_to_dirs = (
        f => 'fqdn',
        d => 'dir_instance',
        i => 'dir_suffix',
        n => 'dir_manager_passwd',
        r => 'dir_manager_passwd',
        s => 'ca_cert_pem',
        e => 'srv_cert_key_pkcs12'
    );
    assert_script_run 'wget ' . data_url('console/samba_ca_cert.pem');
    assert_script_run 'wget ' . data_url('console/samba_server_cert.p12');
    # setup FQDN hostname
    assert_script_run("hostname $ldap_directives{fqdn}");
    assert_script_run("echo \"127.0.0.1 $ldap_directives{fqdn} openqa\" > /etc/hosts");
    assert_script_run("echo \"$ldap_directives{fqdn}\" > /etc/hostname");

    record_info 'Setup LDAP', 'Create New Directory Instance';
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'ldap-server');

    wait_still_screen(2);
    foreach (sort keys %ldap_options_to_dirs) {
        wait_screen_change { send_key "alt-$_" };
        enter_cmd($ldap_directives{$ldap_options_to_dirs{$_}} . "");
    }
    assert_screen 'yast2_samba-389ds-setup';
    send_key $cmd{ok};

    record_info 'Setup LDAP', 'Workaround for cert name issue';
    assert_screen 'yast2_samba-389ds-setup-error-workaround', 180;
    send_key 'ret';
    wait_screen_change { send_key "alt-c" };
    die "'yast2 ldap-server' didn't finish with zero exit code" unless wait_serial("$module_name-0");
    assert_script_run('certutil -d /etc/dirsrv/slapd-openqatest --rename -n "openqa.ldaptest.org - Suse" --new-n Server-Cert');
    systemctl 'start dirsrv@' . $ldap_directives{dir_instance};
    systemctl 'status dirsrv@' . $ldap_directives{dir_instance};
}

sub setup_yast2_auth_server {

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # SLE12SP4 still uses old yast2-auth-server-3.1.18, which does not contain ldap-server.rb
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'auth-server');

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
    send_key 'alt-n';
    assert_screen 'yast2_ldap_basic_db_configuration';
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
    wait_serial("$module_name-0") || die "'yast2 auth server' failed to finish";
    assert_screen 'yast2_console-finished';
    # check ldap server status at first, a local ldap server is needed in the test case
    systemctl "show -p ActiveState slapd.service | grep ActiveState=active";
}

sub set_workgroup {
    record_info 'Samba Installation', 'Step 1 of 1';
    my %actions = (name => {shortcut => 'alt-w', value => $samba_directives{workgroup}});
    assert_screen 'yast2_samba_installation';
    wait_screen_change { send_key $actions{name}->{shortcut} };
    for (1 .. 12) { send_key 'backspace'; }
    type_string $actions{name}->{value};
    assert_screen 'yast2_samba-server_workgroup_new';
    send_key $cmd{next};
}

sub handle_domain_controller {
    record_info 'Samba Installation', 'Handle domain controller';
    # select "Not a Domain Controller"
    assert_screen 'yast2_samba_server_selection';
    send_key 'alt-c';
    # check "Not a DC" is select
    assert_screen 'yast2_samba-server_not-a-dc_selected';
    send_key 'alt-n';
}

sub setup_samba_startup {
    record_info 'Samba Configuration', 'Start-Up';
    my %actions = (firewall => {shortcut => 'alt-f'});

    assert_screen 'yast2_samba-startup-configuration';
    if (is_sle('<15') || is_leap('<15.1')) {
        send_key 'alt-r';
        assert_screen 'yast2_samba-server_start-during-boot';
    }
    else {
        change_service_configuration(
            after_writing => {start => 'alt-e'},
            after_reboot => {start_on_boot => 'alt-a'}
        );
    }
    send_key $actions{firewall}->{shortcut};
    assert_screen 'yast2_samba_open_port_firewall';
}

sub setup_samba_share {
    record_info 'Samba Configuration', 'Shares';
    my %actions = (
        shares => {shortcut => 'alt-s'},
        name => {shortcut => 'alt-n', value => 'html_public'},
        description => {shortcut => 'alt-a', value => $samba_directives{comment}},
        path => {shortcut => 'alt-s', value => $samba_directives{path}},
        readonly => {shortcut => 'alt-r'},
        yes => {shortcut => 'alt-y'},
        allow_users => {shortcut => 'alt-w'},
        allow_guest_access => {shortcut => 'alt-g'},
        maximum => {shortcut => 'alt-m', value => $samba_directives{usershare_max_shares} . "\n"},
    );

    send_key $actions{shares}->{shortcut};
    assert_screen 'yast2_samba-server_shares';
    send_key $cmd{add};

    # Identification
    assert_screen 'yast2_samba-server_new-share';
    send_key_until_needlematch 'yast2_samba-share-name-focused', $actions{name}->{shortcut}, 6;    # ensure responsive
    type_string $actions{name}->{value};
    wait_screen_change { send_key $actions{description}->{shortcut} };
    type_string $actions{description}->{value};

    # Share Type
    wait_screen_change { send_key $actions{path}->{shortcut}; };
    for (1 .. 5) { send_key 'backspace'; }
    type_string $actions{path}->{value};
    send_key $actions{readonly}->{shortcut};
    assert_screen 'yast2_samba-server_new-share_create';
    send_key $cmd{ok};
    assert_screen 'yast2_samba-server_new-share-path';
    send_key $actions{yes}->{shortcut};

    # back to samba configuration and make some changes to share directories
    assert_screen 'yast2_samba-added_html_share';
    send_key $actions{allow_users}->{shortcut};
    wait_screen_change { send_key $actions{allow_guest_access}->{shortcut} };
    send_key $actions{maximum}->{shortcut};
    type_string $actions{maximum}->{value};
}

sub setup_samba_identity {
    record_info 'Samba Configuration', 'Identity';
    my %actions = (
        identity => {shortcut => 'alt-d'},
        domain_controller => {shortcut => 'alt-a'},
        win_server => {shortcut => 'alt-i'},
        netbios => {shortcut => 'alt-e', value => $samba_directives{netbios_name}},
        advanced => {shortcut => 'alt-v'},
        logon_drive => {value => $samba_directives{logon_drive}}
    );

    send_key $actions{identity}->{shortcut};
    assert_screen 'yast2_samba-server_identity';
    # select "Not a Domain Controller" in new products
    if (is_sle('>=15') || is_leap('>=15.0') || is_tumbleweed) {
        wait_screen_change { send_key $actions{domain_controller}->{shortcut} };
        send_key 'ret';
        # check "Not a DC" is select
        assert_screen 'yast2_samba-server_not-a-dc_selected';
    }
    wait_screen_change { send_key $actions{win_server}->{shortcut} };
    wait_screen_change { send_key $actions{netbios}->{shortcut} };
    type_string $actions{netbios}->{value};
    send_key $actions{advanced}->{shortcut};
    assert_screen 'yast2_samba-server_identity_netbios_advanced_expert';
    send_key 'ret';
    assert_screen 'yast2_samba-server_netbios_name_change_warning';
    wait_screen_change { send_key $cmd{ok} };
    # change logon drive to C:
    send_key_until_needlematch 'yast2_samba-server_netbios_logon-drive', 'down';
    wait_screen_change { send_key 'ret' };
    for (1 .. 2) { send_key 'backspace'; }
    type_string $actions{logon_drive}->{value};
    wait_screen_change { send_key $cmd{ok} };
    send_key $cmd{ok};
    # return back to last tab (when some tab is navigated ncurses highlights all letters)
    assert_screen 'yast2_samba-server_identity_navigated';
}

sub setup_samba_trusted_domains {
    record_info 'Samba Configuration', 'Trusted domains';
    my %actions = (
        trusted_domains => {shortcut => 'alt-t', value => "990\n"},
        name => {value => 'suse.de'},
        password => {shortcut => 'alt-p', value => 'testing'}
    );
    send_key $actions{trusted_domains}->{shortcut};
    assert_screen 'yast2_samba-server_trusted-domains';
    wait_screen_change { send_key $cmd{add} };
    type_string $actions{name}->{value};
    wait_screen_change { send_key $actions{password}->{shortcut} };
    type_string $actions{password}->{value};
    send_key $cmd{ok};

    assert_screen 'yast2_samba-server_trusted-domains_error';
    wait_screen_change { send_key $cmd{ok} };
    assert_screen 'yast2_samba-server_trusted-domains_cancel_configuration';
    wait_screen_change { send_key $cmd{cancel} };
}

sub setup_samba_ldap {
    record_info 'Samba Configuration', 'LDAP Settings';
    my $administratio_dn = is_sle('<15') ? $ldap_directives{dir_manager_dn} . ",$ldap_directives{dir_suffix}" : $ldap_directives{dir_manager_dn};
    my %actions = (
        ldap => {shortcut => 'alt-l'},
        use_password_backend => {shortcut => 'alt-b'},
        yes => {shortcut => 'alt-y'},
        server_url => {shortcut => 'alt-e', value => 'ldap://localhost:389'},
        administration_dn => {shortcut => 'alt-a', value => $administratio_dn},
        password => {shortcut => 'alt-p', value => $ldap_directives{dir_manager_passwd}},
        password_retry => {shortcut => 'alt-g', value => $ldap_directives{dir_manager_passwd}},
        search_base_dn => {shortcut => 'alt-n', value => $ldap_directives{dn_container}}
    );

    send_key $actions{ldap}->{shortcut};
    assert_screen 'yast2_samba-server_ldap-settings';

    send_key $actions{use_password_backend}->{shortcut};
    assert_screen 'yast2_samba-server_ldap_value_rewritten';
    send_key $actions{yes}->{shortcut};

    assert_screen 'yast2_samba-server_ldap_passwd_checked';
    send_key $actions{server_url}->{shortcut};
    type_string $actions{server_url}->{value};
    # set admin password and search base dn
    wait_screen_change { send_key $actions{administration_dn}->{shortcut} };
    type_string $actions{administration_dn}->{value};
    wait_screen_change { send_key $actions{password}->{shortcut} };
    type_string $actions{password}->{value};
    wait_screen_change { send_key $actions{password_retry}->{shortcut} };
    type_string $actions{password_retry}->{value};
    wait_screen_change { send_key $actions{search_base_dn}->{shortcut} };
    type_string $actions{search_base_dn}->{value};
    save_screenshot;
}

sub setup_samba_ldap_expert {
    record_info 'Samba Configuration', 'Expert LDAP Settings';
    my %actions = (
        advanced => {shortcut => 'alt-v'},
        replication => {shortcut => 'alt-p', value => "990\n"},
        timeout => {shortcut => 'alt-t', value => "7\n"},
        use_ssl_or_tls => {shortcut => 'alt-u'},
        test => {shortcut => 'alt-t'}
    );

    # check advanced settings before run test connection to ldap server
    wait_screen_change { send_key $actions{advanced}->{shortcut} };
    send_key 'ret';

    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings';
    wait_screen_change { send_key $actions{replication}->{shortcut} };
    type_string $actions{replication}->{value};
    wait_screen_change { send_key $actions{timeout}->{shortcut} };
    type_string $actions{timeout}->{value};

    # change to not use SSL or TLS
    wait_screen_change { send_key $actions{use_ssl_or_tls}{shortcut} };
    send_key 'up';
    assert_screen 'yast2_samba-server_ldap_advanced_expert_settings_not-use-ssl';
    send_key 'ret';
    wait_screen_change { send_key $cmd{ok} };

    # now run test connection
    send_key $actions{test}{shortcut};
    assert_screen 'yast2_samba-server_ldap_test-connection';
    wait_screen_change { send_key $cmd{ok} };
}

sub setup_samba {
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'samba-server');
    set_workgroup;
    handle_domain_controller if (is_sle('<15') || is_leap('<15.0'));
    setup_samba_startup;
    setup_samba_share;
    setup_samba_identity;
    setup_samba_trusted_domains;
    setup_samba_ldap;
    setup_samba_ldap_expert;

    send_key $cmd{ok};
    wait_serial("$module_name-0", 60) || die "'yast2 samba-server' didn't finish";
}

sub run {
    select_console 'root-console';
    zypper_call 'in samba yast2-samba-server yast2-auth-server';

    # setup ldap instance (openldap or 389-ds) for samba
    if (is_sle('<15') || is_leap('<15.0')) {
        setup_yast2_auth_server;
    }
    else {
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
    $self->SUPER::post_fail_hook;
    upload_logs('/etc/samba/smb.conf');
    upload_logs('/tmp/failed_smb_directives.log');
}

1;
