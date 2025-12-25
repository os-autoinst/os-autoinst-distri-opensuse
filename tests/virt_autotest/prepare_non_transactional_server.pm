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
use testapi;
use transactional;
use utils;
use zypper;
use version_utils;
use Utils::Systemd;
use Utils::Backends qw(get_serial_console);
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;

sub run {
    my $self = shift;

    $self->prepare_ground;
    $self->prepare_console;
    $self->prepare_extensions;
    $self->prepare_packages;
    $self->prepare_bootloader;
    $self->prepare_services;
    $self->prepare_reboot;
    $self->prepare_networks;
    $self->restore_ground;
}

sub prepare_networks {
    my $self = shift;

    # Skip br0 bridge creation if SKIP_HOST_BRIDGE_SETUP is set
    if (get_var('SKIP_HOST_BRIDGE_SETUP')) {
        record_info("Host bridge preparation skipped", "Host bridge preparation skipped due to SKIP_HOST_BRIDGE_SETUP setting");
    } else {
        virt_autotest::virtual_network_utils::create_host_bridge_nm;
    }
}

sub prepare_ground {
    my $self = shift;

    set_var('_NEEDS_REBOOTING', get_var('NEEDS_REBOOTING', 0));
}

sub prepare_console {
    my $self = shift;

    select_backend_console(init => 0);
}

sub prepare_extensions {
    my $self = shift;

    zypper_call("install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change suseconnect-ng");
    virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => get_var('SCC_REGEXTS', ''));
}

sub prepare_packages {
    my $self = shift;

    if (!check_var('DESKTOP', 'textmode')) {
        quit_packagekit;
        wait_quit_zypper;
    }

    # install additional packages from product repositories
    install_product_software;
    # install auxiliary packages from additional repositories to facilitate automation, for example screen and etc.
    install_extra_packages;
}

sub prepare_bootloader {
    my $self = shift;

    my $serialconsole = get_serial_console();
    if (script_run("grep -E \"\\s+linux\\s+/boot/.*console=$serialconsole,115200\" /boot/grub2/grub.cfg") != 0) {
        ipmi_backend_utils::add_kernel_options(kernel_opts => "console=tty console=$serialconsole,115200");
        set_var('_NEEDS_REBOOTING', 1);
    }
}

sub prepare_services {
    my $self = shift;

    # prepare services to facilitate test run
    # no services to be handled at the moment
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

    # recovery to be done here
}

sub test_flags {
    return {fatal => 1};
}

1;
