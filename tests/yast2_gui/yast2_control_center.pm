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
        assert_screen([qw(yast2_control-center_search_clear yast2_control-center_search)], no_wait => 1);
        if (match_has_tag 'yast2_control-center_search') {
            assert_and_click 'yast2_control-center_search';
        }
        else {
            assert_and_click 'yast2_control-center_search_clear';
        }
    }
    wait_screen_change { type_string $name; } if $name;
    wait_still_screen 1;
}

sub start_addon_products {
    assert_and_click 'yast2_control-center_add-on';
    assert_screen 'yast2_control-center_add-on_installed', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_add_system_extensions_or_modules {
    assert_and_click 'yast2_control-center_add-system-extensions-or-modules';
    assert_screen 'yast2_control-center_registration', timeout => 180;
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_media_check {
    assert_and_click 'yast2_control-center_media-check';
    assert_screen 'yast2_control-center_media-check_close', timeout => 180;
    wait_still_screen;
    send_key 'alt-l';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_online_update {
    assert_and_click 'yast2_control-center_online-update';
    assert_screen [qw(yast2_control-center_update-repo-dialogue yast2_control-center_online-update_close)];
    if (match_has_tag('yast2_control-center_update-repo-dialogue')) {
        send_key 'alt-n';
        assert_screen 'yast2_control-center_online-update_close';
    }
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_software_repositories {
    search('software');
    assert_and_click 'yast2_control-center_software-repositories';
    assert_screen 'yast2_control-center_configured-software-repositories', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_sound {
    search('sound');
    assert_and_click 'yast2_control-center_sound';
    assert_screen 'yast2_control-center_sound_configuration';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_fonts {
    search('fonts');
    assert_and_click 'yast2_control-center_fonts';
    assert_screen 'yast2_control-center_fonts-configuration', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_sysconfig_editor {
    search('sysconfig');
    assert_and_click 'yast2_control-sysconfig-editor';
    assert_screen 'yast2_control-center_etc-sysconfig-editor', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_kernel_dump {
    search('dump');
    assert_and_click 'yast2_control-kernel-kdump';
    assert_screen 'yast2_control-center_kernel-kdump-configuration', timeout => 180;
    assert_and_click 'yast2_control-kernel-kdump-configuration_ok';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_kernel_settings {
    search('kernel');
    assert_and_click 'yast2_control-center-kernel-settings';
    assert_screen 'yast2_control-center_kernel-settings_pci-id-setup', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_partitioner {
    search('partitioner');
    assert_and_click 'yast2_control-center-partitioner';
    assert_screen 'yast2_control-center-partitioner_warning', timeout => 180;
    send_key 'alt-y';
    assert_screen 'yast2_control-center-partitioner_expert', timeout => 60;
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_authentication_server {
    search 'authentication';
    assert_and_click 'yast2_control-center_authentication-server';
    assert_screen [qw(yast2_control-center-authentication-server_install yast2_control-center-authentication-server_configuration)], 90;
    if (match_has_tag('yast2_control-center-authentication-server_install')) {
        send_key 'alt-i';
        assert_screen 'yast2_control-center-authentication-server_configuration';
        send_key 'alt-c';
    }
    else {
        assert_screen 'yast2_control-center-authentication-server_configuration';
        send_key 'alt-o';
    }
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_user_logon_management {
    search('user');
    assert_and_click 'yast2_control-center_user-logon-management';
    assert_screen 'yast2_control-center_user-logon-management_finish', timeout => 180;
    send_key 'alt-f';
    assert_screen 'yast2_control-center_user-logon-management_new-users';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 180;
}

sub start_vpn_gateway {
    search('vpn');
    assert_and_click 'yast2_control-center_vpn-gateway-client';
    assert_screen 'yast2_control-center_vpn-gateway-client_cancel', timeout => 180;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_wake_on_lan {
    search('wake');
    assert_and_click 'yast2_control-center_wake-on-lan';
    assert_screen 'yast2_control-center_wake-on-lan_install_cancel', 60;
    send_key 'alt-c';
    assert_screen 'yast2_control-center_wake-on-lan_install_error';
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_ca_management {
    search('ca');
    assert_and_click 'yast2_control-center_ca-management';
    assert_screen 'yast2_control-center_ca-management_abort', 60;
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui';
}

sub start_common_server_certificate {
    search('ca');
    assert_and_click 'yast2_control-center_common-server-certificate';
    assert_screen 'yast2_control-center_common-server-certificate_abort';
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui';
}

sub start_security_center {
    search('security');
    assert_and_click 'yast2_control-center_security-center-and-hardening';
    assert_screen 'yast2_control-center_security-center-and-hardening_overview', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_sudo {
    search('sudo');
    assert_and_click 'yast2_control-center_sudo';
    assert_screen 'yast2_control-center_sudo_rules', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_user_and_group_management {
    search('user and');
    assert_and_click 'yast2_control-center_user-and-group-management';
    assert_screen 'yast2_control-center_user-and-group-management_users', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_hypervisor {
    search('hypervisor');
    assert_and_click 'yast2_control-center_install-hypervisor-and-tools';
    assert_screen 'yast2_control-center_install-hypervisor-and-tools_cancel', timeout => 180;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', 60;
}

sub start_printer {
    # for now only test on SLE as openSUSE looks different. Can be extended
    # later
    if (check_var('DISTRI', 'sle')) {
        search('print');
        assert_and_click 'yast2_control-center_printer';
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
        assert_screen 'yast2_control-center_printer_configurations';
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui', 60;
    }
    elsif (check_var('DISTRI', 'opensuse')) {
        search('print');
        assert_and_click 'yast2_control-center_printer';
        assert_screen 'yast2_control-center_printer_configurations', timeout => 180;
        wait_still_screen;
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui', 60;
    }
}

sub run {
    my $self = shift;
    $self->launch_yast2_module_x11;
    assert_screen 'yast2-control-center-ui', timeout => 180;

    # search module by typing string
    search('add');
    assert_screen 'yast2_control-center_search_add', 60;

    # start yast2 modules
    for (1 .. 6) {
        send_key 'backspace';
    }

    start_addon_products;
    start_media_check;
    start_online_update;
    start_software_repositories;
    start_printer;
    start_sound;
    start_fonts;
    start_sysconfig_editor;
    start_partitioner;
    start_vpn_gateway;
    start_security_center;
    start_sudo;
    start_user_and_group_management;
    start_hypervisor;
    if (check_var('DISTRI', 'sle')) {
        start_add_system_extensions_or_modules;
        start_kernel_dump;
        start_common_server_certificate;
        start_ca_management;
        start_wake_on_lan;
        # available by default only on SLES
        start_authentication_server;
    }
    if (check_var('DISTRI', 'opensuse')) {
        start_kernel_settings;
        # only available on openSUSE or at least not SLES
        start_fonts;
    }

    #  finally done and exit
    wait_screen_change { send_key 'alt-f4'; };
}

1;
# vim: set sw=4 et:
