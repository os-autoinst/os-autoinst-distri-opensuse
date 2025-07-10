# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup system which will host containers
# - setup networking via dhclient when is needed
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use network_utils qw(get_nics cidr_to_netmask is_nm_used is_wicked_used delete_all_existing_connections set_nics_link_speed_duplex check_connectivity_to_host_with_retry set_resolv set_nic_dhcp_auto reload_connections_until_all_ips_assigned setup_dhcp_server_network is_running_in_isolated_network get_default_dns);
use main_containers qw(is_suse_host);
use utils;
use version_utils qw(check_os_release get_os_release is_sle is_sle_micro is_transactional is_bootloader_grub2);
use containers::common;
use containers::utils qw(reset_container_network_if_needed);
use containers::k8s qw(install_k3s);
use transactional qw(trup_call process_reboot);
use bootloader_setup qw(add_grub_cmdline_settings);
use power_action_utils qw(power_action);

sub setup_networking_in_isolated_network {
    my ($self, $nics_ref) = @_;
    my @nics = @$nics_ref;
    my $nic0 = $nics[0];

    my $server_ip = "10.0.2.101";
    my $subnet = "/24";
    my $gateway = "10.0.2.2";
    my $dns_string = get_var("DNS", get_default_dns());
    my @dns = ($dns_string ne "") ? split(",", $dns_string) : ();

    setup_dhcp_server_network(
        server_ip => $server_ip,
        subnet => $subnet,
        gateway => $gateway,
        nics => \@nics,
        dns => \@dns
    );

    set_resolv(nameservers => \@dns);

    install_packages("ethtool") if is_suse_host();

    # NICVLAN does not autonegotiate link speed and duplex, so we need to set it manually
    set_nics_link_speed_duplex({
            nics => \@nics,
            speed => 1000,
            duplex => 'full',
            autoneg => 'off'
    });
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    setup_networking_in_isolated_network($self, [get_nics([])]) if is_running_in_isolated_network();

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
            assert_script_run("dhclient -v") unless is_running_in_isolated_network();
            script_retry("apt-get update -qq -y", timeout => $update_timeout);
        } elsif ($host_distri eq 'centos') {
            # dhclient is no longer available in CentOS 10
            script_run("dhclient -v") unless is_running_in_isolated_network();
            script_retry("dnf update -q -y --nobest", timeout => $update_timeout);
        } elsif ($host_distri eq 'rhel') {
            script_retry("dnf update -q -y", timeout => $update_timeout);
        }
    }

    # Install engines in case they are not installed
    install_docker_when_needed() if ($engine =~ 'docker');
    install_podman_when_needed() if ($engine =~ 'podman|k3s' && !is_sle("=12-SP5", get_var('HOST_VERSION', get_required_var('VERSION'))));

    if ($engine =~ 'k3s') {
        install_k3s();
        script_run("systemctl disable --now firewalld");    # Disable firewall for k3s but don't fail if not installed
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
