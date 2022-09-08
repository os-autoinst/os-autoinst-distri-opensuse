# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-control-center-qt yast2-kdump yast2-boot-server yast2-sound
# Summary: YaST2 UI test yast2-control-center provides sanity checks for YaST modules
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_opensuse is_sle is_leap is_tumbleweed is_storage_ng);

sub search {
    my ($name) = @_;
    # with the gtk interface we have to click as there is no shortcut
    if (is_sle('<15') || is_leap('<15.0')) {
        assert_screen([qw(yast2_control-center_search_clear yast2_control-center_search)], no_wait => 1);
        if (match_has_tag 'yast2_control-center_search') {
            assert_and_click 'yast2_control-center_search';
        }
        else {
            assert_and_click 'yast2_control-center_search_clear';
        }
        # openSUSE and sles 15 have a Qt setup with keyboard shortcut
    }
    else {
        send_key 'alt-s';
        send_key 'ctrl-a';
        send_key 'backspace';
    }
    wait_screen_change { type_string $name; } if $name;
}

sub start_addon_products {
    search('add-on');
    assert_and_click 'yast2_control-center_add-on';
    my @tags = qw(yast2_control-center_add-on_installed yast2_control-center-ask_packagekit_to_quit);
    do {
        assert_screen \@tags;
        # Let it kill PackageKit, in case it is running.
        wait_screen_change { send_key 'alt-y' } if match_has_tag('yast2_control-center-ask_packagekit_to_quit');
    } until (match_has_tag('yast2_control-center_add-on_installed'));
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_media_check {
    search 'check';
    assert_and_click 'yast2_control-center_media-check';
    wait_still_screen;
    assert_screen 'yast2_control-center_media-check_close';
    send_key 'alt-l';
    assert_screen 'yast2-control-center-ui';
}

sub start_online_update {
    search 'online update';
    # to test the online update configuration dialog we need update repos
    # which are removed unless explicitly selected to be kept
    if (is_opensuse && !get_var('KEEP_ONLINE_REPOS')) {
        select_console 'root-console';
        my $version = lc get_required_var('VERSION');
        my $update_name = is_tumbleweed() ? $version : 'leap/' . $version . '/oss';
        my $repo_arch = get_required_var('ARCH');
        $repo_arch = 'ppc' if ($repo_arch =~ /ppc64|ppc64le/);
        if ($repo_arch =~ /i586|i686|x86_64/) {
            zypper_call("ar -f http://download.opensuse.org/update/$update_name repo-update");
        } else {
            if (is_tumbleweed()) {
                zypper_call("ar -f http://download.opensuse.org/ports/$repo_arch/update/tumbleweed repo-update");
            } else {
                zypper_call("ar -f http://download.opensuse.org/ports/update/$update_name repo-update");
            }
        }
        select_console 'x11', await_console => 0;
    }
    assert_and_click 'yast2_control-center_online-update';
    my @tags = qw(yast2_control-center_update-repo-dialogue yast2_control-center_online-update_close yast2_control-center-ask_packagekit_to_quit);
    do {
        assert_screen \@tags;
        wait_screen_change { send_key 'alt-n' } if match_has_tag('yast2_control-center_update-repo-dialogue');
        # Let it kill PackageKit, in case it is running.
        wait_screen_change { send_key 'alt-y' } if match_has_tag('yast2_control-center-ask_packagekit_to_quit');
    } until (match_has_tag('yast2_control-center_online-update_close'));

    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_software_repositories {
    search('software repo');
    assert_and_click 'yast2_control-center_software-repositories';
    my @tags = qw(yast2_control-center_configured-software-repositories yast2_control-center-ask_packagekit_to_quit);
    do {
        assert_screen \@tags;
        # Let it kill PackageKit, in case it is running.
        wait_screen_change { send_key 'alt-y' } if match_has_tag('yast2_control-center-ask_packagekit_to_quit');
    } until (match_has_tag('yast2_control-center_configured-software-repositories'));
    send_key 'alt-o';

    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_printer {
    search('printer');
    # for now only test on SLE as openSUSE looks different. Can be extended
    # later
    if (is_sle) {
        search('print');
        assert_and_click 'yast2_control-center_printer';
        assert_screen 'yast2_control-center_printer_running-cups-daemon', timeout => 60;
        send_key 'alt-y';
        # need to wait for Restarted CUPS daemon or Failed to restart CUPS
        assert_screen [qw(yast2_control-center_printer_running-cups-daemon_no-delay yast2_control-center_printer_error-cups-restart-failed), timeout => 60];
        if (match_has_tag('yast2_control-center_printer_running-cups-daemon_no-delay')) {
            send_key 'alt-o';
            assert_screen 'yast2_control-center_printer_running-cups-daemon_enabled';
            send_key 'alt-y';
        }
        else {
            send_key 'alt-o';
        }
        assert_screen 'yast2_control-center_printer_configurations';
        send_key 'alt-o';

        assert_screen 'yast2-control-center-ui', timeout => 120;
        # test case if not restart cups daemon locally
        select_console 'root-console';
        systemctl 'stop cups.service';
        select_console 'x11', await_console => 0;
        assert_screen 'yast2-control-center-ui';
        send_key 'up';
        assert_and_click 'yast2_control-center_printer';
        assert_screen 'yast2_control-center_printer_running-cups-daemon', timeout => 60;
        send_key 'alt-n';
        assert_screen 'yast2_control-center_printer_running-cups-daemon_error';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_detect-printer-queues_error';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_show-printer-queues_error';
        send_key 'alt-o';
        assert_screen 'yast2_control-center_printer_configurations';
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui', timeout => 60;
    }
    elsif (is_opensuse) {
        search('print');
        assert_and_click 'yast2_control-center_printer';
        assert_screen 'yast2_control-center_printer_configurations', timeout => 180;
        wait_still_screen;
        send_key 'alt-o';
        assert_screen 'yast2-control-center-ui', timeout => 60;
    }
}

sub start_sound {
    search('sound');
    assert_and_click 'yast2_control-center_sound';
    assert_screen 'yast2_control-center_sound_configuration', timeout => 180;
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

sub start_partitioner {
    search('partitioner');
    assert_and_click 'yast2_control-center-partitioner';
    assert_screen [qw(yast2_control-center-partitioner_warning yast2_control-center-partitioner_expert)], timeout => 180;
    # Define if storage-ng
    set_var('STORAGE_NG', 1) if match_has_tag 'storage-ng';

    if (match_has_tag 'yast2_control-center-partitioner_warning') {
        send_key 'alt-y';
    }
    elsif (is_storage_ng && match_has_tag 'yast2_control-center-partitioner_expert') {
        # Soft-fail if storage ng and no warning is shown
        record_soft_failure 'bsc#1068905';
    }
    else {
        # Fail with expected assertion in case no match
        assert_screen 'yast2_control-center-partitioner_warning', 0;
    }
    assert_screen 'yast2_control-center-partitioner_expert', timeout => 60;
    send_key 'alt-f';

    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_vpn_gateway {
    search('vpn');
    assert_and_click 'yast2_control-center_vpn-gateway-client';
    record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
    send_key_until_needlematch('yast2-vpn-gateway-client', 'alt-f10', 20, 9);
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_security_center {
    search('security center');
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
    search('user and group');
    assert_and_click 'yast2_control-center_user-and-group-management';
    assert_screen 'yast2_control-center_user-and-group-management_users', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_hypervisor {
    search('hypervisor');
    assert_and_click 'yast2_control-center_install-hypervisor-and-tools';
    assert_screen 'yast2-install-hypervisor-and-tools', timeout => 180;
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_add_system_extensions_or_modules {
    search 'system ext';
    assert_and_click 'yast2_control-center_add-system-extensions-or-modules';
    record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
    send_key_until_needlematch('yast2_control-center_registration', 'alt-f10', 10, 2);
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_kernel_dump {
    search('dump');
    assert_and_click 'yast2_control-kernel-kdump';
    assert_and_click 'yast2_control-install-kdump';
    assert_screen 'yast2_control-center_kernel-kdump-configuration', timeout => 180;
    send_key 'alt-o';    # Press ok
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_common_server_certificate {
    search('cert');
    assert_and_click 'yast2_control-center_common-server-certificate';
    assert_screen 'yast2-common-server-certificate', timeout => 180;
    send_key 'alt-r';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_ca_management {
    search('ca management');
    assert_and_click 'yast2_control-center_ca-management';
    assert_screen 'yast2-ca-management', timeout => 180;
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_wake_on_lan {
    search('wake');
    assert_and_click 'yast2_control-center_wake-on-lan';
    assert_screen 'yast2_control-center_wake-on-lan_install_wol';
    send_key $cmd{install};    # wol needs to be installed
    record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
    send_key_until_needlematch('yast2_control-center_wake-on-lan_overview', 'alt-f10', 10, 2);
    send_key 'alt-f';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_directory_server {
    search 'directory server';
    assert_and_click 'yast2_control-center_authentication-server';
    do {
        assert_screen [
            qw(yast2_control-center-authentication-server_install yast2_control-center-authentication-server_configuration yast2_control-center-authentication-server_empty_first_page)
        ], timeout => 180;
        send_key 'alt-i' if match_has_tag 'yast2_control-center-authentication-server_install';
        send_key 'alt-n' if match_has_tag 'yast2_control-center-authentication-server_empty_first_page';
    } until (match_has_tag 'yast2_control-center-authentication-server_configuration');
    # cancel, just check the first page
    send_key 'alt-c';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_kernel_settings {
    search('kernel settings');
    assert_and_click 'yast2_control-center-kernel-settings';
    assert_screen 'yast2_control-center_kernel-settings_pci-id-setup', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub start_fonts {
    search('fonts');
    assert_and_click 'yast2_control-center_fonts';
    assert_screen 'yast2_control-center_fonts-configuration', timeout => 180;
    send_key 'alt-o';
    assert_screen 'yast2-control-center-ui', timeout => 60;
}

sub run {
    select_console 'x11';
    if (is_sle '15+') {
        # kdump is disabled by default in the installer, so ensure that it's installed
        ensure_installed 'yast2-kdump';
        # see bsc#1062331, sound is not added to the yast2 pattern
        ensure_installed 'yast2-boot-server yast2-sound';
    }
    elsif (is_tumbleweed || is_leap('>15.3')) {
        record_soft_failure('bsc#1182125 - yast2-online-update-frontend is not pre-installed on TW');
        ensure_installed('yast2-online-update-frontend');
        record_soft_failure('bsc#1182241 - yast2-vpn is not pre-installed on TW and Leap');
        ensure_installed('yast2-vpn yast2-sudo yast2-tune yast2-kdump');
    }
    y2_module_guitest::launch_yast2_module_x11('', target_match => 'yast2-control-center-ui', match_timeout => 180);

    start_addon_products;
    start_media_check;
    start_online_update;
    start_software_repositories;
    start_printer;
    start_sound;
    start_sysconfig_editor;
    start_partitioner;
    start_vpn_gateway;
    start_security_center;
    start_sudo;
    start_user_and_group_management;

    if (is_sle) {
        start_hypervisor;
        start_add_system_extensions_or_modules;
        start_kernel_dump;
        # YaST2 CA management has been dropped from SLE15, see
        # https://bugzilla.suse.com/show_bug.cgi?id=1059569#c14
        if (is_sle('15+')) {
            start_directory_server;
        }
        else {
            start_common_server_certificate;
            start_ca_management;
        }
        start_wake_on_lan;
    }
    if (is_opensuse) {
        start_kernel_settings;
    }
    # only available on openSUSE or at least not SLES
    # drop fonts test for leap 15.0, see poo#29292
    if (is_leap('<15.0')) {
        start_fonts;
    }

    #  finally done and exit
    wait_screen_change { send_key 'alt-f4'; };
}

1;
