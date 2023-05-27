# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman, netavark, aardvark
# Summary: Test podman netavark network backend
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(package_version_cmp is_transactional is_jeos);
use containers::utils qw(get_podman_version registry_url);
use transactional qw(trup_call check_reboot_changes);
use utils qw(zypper_call);
use Utils::Systemd qw(systemctl);

sub remove_subtest_setup {
    assert_script_run("podman container rm -af");
    assert_script_run("podman network prune -f");
    validate_script_output("podman network ls --noheading", sub { /^\w+\s+podman\s+bridge$/ });
    validate_script_output("podman ps -a --noheading", sub { /^\s*$/ });
}

sub _cleanup {
    my $podman = shift->containers_factory('podman');
    select_console 'log-console';
    remove_subtest_setup;
    script_run('rm -rf /etc/containers/containers.conf');
    $podman->cleanup_system_host();
    validate_script_output('podman info --format {{.Host.NetworkBackend}}', sub { /cni/ });
    validate_script_output('podman network ls', sub { /podman\s+bridge/ });
}

sub switch_to_netavark {
    my @pkgs = qw(netavark aardvark-dns);

    if (is_transactional) {
        trup_call("pkg install @pkgs");
        check_reboot_changes;
    } else {
        zypper_call("in @pkgs");
    }

    # change network backend to *netavark*
    assert_script_run(q(echo -e '[Network]\nnetwork_backend="netavark"' >> /etc/containers/containers.conf));
    # reset the storage back to the initial state
    assert_script_run('podman system reset --force');
    validate_script_output('podman info --format {{.Host.NetworkBackend}}', sub { /netavark/ });
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    my $podman_version = get_podman_version();

    if (package_version_cmp($podman_version, '4.0.0') < 0) {
        record_info('No support', "Netavark backend is not supported in podman-$podman_version");
        return 1;
    }

    switch_to_netavark;
    $podman->cleanup_system_host();

    ## TEST1
    record_info('TEST1', 'set static IP, and MAC addresses on a per-network basis');
    my $net1 = {
        name => 'simple',
        gateway => '10.90.0.1',
        subnet => '10.90.0.0/16',
        gateway_v6 => 'fd00::1:8:1',
        subnet_v6 => 'fd00::1:8:0/112'
    };
    my $ctr1 = {
        image => registry_url('httpd'),
        name => 'apache_ctr',
        ip => '10.90.0.8',
        mac => '76:22:33:44:55:66',
        ip6 => 'fd00::1:8:9',
        name6 => 'apache_ctr_ipv6'
    };

    assert_script_run("podman network create --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman run --network $net1->{name}:ip=$ctr1->{ip},mac=$ctr1->{mac} -d --name $ctr1->{name} $ctr1->{image}");
    assert_script_run("podman container inspect $ctr1->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
    validate_script_output("curl --head --silent $ctr1->{ip}:80", sub { /HTTP.* 200 OK/ });
    assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
    remove_subtest_setup;

    ## TEST2
    record_info('TEST2', 'set static IPs for containers and check their networking');
    $net1->{name} = 'primary';
    my $net2 = {
        name => 'secondary',
        gateway => '10.64.0.1',
        subnet => '10.64.0.0/16',
    };
    my $ctr2 = {
        image => 'registry.opensuse.org/bci/bci-busybox',
        name => 'busybox_ctr',
        ip => '10.64.0.8',
        mac => '92:aa:33:44:55:66',
        ip_sec => '10.90.0.64',
        mac_sec => '92:bb:cc:44:55:66'
    };

    assert_script_run("podman network create --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman network create --gateway $net2->{gateway} --subnet $net2->{subnet} $net2->{name}");
    assert_script_run("podman run --network $net1->{name}:ip=$ctr1->{ip},mac=$ctr1->{mac} -d --name $ctr1->{name} $ctr1->{image}");
    assert_script_run("podman run --network $net2->{name}:ip=$ctr2->{ip},mac=$ctr2->{mac} --network $net1->{name}:ip=$ctr2->{ip_sec},mac=$ctr2->{mac_sec} -dt --name $ctr2->{name} $ctr2->{image}");

    # second container should have 2 interfaces
    my $net1_reg = qr@ether\s+$ctr2->{mac}.*\s+inet\s+$ctr2->{ip}\/16@;
    my $net2_reg = qr@ether\s+$ctr2->{mac_sec}.*\s+inet\s+$ctr2->{ip_sec}\/16@;
    validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'ip addr show eth0'", sub { /$net1_reg|$net2_reg/m });
    validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'ip addr show eth1'", sub { /$net1_reg|$net2_reg/m });

    # busybox container should be able to resolve apache container
    validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'nslookup $ctr1->{name}'", sub { /Name:\s+$ctr1->{name}\s+Address.*$ctr1->{ip}/m });
    validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'wget -S $ctr1->{ip}:80'", sub { /HTTP.* 200 OK/ });
    assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
    assert_script_run("grep $ctr2->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
    assert_script_run("grep $ctr2->{name} /run/containers/networks/aardvark-dns/$net2->{name}");
    remove_subtest_setup;

    ## TEST3
    record_info('TEST3', 'create a dual stack network');
    $net1->{name} = 'test_dual_stack';
    assert_script_run("podman network create --ipv6 --gateway $net1->{gateway_v6} --subnet $net1->{subnet_v6} --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman run --network $net1->{name} -d --name $ctr1->{name6} --ip6 $ctr1->{ip6} -p 8080:80 $ctr1->{image}");
    assert_script_run("podman run --network $net1->{name} -d --name $ctr1->{name} --ip $ctr1->{ip} -p 8888:80 $ctr1->{image}");

    foreach my $req ((
            "-6 http://[$ctr1->{ip6}]:80",
            "-4 http://$ctr1->{ip}:80",
            'http://localhost:8080',
            'http://localhost:8888'
    )) {
        validate_script_output("curl --retry 5 --head --silent $req", sub { /HTTP.* 200 OK/ }, timeout => 120);
    }

    assert_script_run("podman container inspect $ctr1->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
    assert_script_run("podman container inspect $ctr1->{name6} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
    assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
    assert_script_run("grep $ctr1->{name6} /run/containers/networks/aardvark-dns/$net1->{name}");
    remove_subtest_setup;

    my $cur_version = script_output('rpm -q --qf "%{VERSION}\n" netavark');
    # only for netavark v1.6+
    # JeOS's kernel-default-base is missing *macvlan* kernel module
    if (!is_jeos && package_version_cmp($cur_version, '1.6.0') >= 0) {
        record_info('TEST4', 'smoke test for netavark dhcp proxy + macvlan');
        $net1->{name} = 'test_macvlan';
        systemctl('enable --now netavark-dhcp-proxy.socket');
        systemctl('status netavark-dhcp-proxy.socket');

        my $dev = script_output(q(ip -br link show | awk '/UP / {print $1}'));
        assert_script_run("podman network create -d macvlan --interface-name $dev $net1->{name}");
        assert_script_run("podman run --network $net1->{name} -td --name $ctr2->{name} $ctr2->{image}");
        assert_script_run("podman exec $ctr2->{name} ip addr show eth0");
        assert_script_run("podman container inspect $ctr2->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
    }
}

sub post_run_hook {
    shift->_cleanup();
}
sub post_fail_hook {
    shift->_cleanup();
}

1;
