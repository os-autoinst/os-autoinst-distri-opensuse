# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup system which will host containers
# - setup networking via dhclient when is needed
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(check_os_release get_os_release is_sle is_sle_micro);
use containers::common;
use containers::utils qw(reset_container_network_if_needed);

sub run {
    select_serial_terminal;
    my $interface;
    my $update_timeout = 2400;    # aarch64 takes sometimes 20-30 minutes for completion
    my ($version, $sp, $host_distri) = get_os_release;
    my $engine = get_required_var('CONTAINER_RUNTIMES');

    # Update the system to get the latest released state of the hosts.
    # Check routing table is well configured
    if ($host_distri =~ /sle|opensuse/) {
        my $host_version = get_var('HOST_VERSION');
        $host_version = ($host_version =~ /SP/) ? ("SLE_" . $host_version =~ s/-SP/_SP/r) : $host_version;
        zypper_call("--quiet up", timeout => $update_timeout);
        # Cannot use `ensure_ca_certificates_suse_installed` as it will depend
        # on the BCI container version instead of the host
        if (script_run('rpm -qi ca-certificates-suse') == 1) {
            if ($host_version) {
                zypper_call("ar --refresh http://download.suse.de/ibs/SUSE:/CA/$host_version/SUSE:CA.repo");
            } else {
                zypper_call("ar --refresh http://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo");
                zypper_call("--gpg-auto-import-keys -n install ca-certificates-suse");
            }
            zypper_call("in ca-certificates-suse");
        }
    }
    else {
        if ($host_distri eq 'ubuntu') {
            # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
            assert_script_run("dhclient -v");
            script_retry("apt-get update -qq -y", timeout => $update_timeout);
        } elsif ($host_distri eq 'centos') {
            assert_script_run("dhclient -v");
            script_retry("yum update -q -y --nobest", timeout => $update_timeout);
        } elsif ($host_distri eq 'rhel') {
            script_retry("yum update -q -y", timeout => $update_timeout);
        }
    }

    # Install engines in case they are not installed
    install_docker_when_needed($host_distri) if ($engine =~ 'docker');
    install_podman_when_needed($host_distri) if ($engine =~ 'podman');
    reset_container_network_if_needed($engine);

    # Record podman|docker version
    foreach my $eng (split(',\s*', $engine)) {
        record_info($eng, script_output("$eng info"));
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
