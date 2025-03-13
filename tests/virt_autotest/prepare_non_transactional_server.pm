# PREPARE NON-TRANSACTIONAL SERVER MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module do preparation work for virtual machine installation on non
# -transactional server, including extensions registration, packages installation,
# services toggle and other operations being pertinent to non-transactonal server
# or which need to to performed in advance for various purposes, including better
# test flow, clear functional division, placeholder for future extension and etc.
#
# Maintainer: Wayne Chen <wchen@suse.com> qe-virt@suse.de
package prepare_non_transactional_server;

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional;
use utils;
use version_utils;
use Utils::Systemd;
use Utils::Backends qw(get_serial_console);
use ipmi_backend_utils;
use virt_autotest::utils;

sub run {
    my $self = shift;

    $self->prepare_ground;
    $self->prepare_extensions;
    $self->prepare_packages;
    $self->prepare_bootloader;
    $self->prepare_services;
    $self->prepare_reboot;
    $self->restore_ground;
}

sub prepare_ground {
    my $self = shift;

    set_var('_NEEDS_REBOOTING', get_var('NEEDS_REBOOTING', 0));
    set_var('NEEDS_REBOOTING', 0);
}

sub prepare_extensions {
    my $self = shift;

    zypper_call("install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change suseconnect-ng");
    virt_autotest::utils::subscribe_extensions_and_modules;
}

sub prepare_packages {
    my $self = shift;

    # spice needs to be installed in advance if virtual machine uses it. spice is not installed by default.
    my $zypper_install_package = "install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change libspice-server1 qemu-audio-spice qemu-chardev-spice qemu-spice qemu-ui-spice-core spice-vdagent";
    zypper_call("$zypper_install_package");
    # install auxiliary packages from additional repositories to facilitate automation, for example screen and etc.
    install_extra_packages;
}

sub prepare_bootloader {
    my $self = shift;

    my $serialconsole = get_serial_console();
    if (script_run("grep -E \"\\s+linux\\s+/boot/.*console=$serialconsole,115200\" /boot/grub2/grub.cfg") != 0) {
        ipmi_backend_utils::add_kernel_options(kernel_opts => "console=tty console=$serialconsole,115200");
        set_var('NEEDS_REBOOTING', 1);
    }
}

sub prepare_services {
    my $self = shift;

    #Disable rebootmgr service to prevent scheduled maitenance reboot.
    disable_and_stop_service('rebootmgr.service');
    systemctl('status rebootmgr.service', ignore_failure => 1);
}

sub prepare_reboot {
    my $self = shift;

    if (is_reboot_needed) {
        process_reboot(trigger => 1);
    }
    else {
        record_info("No reboot needed", "No core libraries changed or no changes need to be refreshed");
    }
}

sub restore_ground {
    my $self = shift;

    set_var('NEEDS_REBOOTING', get_required_var('_NEEDS_REBOOTING'));
}

sub test_flags {
    return {fatal => 1};
}

1;
