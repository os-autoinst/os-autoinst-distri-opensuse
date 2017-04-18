# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST2 UI test yast2-control-center provides sanity checks for YaST modules
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base 'y2x11test';
use strict;
use testapi;
use utils;

sub search {
    my ($name) = @_;
    # on openSUSE we have a Qt setup with keyboard shortcut
    if (check_var('DISTRI', 'opensuse')) {
        send_key 'alt-s';
    }
    # with the gtk interface we have to click as there is no shortcut
    elsif (check_var('DISTRI', 'sle')) {
        assert_and_click 'yast2_control-center_search_clear';
    }
    type_string $name if $name;
}

sub start_addon_products {
    assert_and_click 'yast2_control-center_add-on';
    assert_screen 'yast2_control-center_add-on_installed';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_add_system_extensions {
    assert_and_click 'yast2_control-center_add-system-extensions-or-modules';
    assert_screen 'yast2_control-center_registration';
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui';
}

sub start_media_check {
    assert_and_click 'yast2_control-center_media-check';
    assert_screen 'yast2_control-center_media-check_close';
    send_key 'alt-l';
    assert_screen 'yast2-control-center-ui';
}

sub start_online_update {
    assert_and_click 'yast2_control-center_online-update';
    assert_screen [qw(yast2_control-center_update-repo-dialogue yast2_control-center_online-update_close)], 60;
    if (match_has_tag('yast2_control-center_update-repo-dialogue')) {
        send_key 'alt-n';
        assert_screen 'yast2_control-center_online-update_close';
    }
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_software_repositories {
    search('software');
    assert_and_click 'yast2_control-center_software-repositories';
    assert_screen 'yast2_control-center_configured-software-repositories';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_sound {
    assert_and_click 'yast2_control-center_sound';
    assert_screen 'yast2_control-center_sound_configuration';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_scanner {
    assert_and_click 'yast2_control-center_scanner';
    # give 90 seconds timout for creating scanner database and detecting scanners
    assert_screen 'yast2_control-center_scanner_configuration', 90;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_system_keyboard_layout {
    assert_and_click 'yast2_control-center_keyboard';
    assert_screen 'yast2_control-center_keyboard_configuration', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_boot_loader {
    assert_and_click 'yast2_control-center_system' if check_var('DISTRI', 'opensuse');
    assert_and_click 'yast2_control-center_bootloader';
    assert_screen 'yast2_control-center_bootloader_settings';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_date_and_time {
    assert_and_click 'yast2_control-center_date-and-time';
    assert_screen [qw(yast2_control-center_data-and-time_ntp.conf_changed yast2_control-center_clock-and-time-zone)], 60;
    if (match_has_tag 'yast2_control-center_data-and-time_ntp.conf_changed') {
        send_key 'alt-o';
    }
    assert_screen 'yast2_control-center_clock-and-time-zone', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_fonts {
    # only available on openSUSE or at least not SLES
    if (check_var('DISTRI', 'opensuse')) {
        assert_and_click 'yast2_control-center_fonts';
        assert_screen 'yast2_control-center_fonts-configuration';
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui';
    }
}

sub start_sysconfig_editor {
    assert_and_click 'yast2_control-sysconfig-editor';
    assert_screen 'yast2_control-center_etc-sysconfig-editor', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_kernel_dump {
    assert_and_click 'yast2_control-kernel-kdump';
    assert_screen 'yast2_control-center_kernel-kdump-configuration', 60;
    assert_and_click 'yast2_control-kernel-kdump-configuration_ok';
    assert_screen 'yast2-control-center-ui';
}

sub start_kernel_settings {
    assert_and_click 'yast2_control-center-kernel-settings';
    assert_screen 'yast2_control-center_kernel-settings_pci-id-setup', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_languages {
    assert_and_click 'yast2_control-center-languages';
    assert_screen 'yast2_control-center_languages-settings', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_network_settings {
    search('network');
    assert_and_click 'yast2_control-center_network-settings';
    assert_screen 'yast2_control-network-settings_overview', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_partitioner {
    assert_and_click 'yast2_control-center-partitioner';
    assert_screen 'yast2_control-center-partitioner_warning', 60;
    send_key 'alt-y';
    assert_screen 'yast2_control-center-partitioner_expert';
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui';
}

sub start_service_manager {
    assert_and_click 'yast2_control-center_service-manager';
    # for a short moment the screen is not dimmed down
    wait_still_screen 9;
    assert_screen 'yast2_control-center-service-manager_list', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_authentication_server {
    # available by default only on SLES
    if (check_var('DISTRI', 'sle')) {
        # need to scroll down to get other modules
        send_key 'down';
        assert_and_click 'yast2_control-center_authentication-server';
        assert_screen [qw(yast2_control-center-authentication-server_install yast2_control-center-authentication-server_configuration)], 90;
        if (match_has_tag('yast2_control-center-authentication-server_install')) {
            send_key 'alt-i';
            assert_screen 'yast2_control-center-authentication-server_configuration', 60;
            send_key 'alt-c';
        }
        else {
            assert_screen 'yast2_control-center-authentication-server_configuration';
            send_key 'alt-o';
        }
        assert_screen 'yast2-control-center-ui', 60;
    }
}

sub start_dhcp_server {
    if (check_var('DISTRI', 'sle')) {
        assert_and_click 'yast2_control-center_dhcp-server';
        assert_screen [qw(yast2_control-center-dhcp-server-install_cancel yast2_control-center-dhcp-server-configuration)], 60;
        if (match_has_tag 'yast2_control-center-dhcp-server-install_cancel') {
            send_key 'alt-i';
            assert_screen 'yast2_control-center-dhcp-server-hostname', 60;
            send_key 'alt-o';
            assert_screen 'yast2_control-center-dhcp-server-configuration', 60;
            send_key 'alt-r';
        }
        else {
            assert_screen 'yast2_control-center-dhcp-server-configuration', 60;
            send_key 'alt-r';
        }
        assert_screen 'yast2-control-center-ui', 60;
    }
}

sub start_dns_server {
    assert_and_click 'yast2_control-center_dns-server';
    assert_screen [qw(yast2_control-center-dns-server-install_cancel yast2_control-center-dns-server-start-up yast2_control-center-dns-server-installation)], 60;
    if (match_has_tag 'yast2_control-center-dns-server-install_cancel') {
        send_key 'alt-i';
        assert_screen 'yast2_control-center-dns-server-configuration';
        send_key 'alt-c';
        assert_screen 'yast2_control-center-dns-server-really-abort';
        send_key 'alt-y';
    }
    elsif (match_has_tag 'yast2_control-center-dns-server-installation') {
        send_key 'alt-c';
        assert_screen 'yast2_control-center-dns-server-installation_abort';
        send_key 'alt-o';
        assert_screen 'yast2_control-center-dns-server-installation_forwarder-setting';
        send_key 'alt-c';
        assert_screen 'yast2_control-center-dns-server-installation_really-abort';
        send_key 'alt-y';
    }
    else {
        assert_screen 'yast2_control-center-dns-server-start-up';
        send_key 'alt-o';
    }
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_ftp_server {
    search('ftp');
    assert_and_click 'yast2_control-center_ftp-server';
    assert_screen 'yast2_control-center_ftp-start-up', 60;
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_hostnames {
    search('hostname');
    assert_and_click 'yast2_control-center_hostnames';
    assert_screen 'yast2_control-center_hostnames_ok';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_http_server {
    search('http');
    assert_and_click 'yast2_control-center_http';
    assert_screen [qw(yast2_control-center_http_finish yast2_control-center_http_wizard)];
    if (match_has_tag 'yast2_control-center_http_wizard') {
        send_key 'alt-n';
        assert_screen 'yast2_control-center_http_wizard-2';
        send_key 'alt-n';
        assert_screen 'yast2_control-center_http_wizard-3';
        send_key 'alt-n';
        assert_screen 'yast2_control-center_http_wizard-4';
        send_key 'alt-n';
        assert_screen 'yast2_control-center_http_wizard-5';
        send_key 'alt-f';
    }
    assert_screen 'yast2_control-center_http_finish';
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui';
}

sub start_iscsi_initiator {
    search('iSCSI');
    assert_and_click 'yast2_control-center_iscsi-initiator';
    assert_screen 'yast2_control-center_iscsi-initiator_cancel', 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_isns_server {
    search('isns');
    assert_and_click 'yast2_control-center_isns-server';
    assert_screen 'yast2_control-center_isns-server_install', 60;
    send_key 'alt-i';
    assert_screen 'yast2_control-center_isns-server_config', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_ldap_and_kerberos_client {
    search('ldap');
    assert_and_click 'yast2_control-center_ldap-kerberos-client';
    # for a short moment the screen is not dimmed down
    wait_still_screen 6;
    assert_screen 'yast2_control-center_ldap-kerberos-client_finish';
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_mail_server {
    search('mail');
    assert_and_click 'yast2_control-center_mail-server';
    assert_screen 'yast2_control-center_mail-server_general-settings', 60;
    send_key 'alt-r';
    assert_screen 'yast2_control-center_mail-server_really-abort';
    send_key 'alt-y';
    assert_screen 'yast2-control-center-ui';
}

sub start_xinetd {
    search('xinetd');
    assert_and_click 'yast2_control-center_xinetd';
    assert_screen 'yast2_control-center_xinetd-server_cancel', 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_nfs_client {
    search('nfs');
    assert_and_click 'yast2_control-center_nfs-client';
    assert_screen 'yast2_control-center_nfs_client_cancel', 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_nfs_server {
    search('nfs');
    assert_and_click 'yast2_control-center_nfs-server';
    assert_screen 'yast2_control-center_nfs_server_configuraton', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_nis_client {
    search('nis');
    assert_and_click 'yast2_control-center_nis-client';
    assert_screen 'yast2_control-center_nis_client_cancel', 60;
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_nis_server {
    assert_and_click 'yast2_control-center_nis-server';
    assert_screen 'yast2_control-center_nis_server_cancel', 60;
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_ntp_configuration {
    search('ntp');
    assert_and_click 'yast2_control-center_ntp-configuration';
    assert_screen [qw(yast2_control-center_ntp.conf_changed yast2_control-center_ntp-general-settings)], 60;
    if (match_has_tag 'yast2_control-center_ntp.conf_changed') {
        send_key 'alt-o';
        assert_screen 'yast2_control-center_ntp-general-settings';
        send_key 'alt-o';
    }
    else {
        assert_screen 'yast2_control-center_ntp-general-settings';
        send_key 'alt-o';
    }
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_openldap {
    if (check_var('DISTRI', 'sle')) {
        assert_and_click 'yast2_control-center_openldap-mirrormode-configuration';
        assert_screen 'yast2_control-center_openldap-mirrormode-configuration_cancel', 90;
        send_key 'alt-c';
        assert_screen 'yast2-control-center-ui';
    }
}

sub start_proxy_configuration {
    search('proxy');
    assert_and_click 'yast2_control-center_proxy-configuration';
    assert_screen 'yast2_control-center_proxy-configuration_enable', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_remote_administration_vnc {
    search('remote');
    assert_and_click 'yast2_control-center_remote-administration';
    assert_screen [qw(yast2_control-center_remote-administration_ok yast2_control-center_remote-administration_install)], 60;
    if (match_has_tag 'yast2_control-center_remote-administration_install')) {
        send_key 'alt-i';
        assert_screen 'yast2_control-center_remote-administration_configuration', 60;
    }
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_samba_server {
    search('samba');
    assert_and_click 'yast2_control-center_samba-server';
    assert_screen 'yast2_control-center_samba-server_samba-configuration', 60;
    send_key 'alt-n';
    assert_screen 'yast2_control-center_samba-server_samba-configuration_dc';
    send_key 'alt-n';
    assert_screen 'yast2_control-center_samba-server_samba-configuration_start-up';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_squid_server {
    if (check_var('DISTRI', 'sle')) {
        assert_and_click 'yast2_control-center_squid-server-configuration';
        assert_screen [qw(yast2_control-center_squid-server-install yast2_control-center_squid-server_start-up)];
        if (match_has_tag 'yast2_control-center_squid-server-install') {
            send_key 'alt-i';
            assert_screen 'yast2_control-center_squid-server_start-up', 60;
            send_key 'alt-o';
        }
        else {
            assert_screen 'yast2_control-center_squid-server_start-up';
            send_key 'alt-o';
        }
        assert_screen 'yast2-control-center-ui', 60;
    }
}

sub start_tftp_server {
    assert_and_click 'yast2_control-center_tftp-server-configuration';
    assert_screen 'yast2_control-center_tftp-server-configuration_cancel';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_user_logon_management {
    search('user');
    assert_and_click 'yast2_control-center_user-logon-management';
    assert_screen 'yast2_control-center_user-logon-management_finish', 60;
    send_key 'alt-f';
    assert_screen 'yast2_control-center_user-logon-management_new-users';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_vpn_gateway {
    assert_and_click 'yast2_control-center_vpn-gateway-client';
    assert_screen 'yast2_control-center_vpn-gateway-client_cancel', 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_wake_on_lan {
    if (check_var('DISTRI', 'opensuse')) {
        assert_and_click 'yast2_control-center_wake-on-lan';
        assert_screen 'yast2_control-center_wake-on-lan_install_cancel';
        send_key 'alt-c';
        assert_screen 'yast2_control-center_wake-on-lan_install_error';
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui', 60;
    }
}

sub start_windows_domain_membership {
    search('domain');
    assert_and_click 'yast2_control-center_windows-domain-membership';
    # for a short moment the screen is not dimmed downfor a short moment the screen is not dimmed down
    wait_still_screen 20;
    assert_screen 'yast2_control-center_windows-domain-membership_verifying-membership';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_apparmor_configuration {
    search('apparmor');
    assert_and_click 'yast2_control-center_apparmor-configuration';
    assert_screen 'yast2_control-center-apparmor-configuration_abort', 60;
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui';
}

sub start_ca_management {
    if (check_var('DISTRI', 'sle')) {
        # start CA Management
        assert_and_click 'yast2_control-center_ca-management';
        assert_screen 'yast2_control-center_ca-management_abort';
        send_key 'alt-f';
        assert_screen 'yast2-control-center-ui';

        # start Common Server Certificate
        assert_and_click 'yast2_control-center_common-server-certificate';
        assert_screen 'yast2_control-center_common-server-certificate_abort';
        send_key 'alt-r';
        assert_screen 'yast2-control-center-ui';
    }
}

sub start_firewall {
    search('firewall');
    assert_and_click 'yast2_control-center_firewall';
    assert_screen 'yast2_control-center_firewall_configuration', 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_laf {
    search('audit');
    assert_and_click 'yast2_control-center_laf';
    assert_screen [qw(yast2_control-center_laf_cancel yast2_control-center_laf-configuration)], 60;
    if (match_has_tag 'yast2_control-center_laf_cancel') {
        send_key 'alt-e';
        assert_screen 'yast2_control-center_laf-configuration';
        send_key 'alt-f';
    }
    else {
        assert_screen 'yast2_control-center_laf-configuration';
        send_key 'alt-f';
    }
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_security_center {
    search('security');
    assert_and_click 'yast2_control-center_security-center-and-hardening';
    assert_screen 'yast2_control-center_security-center-and-hardening_overview';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_sudo {
    search('sudo');
    assert_and_click 'yast2_control-center_sudo';
    assert_screen 'yast2_control-center_sudo_rules';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_user_and_group_management {
    search('user and');
    assert_and_click 'yast2_control-center_user-and-group-management';
    assert_screen 'yast2_control-center_user-and-group-management_users', 60;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui';
}

sub start_hypervisor {
    search('hypervisor');
    assert_and_click 'yast2_control-center_install-hypervisor-and-tools';
    assert_screen 'yast2_control-center_install-hypervisor-and-tools_cancel';
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';
}

sub start_relation_server_configuration {
    if (check_var('DISTRI', 'sle')) {
        assert_and_click 'yast2_control-center_relocation-server-configuration';
        assert_screen 'yast2_control-center_relocation-server-configuration_cancel';
        send_key 'alt-c';
        assert_screen 'yast2-control-center-ui';
    }
}

sub start_printer {
    search;
    for (1 .. 20) {
        send_key 'backspace';
    }
    assert_and_click 'yast2_control-center_hardware' if check_var('DISTRI', 'opensuse');
    assert_and_click 'yast2_control-center_printer';
    # for now only test on SLE as openSUSE looks different. Can be extended
    # later
    if (check_var('DISTRI', 'sle')) {
        assert_screen 'yast2_control-center_printer_running-cups-daemon';
        send_key 'alt-y';
        assert_screen 'yast2_control-center_printer_running-cups-daemon_no-delay';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_printer_running-cups-daemon_enabled';
        send_key 'alt-y';
        assert_screen 'yast2_control-center_printer_configurations';
        send_key 'alt-o';

        assert_screen 'yast2-control-center-ui', 60;
        # test case if not restart cups daemon locally
        select_console 'root-console';
        assert_script_run 'systemctl stop cups.service';
        select_console 'x11', await_console => 0;
        assert_screen 'yast2-control-center-ui';
        send_key 'up';
        assert_and_click 'yast2_control-center_printer';
        assert_screen 'yast2_control-center_printer_running-cups-daemon';
        send_key 'alt-n';
        assert_screen 'yast2_control-center_printer_running-cups-daemon_error';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_detect-printer-queues_error';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_show-printer-queues_error';
        send_key 'alt-o';
    }
    assert_screen 'yast2_control-center_printer_configurations';
    send_key 'alt-o';
}

sub run() {
    my $self = shift;

    # on SLE we can assume the yast modules all to be pre-installed
    if (check_var('DISTRI', 'opensuse')) {
        select_console 'root-console';
        zypper_call('in yast2-dhcp-server yast2-http-server apache2 yast2-isns yast2-nfs-server yast2-nis-server tftp yast2-tftp-server yast2-nis-server yast2-audit-laf');
        select_console 'x11', await_console => 0;
    }

    $self->launch_yast2_module_x11;
    assert_screen 'yast2-control-center-ui';

    # search module by typing string
    search('add');
    assert_screen 'yast2_control-center_search_add';

    # start yast2 modules
    for (1 .. 6) {
        send_key 'backspace';
    }

    start_addon_products;
    start_add_system_extensions;
    start_media_check;
    start_online_update;
    start_software_repositories;
    start_printer;
    start_sound;
    start_addon_products;
    start_add_system_extensions;
    start_media_check;
    start_online_update;
    start_software_repositories;
    start_sound;
    start_scanner;
    start_system_keyboard_layout;
    start_boot_loader;
    start_date_and_time;
    start_fonts;
    start_sysconfig_editor;
    start_kernel_dump;
    start_kernel_settings;
    start_languages;
    start_network_settings;
    start_partitioner;
    start_service_manager;
    start_authentication_server;
    start_dhcp_server;
    start_dns_server;
    start_ftp_server;
    start_hostnames;
    start_http_server;
    start_iscsi_initiator;
    start_isns_server;
    start_ldap_and_kerberos_client;
    start_mail_server;
    start_xinetd;
    start_nfs_client;
    start_nfs_server;
    start_nis_client;
    start_nis_server;
    start_ntp_configuration;
    start_openldap;
    start_proxy_configuration;
    start_remote_administration_vnc;
    start_samba_server;
    start_squid_server;
    start_tftp_server;
    start_user_logon_management;
    start_vpn_gateway;
    start_wake_on_lan;
    start_windows_domain_membership;
    start_apparmor_configuration;
    start_ca_management;
    start_firewall;
    start_laf;
    start_security_center;
    start_sudo;
    start_user_and_group_management;
    start_hypervisor;
    start_relation_server_configuration;
    start_printer;

    #  finally done and exit
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
