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
use strict;
use warnings;
use testapi;
use transactional;
use utils;
use version_utils;
use Utils::Systemd;
use Utils::Backends;
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

    $self->prepare_services;
}

sub prepare_extensions {
    my $self = shift;

    #Subscribing packagehub that enables access to many useful software tools
    virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => 'PackageHub');
}

sub prepare_packages {
    my $self = shift;

    # Install necessary virtualization client packages
    zypper_call("--non-interactive install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change virt-install libvirt-client libguestfs0 guestfs-tools yast2-schema-micro sshpass");

    if (get_var("INSTALL_OTHER_REPOS")) {

        # SLE Micro is a lightweight operating system purpose built for containerized
        # and virtualized workloads. It does not provide equally abundant functionality
        # compared with SLES, so it becomes necessary to install some useful utilities
        # from SLES repos to facilitate test run. At the same time, ensure it will not
        # alter SLEM and its features and characteristics. Althought operating system
        # should not prevent user from installing legitimate tools and utilities, it
        # is expected that use of additional packages should be limited to the minimum
        # and their impact should be analyzed beforehand.
        my @repos_to_install = split(/,/, get_var("INSTALL_OTHER_REPOS"));
        my @repos_names = ();
        my $repo_name = "";
        foreach (@repos_to_install) {
            $repo_name = (split(/\//, $_))[-1] . "-" . bmwqemu::random_string(8);
            push(@repos_names, $repo_name);
            zypper_call("--non-interactive --gpg-auto-import-keys ar --enable --refresh $_ $repo_name");
            save_screenshot;
        }
        zypper_call("--non-interactive --gpg-auto-import-keys refresh");
        save_screenshot;

        my $cmd = "--non-interactive install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change";
        $cmd = $cmd . " $_" foreach (split(/,/, get_required_var("INSTALL_OTHER_PACKAGES")));
        zypper_call($cmd);
        save_screenshot;

        # Remove additional repos from SLEM after packages installation finishes.
        $cmd = "--non-interactive rr";
        $cmd = $cmd . " $_" foreach (@repos_names);
        zypper_call($cmd);
        save_screenshot;
    }
}

sub prepare_bootloader {
    my $self = shift;

    my $serialconsole = get_serial_console();
    ipmi_backend_utils::add_kernel_options(kernel_opts => "selinux=0 console=tty console=$serialconsole,115200");
    ipmi_backend_utils::set_grub_terminal_and_timeout(terminals => "console serial", timeout => 30);
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
