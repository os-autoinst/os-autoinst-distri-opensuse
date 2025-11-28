# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare 2-host environment variables for LTP net.nfs on baremetal
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi 'barrier_wait';
use utils;
use Utils::Backends 'is_ipmi';
use Kernel::net_tests qw(get_ipv4_addresses get_ipv6_addresses);

sub _find_local_mapping {
    my ($ip1, $ip2, $ips_by_if) = @_;
    my ($local_ip, $peer_ip, $local_if);

    for my $ifname (sort keys %$ips_by_if) {
        for my $ip (@{$ips_by_if->{$ifname}}) {
            if ($ip eq $ip1) {
                ($local_ip, $peer_ip, $local_if) = ($ip1, $ip2, $ifname);
                last;
            }
            if ($ip eq $ip2) {
                ($local_ip, $peer_ip, $local_if) = ($ip2, $ip1, $ifname);
                last;
            }
        }
        last if $local_ip;
    }

    return ($local_ip, $peer_ip, $local_if);
}

sub _local_prefix_len {
    my ($ifname, $local_ip) = @_;
    my $cidr = script_output("ip -4 -o addr show dev $ifname scope global | awk '{print \\$4}' | grep '^$local_ip/' | head -n1", proceed_on_failure => 1);
    my ($prefix_len) = $cidr =~ m{/(\d+)$};
    return $prefix_len // 24;
}

sub _append_ltp_env {
    my (%args) = @_;
    my @extra = (
        "RHOST=$args{rhost}",
        "IPV4_LHOST=$args{ipv4_lhost}",
        "IPV4_RHOST=$args{ipv4_rhost}",
        "LHOST_IFACES=$args{lhost_ifaces}",
        "RHOST_IFACES=$args{rhost_ifaces}",
    );
    push @extra, "IPV6_LHOST=$args{ipv6_lhost}" if $args{ipv6_lhost};
    push @extra, "IPV6_RHOST=$args{ipv6_rhost}" if $args{ipv6_rhost};
    my $base = get_var('LTP_ENV', '');
    my $ltp_env = join(',', grep { $_ ne '' } ($base, @extra));
    set_var('LTP_ENV', $ltp_env);
    record_info('LTP_ENV', $ltp_env);
}

sub run {
    my $role = get_required_var('ROLE');
    select_serial_terminal;

    systemctl('enable sshd --now');
    systemctl('is-active sshd');
    assert_script_run("mkdir -p /etc/ssh/sshd_config.d");
    assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/99-ltp-root.conf");
    assert_script_run("echo 'PubkeyAuthentication yes' > /etc/ssh/sshd_config.d/99-ltp-pubkey.conf");
    systemctl('restart sshd');
    systemctl('is-active sshd');

    my $ips_by_if = get_ipv4_addresses();
    my @all_local_ips = sort map { @$_ } values %$ips_by_if;
    record_info('Local IPv4', join(' ', @all_local_ips));

    my $ip1 = get_var('IBTEST_IP1');
    my $ip2 = get_var('IBTEST_IP2');
    die 'IBTEST_IP1 and IBTEST_IP2 are required for before_ltp_nfs_test on IPMI' if (is_ipmi && (!$ip1 || !$ip2));

    my ($local_ip, $peer_ip, $local_if) = _find_local_mapping($ip1, $ip2, $ips_by_if);
    unless ($local_ip && $peer_ip && $local_if) {
        record_info('IP mapping', "local_ips=@all_local_ips ib1=$ip1 ib2=$ip2", result => 'fail');
        die 'Unable to map local/peer IP from IBTEST_IP1 and IBTEST_IP2';
    }

    my $prefix_len = _local_prefix_len($local_if, $local_ip);
    record_info('LTP 2host map', "role=$role local_ip=$local_ip peer_ip=$peer_ip if=$local_if/$prefix_len");

    # LTP net helpers are executed locally and over non-interactive SSH via tst_rhost_run().
    # Ensure helper binaries are resolvable from a stable PATH on both nodes.
    assert_script_run('install -d /usr/local/bin');
    assert_script_run('ln -sf /opt/ltp/testcases/bin/tst_net_iface_prefix /usr/local/bin/tst_net_iface_prefix');
    assert_script_run('ln -sf /opt/ltp/testcases/bin/tst_net_ip_prefix /usr/local/bin/tst_net_ip_prefix');

    # Make SSH non-interactive for two-host LTP calls and try to pre-seed known_hosts.
    assert_script_run('mkdir -p /root/.ssh && chmod 700 /root/.ssh');
    script_run('[ -f /root/.ssh/id_rsa ] || ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');
    assert_script_run(qq(echo "Host $peer_ip" > /root/.ssh/config));
    assert_script_run(qq(echo "  StrictHostKeyChecking no" >> /root/.ssh/config));
    assert_script_run(qq(echo "  UserKnownHostsFile /root/.ssh/known_hosts" >> /root/.ssh/config));
    assert_script_run(qq(echo "  GlobalKnownHostsFile /dev/null" >> /root/.ssh/config));
    assert_script_run('chmod 600 /root/.ssh/config');
    script_run("ssh-keygen -R $peer_ip");
    script_retry("ssh-keyscan -T 10 -H $peer_ip >> /root/.ssh/known_hosts", retry => 12, delay => 5, timeout => 30);
    script_run('chmod 600 /root/.ssh/known_hosts');

    barrier_wait('NFS_LTP_2HOST_PREP_DONE');

    return unless check_var('ROLE', 'nfs_client');

    my $rhost_ifaces = get_var('RHOST_IFACES', $local_if);
    my $ipv6_lhost;
    my $ipv6_rhost;
    my $ip6_1 = get_var('IBTEST_IPV6_1');
    my $ip6_2 = get_var('IBTEST_IPV6_2');
    if ($ip6_1 && $ip6_2) {
        my $ips_by_if_v6 = get_ipv6_addresses();
        my @local_v6 = map { @$_ } values %$ips_by_if_v6;
        if (grep { $_ eq $ip6_1 } @local_v6) {
            $ipv6_lhost = "$ip6_1/64";
            $ipv6_rhost = "$ip6_2/64";
        } elsif (grep { $_ eq $ip6_2 } @local_v6) {
            $ipv6_lhost = "$ip6_2/64";
            $ipv6_rhost = "$ip6_1/64";
        } else {
            record_info('IPv6 mapping', "IBTEST_IPV6_1/2 configured but not found on local host", result => 'softfail');
        }
    } else {
        record_info('IPv6 mapping', 'IBTEST_IPV6_1/2 not set, skipping IPV6_* export');
    }

    _append_ltp_env(
        rhost => $peer_ip,
        ipv4_lhost => "$local_ip/$prefix_len",
        ipv4_rhost => "$peer_ip/$prefix_len",
        lhost_ifaces => $local_if,
        rhost_ifaces => $rhost_ifaces,
        ipv6_lhost => $ipv6_lhost,
        ipv6_rhost => $ipv6_rhost,
    );

    # Minimal packages/services required by net.nfs checks on lhost side.
    zypper_call('in --no-recommends rpcbind nfs-kernel-server');
    systemctl('enable rpcbind --now');
    systemctl('is-active rpcbind');
    systemctl('enable nfs-server --now');
    systemctl('is-active nfs-server');
    record_info('rpcinfo localhost', script_output('rpcinfo -p localhost', proceed_on_failure => 1));

    my $ssh_port_ready = script_retry("bash -c 'echo >/dev/tcp/$peer_ip/22'", retry => 12, delay => 5, timeout => 30);
    die "SSH on peer not reachable: $peer_ip:22" if $ssh_port_ready != 0;
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$peer_ip");
    assert_script_run("ssh -o BatchMode=yes root\@$peer_ip true");
}

sub test_flags {
    return {fatal => 1};
}

1;
