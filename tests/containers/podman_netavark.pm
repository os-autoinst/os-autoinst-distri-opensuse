# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman, netavark, aardvark
# Summary: Test podman netavark network backend
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(package_version_cmp is_transactional is_jeos is_leap is_sle_micro is_leap_micro is_sle is_microos is_public_cloud is_vmware);
use containers::common qw(install_packages);
use Utils::Systemd qw(systemctl);
use Utils::Architectures qw(is_s390x);
use main_common qw(is_updates_tests);
use publiccloud::utils qw(is_gce);

my ($ipv6_gateway, $ipv6_interface, $dev);

sub store_ipv6_route {
    # TEST3 may remove the default ipv6 route, save it to restore later
    # bsc#1222239 bsc#1232450
    my $default_ipv6_route = script_output("ip -6 route show default");
    if ($default_ipv6_route =~ /default via (\S+) dev (\S+)/) {
        $ipv6_gateway = $1;
        $ipv6_interface = $2;
    }
}

sub load_ipv6_route {
    # restore the default ipv6 route
    my $default_ipv6_route = script_output("ip -6 route show default");
    if (!$default_ipv6_route && $ipv6_gateway && $ipv6_interface) {
        assert_script_run("ip -6 route add default via $ipv6_gateway dev $ipv6_interface");
    }
}

sub is_cni_in_tw {
    return (script_output("podman info -f '{{.Host.NetworkBackend}}'") =~ "cni") && is_microos && get_var('TDUP');
}

# podman >=4.8.0 defaults to netavark
# but images build with older pre-installed podman come with cni
# fresh install of sle-micro comes with netavark
sub is_cni_default {
    return (is_sle_micro('<6.0') && !check_var('FLAVOR', 'DVD-Updates'));
}

sub remove_subtest_setup {
    assert_script_run("podman container rm -af");
    assert_script_run("podman network prune -f");
    validate_script_output("podman network ls --noheading", sub { /^\w+\s+podman\s+bridge$/ });
    validate_script_output("podman ps -a --noheading", sub { /^\s*$/ });

    if ($dev) {
        script_run 'ip a s';
        script_run("ip link set $dev down");
        script_run("ip link del dev $dev");
    }
}

sub is_container_running {
    my @containers = @_;
    my $out = script_output("podman container ps --format '{{.Names}}' --noheading");

    foreach my $cont (@containers) {
        if ($out =~ m/$cont/) {
            next;
        } elsif (is_sle_micro) {
            record_soft_failure('bsc#1211774 - podman fails to start container with SELinux');
            return 0;
        } else {
            die "Container $cont is not running!";
        }
    }
    return 1;
}

# clean up routine only for systems that run CNI as default network backend
sub _cleanup {
    my $podman = shift->containers_factory('podman');
    select_console 'log-console';
    remove_subtest_setup;

    if (is_cni_default) {
        script_run('rm -f /etc/containers/containers.conf');
        $podman->cleanup_system_host();
        validate_script_output('podman info --format {{.Host.NetworkBackend}}', sub { /cni/ });
    } else {
        $podman->cleanup_system_host();
        validate_script_output('podman info --format {{.Host.NetworkBackend}}', sub { /netavark/ });
    }

    validate_script_output('podman network ls', sub { /podman\s+bridge/ });
}

sub switch_to_netavark {
    install_packages('netavark', 'aardvark-dns');
    # change network backend to *netavark*
    assert_script_run(q(echo -e '[Network]\nnetwork_backend="netavark"' >> /etc/containers/containers.conf));
    # reset the storage back to the initial state
    assert_script_run('podman system reset --force');
    validate_script_output('podman info --format {{.Host.NetworkBackend}}', sub { /netavark/ });
}

sub run {
    my ($self, $args) = @_;

    my $podman = $self->containers_factory('podman');

    if (is_cni_default || is_cni_in_tw) {
        switch_to_netavark;
    } else {
        record_info('default', 'netavark should be the default network backend');
        install_packages('aardvark-dns');
    }

    $podman->cleanup_system_host();

    assert_script_run('curl ' . data_url('containers/nginx.conf') . ' -o nginx.conf');

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
        image => 'registry.opensuse.org/opensuse/nginx',
        name => 'webserver_ctr',
        ip => '10.90.0.8',
        mac => '76:22:33:44:55:66',
        ip6 => 'fd00::1:8:9',
        name6 => 'webserver_ctr_ipv6'
    };

    assert_script_run("podman network create --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman run --network $net1->{name}:ip=$ctr1->{ip},mac=$ctr1->{mac} -d --name $ctr1->{name} -v \$PWD/nginx.conf:/etc/nginx/nginx.conf:ro,Z $ctr1->{image}");
    assert_script_run("podman container inspect $ctr1->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
    if (is_container_running($ctr1->{name})) {
        validate_script_output("curl --head --silent $ctr1->{ip}:80", sub { /HTTP.* 200 OK/ });
        assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
    }
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
        image => 'registry.opensuse.org/opensuse/busybox',
        name => 'busybox_ctr',
        ip => '10.64.0.8',
        mac => '92:aa:33:44:55:66',
        ip_sec => '10.90.0.64',
        mac_sec => '92:bb:cc:44:55:66'
    };

    assert_script_run("podman network create --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman network create --gateway $net2->{gateway} --subnet $net2->{subnet} $net2->{name}");
    assert_script_run("podman run --network $net1->{name}:ip=$ctr1->{ip},mac=$ctr1->{mac} -dt --name $ctr1->{name} -v \$PWD/nginx.conf:/etc/nginx/nginx.conf:ro,Z $ctr1->{image}");
    assert_script_run("podman run --network $net2->{name}:ip=$ctr2->{ip},mac=$ctr2->{mac} --network $net1->{name}:ip=$ctr2->{ip_sec},mac=$ctr2->{mac_sec} -dt --name $ctr2->{name} $ctr2->{image}");

    # second container should have 2 interfaces
    if (is_container_running($ctr1->{name}, $ctr2->{name})) {
        my $net1_reg = qr@ether\s+$ctr2->{mac}.*\s+inet\s+$ctr2->{ip}\/16@;
        my $net2_reg = qr@ether\s+$ctr2->{mac_sec}.*\s+inet\s+$ctr2->{ip_sec}\/16@;
        validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'ip addr show eth0'", sub { /$net1_reg|$net2_reg/m });
        validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'ip addr show eth1'", sub { /$net1_reg|$net2_reg/m });
        validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'nslookup $ctr1->{name}'", sub { /Name:\s+$ctr1->{name}\s+Address.*$ctr1->{ip}/m });
        validate_script_output("podman exec -t $ctr2->{name} /bin/sh -c 'wget -S $ctr1->{ip}:80'", sub { /HTTP.* 200 OK/ });
        # busybox container should be able to resolve webserver container
        assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
        assert_script_run("grep $ctr2->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
        assert_script_run("grep $ctr2->{name} /run/containers/networks/aardvark-dns/$net2->{name}");
    }

    remove_subtest_setup;

    ## TEST3
    record_info('TEST3', 'create a dual stack network');
    $net1->{name} = 'test_dual_stack';
    assert_script_run("podman network create --ipv6 --gateway $net1->{gateway_v6} --subnet $net1->{subnet_v6} --gateway $net1->{gateway} --subnet $net1->{subnet} $net1->{name}");
    assert_script_run("podman run --network $net1->{name} -d --name $ctr1->{name6} --ip6 $ctr1->{ip6} -p 8080:80 -v \$PWD/nginx.conf:/etc/nginx/nginx.conf:ro,Z $ctr1->{image}");
    assert_script_run("podman run --network $net1->{name} -d --name $ctr1->{name} --ip $ctr1->{ip} -p 8888:80 -v \$PWD/nginx.conf:/etc/nginx/nginx.conf:ro,Z $ctr1->{image}");

    if (is_container_running($ctr1->{name})) {
        foreach my $req ((
                'http://localhost:8080',
                'http://localhost:8888',
                "-4 http://$ctr1->{ip}:80",
                "-6 http://[$ctr1->{ip6}]:80"
        )) {
            validate_script_output("curl --retry 5 --head --silent $req", sub { /HTTP.* 200 OK/ }, timeout => 120);
        }
        assert_script_run("podman container inspect $ctr1->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
        assert_script_run("podman container inspect $ctr1->{name6} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
        assert_script_run("grep $ctr1->{name} /run/containers/networks/aardvark-dns/$net1->{name}");
        assert_script_run("grep $ctr1->{name6} /run/containers/networks/aardvark-dns/$net1->{name}");
    }

    remove_subtest_setup;
    load_ipv6_route;

    my $cur_version = script_output('rpm -q --qf "%{VERSION}\n" netavark');
    # only for netavark v1.6+
    # JeOS's kernel-default-base is missing *macvlan* kernel module
    if (!is_jeos && package_version_cmp($cur_version, '1.6.0') >= 0) {
        record_info('TEST4', 'smoke test for netavark dhcp proxy + macvlan');
        $net1->{name} = 'test_macvlan';
        systemctl('enable --now netavark-dhcp-proxy.socket');
        systemctl('status netavark-dhcp-proxy.socket');

        my $d = script_output(q(ip -br link show | awk '/UP / {print $1}'| head -n 1));
        my $id = 666;
        $dev = "$d" . "\.$id";

        assert_script_run("ip link add link $d name $dev type vlan id $id");
        assert_script_run("ip link set $dev up");

        my $extra = '--subnet=192.168.64.0/24  --ip-range=192.168.64.128/25 --gateway=192.168.64.254';
        assert_script_run("podman network create -d macvlan --interface-name $dev $extra $net1->{name}");
        assert_script_run("podman run --network $net1->{name} -td --name $ctr2->{name} --ip 192.168.64.128 $ctr2->{image}");
        if (is_container_running($ctr2->{name})) {
            assert_script_run("podman exec $ctr2->{name} ip addr show eth0");
            assert_script_run("podman container inspect $ctr2->{name} --format {{.NetworkSettings.Networks.$net1->{name}.IPAddress}}");
        }

        # NOTE: Remove condition when https://bugzilla.suse.com/show_bug.cgi?id=1239176 is fixed
        unless (is_s390x) {
            assert_script_run("podman run --network $net1->{name} -td --name $ctr1->{name} --ip 192.168.64.129 $ctr2->{image}");
            assert_script_run("podman exec $ctr2->{name} ip addr show eth0");
            assert_script_run("podman exec $ctr1->{name} ping -c4 192.168.64.128");
        }
    }

    remove_subtest_setup;
}

sub pre_run_hook() {
    select_serial_terminal;
    store_ipv6_route;
}

sub post_run_hook {
    shift->_cleanup();
}

sub post_fail_hook {
    load_ipv6_route;
    shift->_cleanup();
}

1;
