# PREPARE TRANSACTIONAL SERVER MODULE
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module do preparation work for virtual machine installation on
# transactional server, including extensions registration, packages installation,
# services toggle and other operations that are pertinent to transactonal server
# only or which need to to performed by leveraging transactional-update command.
#
# Maintainer: Wayne Chen <wchen@suse.com> qe-virt@suse.de
package prepare_transactional_server;

use base "opensusebasetest";
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

    $self->prepare_in_trup_shell;
    $self->prepare_on_active_system;
}

sub prepare_in_trup_shell {
    my $self = shift;

    transactional::enter_trup_shell(global_options => '--drop-if-no-change');
    $self->prepare_extensions;
    $self->prepare_packages;
    $self->prepare_bootloader;
    transactional::exit_trup_shell_and_reboot();
}

sub prepare_on_active_system {
    my $self = shift;

    double_check_xen_role if (is_xen_host and is_sle('>=16.1') and is_disk_image);
    check_kvm_modules if (is_kvm_host and is_sle('>=16.1') and is_disk_image);
    $self->prepare_services;
}

sub prepare_extensions {
    my $self = shift;

    virt_autotest::utils::subscribe_extensions_and_modules;
}

sub prepare_packages {
    my $self = shift;

    # install additional packages from product repositories
    install_product_software;
    # install auxiliary packages from additional repositories to facilitate automation, for example screen and etc.
    $self->install_additional_pkgs;
}

sub install_additional_pkgs {
    my $self = shift;

    # install auxiliary packages from additional repositories to facilitate automation, for example screen and etc.
    install_extra_packages;
}

sub prepare_bootloader {
    my $self = shift;

    my $serialconsole = get_serial_console();
    if (is_uefi_boot) {
        ipmi_backend_utils::set_grub_terminal_and_timeout(grub_to_change => 3, terminals => "gfxterm console", timeout => 30);
    }
    else {
        ipmi_backend_utils::set_grub_terminal_and_timeout(terminals => "console serial", timeout => 30);
    }
    ipmi_backend_utils::add_kernel_options(kernel_opts => "console=tty console=$serialconsole,115200");
}

sub prepare_services {
    my $self = shift;

    #Disable rebootmgr service to prevent scheduled maitenance reboot.
    disable_and_stop_service('rebootmgr.service');
    systemctl('status rebootmgr.service', ignore_failure => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
