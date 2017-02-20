# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Extend YaST2 UI test yast2-control-center
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
    assert_and_click "yast2_control-center_media-check_close";
    assert_screen 'yast2-control-center-ui';

    #	start Online Update
    assert_and_click "yast2_control-center_online-update";
    assert_screen "yast2_control-center_update-repo-dialogue";
    send_key "alt-n";
    assert_and_click "yast2_control-center_online-update_close";
    assert_screen 'yast2-control-center-ui';

    #	start Software Repositiories
    assert_and_click "yast2_control-center_software-repositories";
    assert_screen "yast2_control-center_configured-software-repositories";
    assert_and_click "yast2_control-center_configured-software-repositories_ok";
    assert_screen 'yast2-control-center-ui';

    #	start Printer
    assert_and_click "yast2_control-center_printer";
    assert_screen "yast2_control-center_printer_configurations";
    assert_and_click "yast2_control-center_printer_yes";
    assert_and_click "yast2_control-center_printer_ok";
    assert_and_click "yast2_control-center_printer_cups-daemon-restart_ok";
    assert_and_click "yast2_control-center_printer_cups-daemon-enable-start";
    assert_and_click "yast2_control-center_printer_close";
    assert_screen 'yast2-control-center-ui';

    #	start Sound
    assert_and_click "yast2_control-center_sound";
    assert_screen "yast2_control-center_sound_configuration";
    assert_and_click "yast2_control-center_sound_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start System Keyboard Layout
    assert_and_click "yast2_control-center_keyboard";
    assert_screen "yast2_control-center_keyboard_configuration";
    assert_and_click "yast2_control-center_keyboard_ok";
    assert_screen 'yast2-control-center-ui';

    #	start Boot Loader
    assert_and_click "yast2_control-center_bootloarder";
    assert_screen "yast2_control-center_bootloader_configuration";
    assert_and_click "yast2_control-center_bootloader_ok";
    assert_screen 'yast2-control-center-ui';

    #	start Date and Time
    assert_and_click "yast2_control-center_date-and-time";
    assert_screen "yast2_control-center_clock-and-time-zone";
    assert_and_click "yast2_control-center_clock-and-time-zone_ok";
    assert_screen 'yast2-control-center-ui';

    #	start Sysconfig Editor
    assert_and_click "yast2_control-sysconfig-editor";
    assert_screen "yast2_control-center_etc-sysconfig-editor";
    assert_and_click "yast2_control-sysconfig-editor_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Kernel Kdump
    assert_and_click "yast2_control-kernel-kdump";
    assert_screen "yast2_control-center_kernel-kdump-configuration";
    assert_and_click "yast2_control-kernel-kdump-configuration_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Languages
    assert_and_click "yast2_control-languages";
    assert_screen "yast2_control-center_languages-settings";
    assert_and_click "yast2_control-languages-settings_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Network Settings
    assert_and_click "yast2_control-center_network-settings";
    assert_screen "yast2_control-network-settings_overview", 60;
    assert_and_click "yast2_control-network-settings_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Online Migration
    assert_and_click "yast2_control-center_online-migration";
    assert_and_click "yast2_control-center-online-migration_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Partitioner
    assert_and_click "yast2_control-center_partitioner";
    assert_screen "yast2_control-center-partitioner_warning";
    assert_and_click "yast2_control-center-partitioner_abort";
    assert_screen 'yast2-control-center-ui';

    #   start Service Manager
    assert_and_click "yast2_control-center_service-manager";
    assert_screen "yast2_control-center-service-manager";
    assert_and_click "yast2_control-center-service-manager_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Authentication Server
    #	need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_authentication-server";
    assert_screen "yast2_control-center-authentication-server_install";
    assert_and_click "yast2_control-center-authentication-server_install-cancel";
    assert_and_click "yast2_control-center-authentication-server_install-error";
    assert_screen 'yast2-control-center-ui';

    #   start DHCP Server
    assert_and_click "yast2_control-center_dhcp-server";
    assert_and_click "yast2_control-center-dhcp-server-install_cancel";
    assert_and_click "yast2_control-center-dhcp-server-install-cancel_again";
    assert_screen 'yast2-control-center-ui';

    #   start DNS Server
    assert_and_click "yast2_control-center_dns-server";
    assert_and_click "yast2_control-center-dns-server-install_cancel";
    assert_and_click "yast2_control-center-dns-server-install_abort";
    assert_screen 'yast2-control-center-ui';

    #   start FTP Server
    assert_and_click "yast2_control-center_ftp-server";
    assert_screen "yast2_control-center_ftp-start-up";
    assert_and_click "yast2_control-center_ftp-server_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Hostnames
    assert_and_click "yast2_control-center_hostnames";
    assert_and_click "yast2_control-center_hostnames_ok";
    assert_screen 'yast2-control-center-ui';

    #   start HTTP Server
    assert_and_click "yast2_control-center_http";
    assert_and_click "yast2_control-center_http_finish";
    assert_screen 'yast2-control-center-ui';

    #   start iSCSI initiator
    assert_and_click "yast2_control-center_iscsi-initiator";
    assert_and_click "yast2_control-center_iscsi-intiator_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start iSNS Server
    assert_and_click "yast2_control-center_isns-server";
    assert_and_click "yast2_control-center_isns-server_cancel";
    assert_and_click "yast2_control-center_isns-server_error";
    assert_screen 'yast2-control-center-ui';

    #   start LDAP and Kerberos client
    assert_and_click "yast2_control-center_ldap-kerberos-client";
    assert_screen "yast2_control-center_ldap-kerberos-client_configuration";
    assert_and_click "yast2_control-center_ldap-kerberos-client_finish";
    # it needs long time to get finished.
    assert_screen 'yast2-control-center-ui', 60;

    #   start Mail Server
    assert_and_click "yast2_control-center_mail-server";
    assert_and_click "yast2_control-center_mail-server_cancel";
    assert_and_click "yast2_control-center_mail-server_cancel-confirm";
    assert_screen 'yast2-control-center-ui';

    #   start Xinetd
    assert_and_click "yast2_control-center_xinetd";
    assert_and_click "yast2_control-center_xinetd-server_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start NFS Client
    assert_and_click "yast2_control-center_nfs-client";
    assert_and_click "yast2_control-center_nfs_client_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start NFS Server
    assert_and_click "yast2_control-center_nfs-server";
    assert_and_click "yast2_control-center_nfs_server_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start NIS Client
    assert_and_click "yast2_control-center_nis-client";
    assert_and_click "yast2_control-center_nis_client_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start NIS Server
    assert_and_click "yast2_control-center_nis-server";
    assert_and_click "yast2_control-center_nis_server_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start NTP Configuration
    assert_and_click "yast2_control-center_ntp-configuration";
    assert_and_click "yast2_control-center_ntp-configuration_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start OpenLDAP MirrorMode Configuration
    assert_and_click "yast2_control-center_openldap-mirrormode-configuration";
    assert_and_click "yast2_control-center_openldap-mirrormode-configuration_cancel";
    assert_and_click "yast2_control-center_openldap-mirrormode-configuration_error";
    assert_screen 'yast2-control-center-ui';

    #   start Proxy Configuration
    assert_and_click "yast2_control-center_proxy-configuration";
    assert_and_click "yast2_control-center_proxy-configuration_cancel";
    assert_and_click "yast2_control-center_proxy-configuration-configuration_error";
    assert_screen 'yast2-control-center-ui';

    #   start Remote Administration VNC
    assert_and_click "yast2_control-center_remote-administration";
    assert_and_click "yast2_control-center_remote-administration_ok";
    assert_screen 'yast2-control-center-ui';

    #   start Samba Server
    assert_and_click "yast2_control-center_samba-server";
    assert_and_click "yast2_control-center_samba-server-installation_abort";
    assert_screen 'yast2-control-center-ui';

    #   start Squid Server
    assert_and_click "yast2_control-center_squid-server-configuration";
    assert_and_click "yast2_control-center_squid-server-start-up_cancel";
    assert_and_click "yast2_control-center_squid-server-installation_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start TFTP Server
    assert_and_click "yast2_control-center_tftp-server-configuration";
    assert_and_click "yast2_control-center_tftp-server-configuration_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start User Logon Management
    assert_and_click "yast2_control-center_user-logon-management";
    assert_and_click "yast2_control-center_user-logon-management_finish";
    assert_screen 'yast2-control-center-ui';

    #   start VPN Gateway and Clients
    assert_and_click "yast2_control-center_vpn-gateway-client";
    assert_and_click "yast2_control-center_vpn-gateway-client_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Wake-on-LAN
    assert_and_click "yast2_control-center_wake-on-lan";
    assert_and_click "yast2_control-center_wake-on-lan_install_cancel";
    assert_and_click "yast2_control-center_wake-on-lan_install_error";
    assert_screen 'yast2-control-center-ui';

    #   start Windows Domain Membership
    assert_and_click "yast2_control-center_windows-domain-membership";
    assert_and_click "yast2_control-center_windows-domain-membership_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start AppArmor Configuration
    #   need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_apparmor-configuration";
    assert_and_click "yast2_control-center-apparmor-configuration_abort";
    assert_screen 'yast2-control-center-ui';

    #   start CA Management
    assert_and_click "yast2_control-center_ca-management";
    assert_and_click "yast2_control-center_ca-management_abort";
    assert_screen 'yast2-control-center-ui';

    #   start Common Server Certificate
    assert_and_click "yast2_control-center_common-server-certificate";
    assert_and_click "yast2_control-center_common-server-certificate_abort";
    assert_screen 'yast2-control-center-ui';

    #   start Firewall
    assert_and_click "yast2_control-center_firewall";
    assert_and_click "yast2_control-center_firewall_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Linux Audit Framework LAF
    assert_and_click "yast2_control-center_laf";
    assert_and_click "yast2_control-center_laf_cancel";
    assert_and_click "yast2_control-center_laf_abort";
    assert_and_click "yast2_control-center_laf_abort_really";
    assert_screen 'yast2-control-center-ui';

    #   start Security Center and Hardening
    assert_and_click "yast2_control-center_security-center-and-hardening";
    assert_and_click "yast2_control-center_security-center-and-hardening_cancel";
    assert_screen 'yast2-control-center-ui';

    #	start Sudo
    assert_and_click "yast2_control-center_sudo";
    assert_and_click "yast2_control-center_sudo_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start User and Group Management
    assert_and_click "yast2_control-center_user-and-group-management";
    assert_and_click "yast2_control-center_user-and-group-management_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Install Hypervisor and Tools
    #   need to scroll down to get other modules
    send_key "down";
    assert_and_click "yast2_control-center_install-hypervisor-and-tools";
    assert_and_click "yast2_control-center_install-hypervisor-and-tools_cancel";
    assert_screen 'yast2-control-center-ui';

    #   start Relocation Server Configuration
    assert_and_click "yast2_control-center_relocation-server-configuration";
    assert_and_click "yast2_control-center_relocation-server-configuration_cancel";
    assert_screen 'yast2-control-center-ui';

    # 	finally done and exit
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
