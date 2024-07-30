# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman, netavark, aardvark
# Summary: Test podman IPv6
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(package_version_cmp is_transactional is_jeos is_leap is_sle_micro is_leap_micro is_sle is_microos is_public_cloud);
use containers::common qw(install_packages);
use publiccloud::utils 'is_gce';

# clean up routine only for systems that run CNI as default network backend
sub _cleanup {
    my $podman = shift->containers_factory('podman');
    select_console 'log-console';
    $podman->cleanup_system_host();

    my $registry_ipv4 = script_output('dig +short registry.opensuse.org A | grep -v suse');
    assert_script_run("iptables -D OUTPUT -d $registry_ipv4 -j DROP");
}

sub run {
    my ($self, $args) = @_;

    die('Please set PUBLIC_CLOUD_GCE_STACK_TYPE=IPV4_IPV6') if (is_gce && !check_var('PUBLIC_CLOUD_GCE_STACK_TYPE', 'IPV4_IPV6'));

    my $image = 'registry.opensuse.org/opensuse/leap:latest';

    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    install_packages('bind-utils');

    # Test host IPv6 connectivity
    assert_script_run('curl -sSf6 -o /dev/null https://opensuse.org');
    # Test openSUSE registry over IPv6
    assert_script_run('curl -sSf6 https://registry.opensuse.org/v2/; echo $?');

    # Block access to openSUSE registry via IPv4
    my $registry_ipv4 = script_output('dig +short registry.opensuse.org A | grep -v suse');
    assert_script_run("iptables -A OUTPUT -d $registry_ipv4 -j DROP");
    validate_script_output('iptables -L OUTPUT', sub { m/$registry_ipv4/g });
    # Test that access to openSUSE registry no longer works via IPv4
    assert_script_run("!curl -sSf4 https://registry.opensuse.org/v2/");
    # Test that access to openSUSE registry still works (IPv6 should work)
    assert_script_run('curl -sSf https://registry.opensuse.org/v2/');
    # Pull image from openSUSE registry (over IPv6 now)
    assert_script_run("podman pull $image", timeout => 300);

    # This is only needed for bsc#1222239 - Host loses default IPv6 route when podman IPv6 network is created
    my $host_if = script_output('ip -6 route show default | awk "{print \$5; exit}"');
    record_info('HOST IF', $host_if);
    my $host_gw = script_output('ip -6 route show default | awk "{print \$3}"');
    record_info('HOST GW', $host_gw);


    # Create the IPv6 network and test container
    assert_script_run('podman network create --ipv6 --subnet fd00:c0de:ba5e::/112 --gateway fd00:c0de:ba5e::1 podman-ipv6');
    assert_script_run("podman run --name test-ipv6 --network podman-ipv6 --ip6 fd00:c0de:ba5e::2 -d $image sleep 999", timeout => 180);

    if (script_output('ip -6 r s default') !~ m/^default via/gi) {
        record_soft_failure('bsc#1222239 - Host loses default IPv6 route when podman IPv6 network is created');
        assert_script_run("ip -6 route add default via $host_gw dev $host_if");
        assert_script_run('ip -6 r s default');
    }

    # Test host IPv6 connectivity
    my $curl_test = '-w "Local: %{local_ip}:%{local_port}\nRemote: %{remote_ip}:%{remote_port}\nReturn: %{http_code}\n"';
    assert_script_run("curl -sSf6 -o /dev/null $curl_test https://opensuse.org");

    # Test container IPv6 connectivity
    #   there is iptables masquarade so the container appears under the host address
    assert_script_run("podman exec -it test-ipv6 curl -sSf6 -o /dev/null $curl_test https://opensuse.org");
}

sub post_run_hook {
    shift->_cleanup();
}
sub post_fail_hook {
    script_run("sysctl -a | grep --color=never net");
    shift->_cleanup();
}

1;
