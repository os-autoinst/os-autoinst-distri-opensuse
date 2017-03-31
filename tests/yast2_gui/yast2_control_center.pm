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

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;

    $self->launch_yast2_module_x11;
    assert_screen 'yast2-control-center-ui';

    #	search module by typing string
    type_string "add";
    assert_screen "yast2_control-center_search_add";

    #	start yast2 modules
    for (1 .. 6) {
        send_key 'backspace';
    }

    #	start Add-on Products
    assert_and_click "yast2_control-center_add-on";
    assert_screen "yast2_control-center_add-on_installed";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #	start Add System Extensions or Modules
    assert_and_click "yast2_control-center_add-system-extensions-or-modules";
    assert_screen "yast2_control-center_registration";
    send_key "alt-r";
    assert_screen 'yast2-control-center-ui';

    #	start Media Check
    assert_and_click "yast2_control-center_media-check";
    assert_screen "yast2_control-center_media-check_close";
    send_key "alt-l";
    assert_screen 'yast2-control-center-ui';

    #	start Online Update
    assert_and_click 'yast2_control-center_online-update';
    assert_screen [qw(yast2_control-center_update-repo-dialogue yast2_control-center_online-update_close)], 60;
    if (match_has_tag('yast2_control-center_update-repo-dialogue')) {
        send_key 'alt-n';
        assert_screen 'yast2_control-center_online-update_close';
    }
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui';

    #	start Software Repositiories
    assert_and_click "yast2_control-center_software-repositories";
    assert_screen "yast2_control-center_configured-software-repositories";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #	start Printer
    assert_and_click "yast2_control-center_printer";
    assert_screen "yast2_control-center_printer_running-cups-daemon";
    send_key "alt-y";
    assert_screen 'yast2_control-center_printer_running-cups-daemon_no-delay';
    send_key "alt-o";
    assert_screen 'yast2_control-center_printer_running-cups-daemon_enabled';
    send_key 'alt-y';
    assert_screen "yast2_control-center_printer_configurations";
    send_key "alt-o";

    assert_screen 'yast2-control-center-ui', 60;
    #	test case if not restart cups daemon locally
    select_console 'root-console';
    assert_script_run 'systemctl stop cups.service';
    select_console 'x11', await_console => 0;
    assert_screen 'yast2-control-center-ui';
    send_key "up";
    assert_and_click 'yast2_control-center_printer';
    assert_screen 'yast2_control-center_printer_running-cups-daemon';
    send_key "alt-n";
    assert_screen "yast2_control-center_printer_running-cups-daemon_error";
    send_key "alt-o";
    assert_screen "yast2_control-center_detect-printer-queues_error";
    send_key "alt-o";
    assert_screen 'yast2_control-center_show-printer-queues_error';
    send_key "alt-o";
    assert_screen "yast2_control-center_printer_configurations";
    send_key "alt-o";

    #	start Sound
    assert_and_click "yast2_control-center_sound";
    assert_screen "yast2_control-center_sound_configuration";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui', 60;

    #   start System Keyboard Layout
    assert_and_click "yast2_control-center_keyboard";
    assert_screen "yast2_control-center_keyboard_configuration";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui', 60;

    #	start Boot Loader
    assert_and_click "yast2_control-center_bootloarder";
    assert_screen "yast2_control-center_bootloader_ok";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui', 60;

    #	start Date and Time
    assert_and_click "yast2_control-center_date-and-time";
    assert_screen [qw(yast2_control-center_data-and-time_ntp.conf_changed yast2_control-center_clock-and-time-zone)], 60;
    if (match_has_tag 'yast2_control-center_data-and-time_ntp.conf_changed') {
        send_key "alt-o";
    }
    assert_screen "yast2_control-center_clock-and-time-zone", 60;
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #	start Sysconfig Editor
    assert_and_click "yast2_control-sysconfig-editor";
    assert_screen "yast2_control-center_etc-sysconfig-editor", 60;
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #   start Kernel Kdump
    assert_and_click "yast2_control-kernel-kdump";
    assert_screen "yast2_control-center_kernel-kdump-configuration", 60;
    assert_and_click "yast2_control-kernel-kdump-configuration_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Languages
    assert_and_click "yast2_control-languages";
    assert_screen "yast2_control-center_languages-settings", 60;
    assert_and_click "yast2_control-languages-settings_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Network Settings
    assert_and_click "yast2_control-center_network-settings";
    assert_screen "yast2_control-network-settings_overview", 60;
    assert_and_click "yast2_control-network-settings_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Online Migration
    assert_and_click "yast2_control-center_online-migration";
    assert_screen "yast2_control-center-online-migration_cancel", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Partitioner
    assert_and_click "yast2_control-center_partitioner";
    assert_screen "yast2_control-center-partitioner_warning", 60;
    assert_and_click "yast2_control-center-partitioner_abort";
    assert_screen 'yast2-control-center-ui';

    #   start Service Manager
    assert_and_click "yast2_control-center_service-manager";
    assert_screen "yast2_control-center-service-manager_list", 60;
    assert_and_click "yast2_control-center-service-manager_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Authentication Server
    #	need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_authentication-server";
    assert_screen [qw(yast2_control-center-authentication-server_install yast2_control-center-authentication-server_configuration)], 90;
    if (match_has_tag('yast2_control-center-authentication-server_install')) {
        send_key "alt-i";
        assert_screen 'yast2_control-center-authentication-server_configuration', 60;
        send_key "alt-c";
    }
    else {
        assert_screen 'yast2_control-center-authentication-server_configuration';
        send_key "alt-o";
    }
    assert_screen 'yast2-control-center-ui', 60;

    #   start DHCP Server
    assert_and_click "yast2_control-center_dhcp-server";
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

    #   start DNS Server
    assert_and_click "yast2_control-center_dns-server";
    assert_screen [qw(yast2_control-center-dns-server-install_cancel yast2_control-center-dns-server-start-up)], 60;
    if (match_has_tag 'yast2_control-center-dns-server-install_cancel') {
        send_key "alt-i";
        assert_screen 'yast2_control-center-dns-server-configuration';
        send_key 'alt-c';
        assert_screen 'yast2_control-center-dns-server-really-abort';
        send_key 'alt-y';
    }
    else {
        assert_screen "yast2_control-center-dns-server-start-up";
        send_key "alt-o";
    }
    assert_screen 'yast2-control-center-ui', 60;

    #   start FTP Server
    assert_and_click "yast2_control-center_ftp-server";
    assert_screen "yast2_control-center_ftp-start-up", 60;
    send_key "alt-f";
    assert_screen 'yast2-control-center-ui', 60;

    #   start Hostnames
    assert_and_click "yast2_control-center_hostnames";
    assert_screen "yast2_control-center_hostnames_ok";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #   start HTTP Server
    assert_and_click "yast2_control-center_http";
    assert_screen [qw(yast2_control-center_http_finish yast2_control-center_http_install)], 60;
    if (match_has_tag 'yast2_control-center_http_install') {
        send_key 'alt-c';
        send_key 'alt-o';
    }
    assert_screen 'yast2_control-center_http_finish';
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui';

    #   start iSCSI initiator
    assert_and_click "yast2_control-center_iscsi-initiator";
    assert_screen "yast2_control-center_iscsi-initiator_cancel", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start iSNS Server
    assert_and_click "yast2_control-center_isns-server";
    assert_screen "yast2_control-center_isns-server_cancel";
    send_key "alt-c";
    assert_screen "yast2_control-center_isns-server_error";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #   start LDAP and Kerberos client
    assert_and_click "yast2_control-center_ldap-kerberos-client";
    assert_screen "yast2_control-center_ldap-kerberos-client_finish";
    send_key "alt-f";
    assert_screen 'yast2-control-center-ui', 60;

    #   start Mail Server
    assert_and_click "yast2_control-center_mail-server";
    assert_screen "yast2_control-center_mail-server_cancel", 60;
    send_key "alt-c";
    assert_screen "yast2_control-center_mail-server_cancel-confirm";
    send_key "alt-r";
    assert_screen "yast2_control-center_mail-server_really-abort";
    send_key "alt-y";
    assert_screen 'yast2-control-center-ui';

    #   start Xinetd
    assert_and_click "yast2_control-center_xinetd";
    assert_screen "yast2_control-center_xinetd-server_cancel", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start NFS Client
    assert_and_click "yast2_control-center_nfs-client";
    assert_screen "yast2_control-center_nfs_client_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui', 60;

    #   start NFS Server
    assert_and_click "yast2_control-center_nfs-server";
    assert_screen "yast2_control-center_nfs_server_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui', 60;

    #   start NIS Client
    assert_and_click "yast2_control-center_nis-client";
    assert_screen "yast2_control-center_nis_client_cancel", 60;
    send_key "alt-r";
    assert_screen 'yast2-control-center-ui', 60;

    #   start NIS Server
    assert_and_click "yast2_control-center_nis-server";
    assert_screen "yast2_control-center_nis_server_cancel", 60;
    send_key "alt-r";
    assert_screen 'yast2-control-center-ui', 60;

    #   start NTP Configuration
    assert_and_click "yast2_control-center_ntp-configuration";
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

    #   start OpenLDAP MirrorMode Configuration
    assert_and_click "yast2_control-center_openldap-mirrormode-configuration";
    assert_screen "yast2_control-center_openldap-mirrormode-configuration_cancel", 90;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Proxy Configuration
    assert_and_click "yast2_control-center_proxy-configuration";
    assert_screen "yast2_control-center_proxy-configuration_enable", 60;
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #   start Remote Administration VNC
    assert_and_click "yast2_control-center_remote-administration";
    assert_screen "yast2_control-center_remote-administration_ok", 60;
    send_key "alt-o";
    assert_screen "yast2_control-center_remote-administration_display-manager-warning";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui';

    #   start Samba Server
    assert_and_click "yast2_control-center_samba-server";
    assert_screen "yast2_control-center_samba-server_samba-configuration", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Squid Server
    assert_and_click "yast2_control-center_squid-server-configuration";
    assert_screen [qw(yast2_control-center_squid-server-install yast2_control-center_squid-server_start-up)];
    if (match_has_tag 'yast2_control-center_squid-server-install') {
        send_key "alt-i";
        assert_screen 'yast2_control-center_squid-server_start-up', 60;
        send_key "alt-o";
    }
    else {
        assert_screen 'yast2_control-center_squid-server_start-up';
        send_key "alt-o";
    }
    assert_screen 'yast2-control-center-ui', 60;

    #   start TFTP Server
    assert_and_click "yast2_control-center_tftp-server-configuration";
    assert_screen 'yast2_control-center_tftp-server-configuration_cancel';
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui', 60;

    #   start User Logon Management
    assert_and_click "yast2_control-center_user-logon-management";
    assert_screen "yast2_control-center_user-logon-management_finish", 60;
    send_key "alt-f";
    assert_screen 'yast2-control-center-ui', 60;

    #   start VPN Gateway and Clients
    assert_and_click "yast2_control-center_vpn-gateway-client";
    assert_screen "yast2_control-center_vpn-gateway-client_cancel", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Wake-on-LAN
    assert_and_click "yast2_control-center_wake-on-lan";
    assert_screen "yast2_control-center_wake-on-lan_install_cancel";
    send_key "alt-c";
    assert_screen "yast2_control-center_wake-on-lan_install_error";
    send_key "alt-o";
    assert_screen 'yast2-control-center-ui', 60;

    #   start Windows Domain Membership
    assert_and_click "yast2_control-center_windows-domain-membership";
    assert_screen "yast2_control-center_windows-domain-membership_verifying-membership", 60;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', 60;

    #   start AppArmor Configuration
    #   need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_apparmor-configuration";
    assert_screen "yast2_control-center-apparmor-configuration_abort", 60;
    send_key "alt-r";
    assert_screen 'yast2-control-center-ui';

    #   start CA Management
    assert_and_click "yast2_control-center_ca-management";
    assert_screen "yast2_control-center_ca-management_abort";
    send_key "alt-f";
    assert_screen 'yast2-control-center-ui';

    #   start Common Server Certificate
    assert_and_click "yast2_control-center_common-server-certificate";
    assert_screen "yast2_control-center_common-server-certificate_abort";
    send_key "alt-r";
    assert_screen 'yast2-control-center-ui';

    #   start Firewall
    assert_and_click "yast2_control-center_firewall";
    assert_screen "yast2_control-center_firewall_configuration", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Linux Audit Framework LAF
    assert_and_click "yast2_control-center_laf";
    assert_screen [qw(yast2_control-center_laf_cancel yast2_control-center_configuration)], 60;
    if (match_has_tag 'yast2_control-center_laf_cancel') {
        send_key "alt-e";
        assert_screen "yast2_control-center_laf-configuration";
        send_key "alt-f";
    }
    else {
        assert_screen "yast2_control-center_laf-configuration";
        send_key "alt-f";
    }
    assert_screen 'yast2-control-center-ui', 60;

    #   start Security Center and Hardening
    assert_and_click "yast2_control-center_security-center-and-hardening";
    assert_screen "yast2_control-center_security-center-and-hardening_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #	start Sudo
    assert_and_click "yast2_control-center_sudo";
    assert_screen "yast2_control-center_sudo_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start User and Group Management
    assert_and_click "yast2_control-center_user-and-group-management";
    assert_screen "yast2_control-center_user-and-group-management_cancel", 60;
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Install Hypervisor and Tools
    #   need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_install-hypervisor-and-tools";
    assert_screen "yast2_control-center_install-hypervisor-and-tools_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    #   start Relocation Server Configuration
    assert_and_click "yast2_control-center_relocation-server-configuration";
    assert_screen "yast2_control-center_relocation-server-configuration_cancel";
    send_key "alt-c";
    assert_screen 'yast2-control-center-ui';

    # 	finally done and exit
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
