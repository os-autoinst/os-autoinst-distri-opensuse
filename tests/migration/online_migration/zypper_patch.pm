# SLE12 online migration tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Fully patch the system before conducting an online migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use Utils::Architectures;
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils qw(is_desktop_installed is_sles4sap);
use migration;
use qam;
use Utils::Backends 'is_pvm';
use bootloader_setup qw(change_grub_config);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    disable_installation_repos;
    add_test_repositories;
    set_zypp_single_rpmtrans;
    fully_patch_system;
    # Sometimes update package 'polkit' will cause GDM restart, so after
    # update patches we'd better to select_console to make test robust.
    select_console 'root-console';
    install_patterns() if (get_var('PATTERNS'));
    # Install openldap package as required
    if ((get_var('FLAVOR') =~ /Regression/) && check_var('HDDVERSION', '15-SP3') && is_x86_64) {
        zypper_call("in sssd sssd-tools sssd-ldap openldap2 openldap2-client");
    }
    deregister_dropped_modules;
    # disable multiversion for kernel-default based on bsc#1097111, for migration continuous cases only
    if (get_var('FLAVOR', '') =~ /Continuous-Migration/) {
        modify_kernel_multiversion("disable");
    }
    workaround_bsc_1220091;
    cleanup_disk_space if get_var('REMOVE_SNAPSHOTS');
    # Sometimes we can't wait the grub screen before it booting into system,
    # we can change the GRUB_TIMEOUT in /etc/default/grub to fix this.
    my $timeout = get_var('GRUB_TIMEOUT');
    change_grub_config('=.*', "=$timeout", 'GRUB_TIMEOUT', '', 1) if (length $timeout);
    power_action('reboot', keepconsole => 1, textmode => 1);
    reconnect_mgmt_console if is_pvm;

    # Do not attempt to log into the desktop of a system installed with SLES4SAP
    # being prepared for upgrade, as it does not have an unprivileged user to test
    # with other than the SAP Administrator
    $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 300, ready_time => 600, nologin => is_sles4sap);
    $self->setup_migration;
}

sub test_flags {
    return {fatal => 1};
}

1;
