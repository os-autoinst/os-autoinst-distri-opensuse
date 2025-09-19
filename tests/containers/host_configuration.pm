# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup system which will host containers
# - setup networking via dhclient when is needed
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use main_containers qw(is_suse_host);
use utils;
use version_utils qw(check_os_release get_os_release is_sle is_sle_micro is_bootloader_grub2);
use containers::common;
use containers::utils qw(reset_container_network_if_needed);
use containers::k8s qw(install_k3s);
use bootloader_setup qw(add_grub_cmdline_settings);
use power_action_utils qw(power_action);
use zypper qw(wait_quit_zypper);
use containers::bats;
use Utils::Architectures qw(is_x86_64 is_aarch64);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $interface;
    my $update_timeout = 2400;    # aarch64 takes sometimes 20-30 minutes for completion
    my ($version, $sp, $host_distri) = get_os_release;
    my $engine = get_required_var('CONTAINER_RUNTIMES');

    # Update the system to get the latest released state of the hosts.
    # Check routing table is well configured
    if ($host_distri =~ /sle|opensuse/) {
        zypper_call("--quiet up", timeout => $update_timeout);
        # Cannot use `ensure_ca_certificates_suse_installed` as it will depend
        # on the BCI container version instead of the host
        if (script_run('rpm -qi ca-certificates-suse') == 1) {
            zypper_call("addrepo --refresh https://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo");
            zypper_call("--gpg-auto-import-keys -n install ca-certificates-suse");
        }

        # some images do not have quiet option in kernel parameters
        if (is_bootloader_grub2 && script_run('grep -q quiet /proc/cmdline') != 0) {
            add_grub_cmdline_settings('quiet', update_grub => 1);
            power_action("reboot", textmode => 1);
            $self->wait_boot(textmode => 1);
            select_serial_terminal;
        }
    }
    else {
        # post_{fail|run}_hooks are not working with 3rd party hosts
        set_var('NOLOGS', 1);
        if ($host_distri eq 'ubuntu') {
            # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
            assert_script_run("dhclient -v");
            script_retry("apt-get update -qq -y", timeout => $update_timeout);
        } elsif ($host_distri eq 'centos') {
            # dhclient is no longer available in CentOS 10
            script_run("dhclient -v");
            script_retry("dnf update -q -y --nobest", timeout => $update_timeout);
        } elsif ($host_distri eq 'rhel') {
            script_retry("dnf update -q -y", timeout => $update_timeout);
        }
    }

    # Install engines in case they are not installed
    # Make sure packagekit is not running, or it will conflict with SUSEConnect.
    quit_packagekit;
    # poo#87850 wait the zypper processes in background to finish and release the lock.
    wait_quit_zypper;

    # docker GO tests build Rancher (only x86_64 and aarch64) that requires a significant size of tmpfs
    # sle-micro tmp.mount allocates 50% for tmpfs by default setup
    if ((is_x86_64 || is_aarch64) && $engine =~ /docker/ && get_var('HOST_VERSION', '') =~ /slem/i && get_var('BCI_IMAGE_NAME', '') =~ /golang/) {
        script_run('systemctl disable --now k3s.service');
        mount_tmp_vartmp;
    }

    install_docker_when_needed() if ($engine =~ 'docker');
    install_podman_when_needed() if ($engine =~ 'podman|k3s' && !is_sle("=12-SP5", get_var('HOST_VERSION', get_required_var('VERSION'))));

    if ($engine =~ 'k3s') {
        # Disable firewall for k3s but don't fail if not installed
        if ($version eq '12') {
            script_run('systemctl disable SuSEfirewall2');
            add_grub_cmdline_settings('apparmor=0', update_grub => 1);
            power_action("reboot", textmode => 1);
            $self->wait_boot(textmode => 1);
            select_serial_terminal;
        } else {
            script_run('systemctl disable --now firewalld');
        }
        install_k3s();
    } else {
        reset_container_network_if_needed($engine);
    }

    # Record podman|docker version
    record_info("docker info", script_output("docker info")) if ($engine =~ 'docker');
    record_info("podman info", script_output("podman info")) if ($engine =~ 'podman');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
