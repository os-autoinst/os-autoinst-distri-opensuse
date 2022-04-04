# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup system which will host containers
# - setup networking via dhclient when is needed
# - make sure that ca certifications were installed
# - import SUSE CA certificates
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use version_utils qw(check_os_release get_os_release is_sle);
use containers::common;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $interface;
    my $update_timeout = 1200;
    my ($version, $sp, $host_distri) = get_os_release;
    my $engine = get_required_var('CONTAINER_RUNTIME');

    # Update the system to get the latest released state of the hosts.
    # Check routing table is well configured
    if ($host_distri =~ /sles|opensuse/) {
        zypper_call("--quiet up", timeout => $update_timeout);
        ensure_ca_certificates_suse_installed();
    }
    else {
        if ($host_distri eq 'ubuntu') {
            # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
            assert_script_run("dhclient -v");
            assert_script_run("apt-get update -qq -y", timeout => $update_timeout);
        } elsif ($host_distri eq 'centos') {
            assert_script_run("dhclient -v");
            assert_script_run("yum update -q -y --nobest", timeout => $update_timeout);
        } elsif ($host_distri eq 'rhel') {
            assert_script_run("yum update -q -y", timeout => $update_timeout);
        }
    }

    # Install engines in case they are not installed
    install_docker_when_needed($host_distri) if ($engine =~ 'docker');
    install_podman_when_needed($host_distri) if ($engine =~ 'podman');

    # It has been observed that after system update, the ip forwarding doesn't work.
    # Sometimes there is a need to restart the firewall and docker daemon.
    if ($host_distri =~ /sles|opensuse/) {
        # We can't use opensusebasetest::firewall here because VERSION variable referrs to the container image.
        my $firewall = $version =~ /12/ ? 'SuSEfirewall2' : 'firewalld';
        systemctl("restart docker") if ($engine =~ 'docker');
        systemctl("restart $firewall");
    }

    # Record podman|docker version
    foreach my $eng (split(',\s*', $engine)) {
        record_info($eng, script_output("$eng info"));
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
