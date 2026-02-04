# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Preparing static IPs and hostnames on multi-nodes.
#
# Based on code written by Pavel Dostal <pdostal@suse.cz>
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use mm_network qw(configure_hostname setup_static_mm_network);
use serial_terminal qw(select_serial_terminal);
use utils qw(systemctl);

sub run {
    my $hostname = get_required_var('HOSTNAME');
    my $is_server = ($hostname =~ /master/);
    my $local_index;

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD') unless ($is_server);

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.100 master" >> /etc/hosts');
    foreach (split(/,/, get_required_var('NODES_LIST'))) {
        $_ =~ m/node(.*)/;
        my $index = $1;
        $local_index = $index if ($_ eq $hostname);    # Keep the local index
        assert_script_run("echo '10.0.2.1$index node$index' >> /etc/hosts");
    }

    # Setup static network
    setup_static_mm_network($is_server ? '10.0.2.100/24' : "10.0.2.1$local_index/24");

    # Set the hostname
    configure_hostname($hostname);

    # Restart sshd on the nodes
    systemctl('restart sshd') unless $is_server;

    # Wait for all nodes to be synced
    barrier_wait('NETWORK_SETUP_DONE');

    # Ping test: ensure that all nodes are able to join the master
    assert_script_run('ping -M do -s 0 -c 5 10.0.2.100') unless $is_server;

    # Record network info
    record_info('Network configuration',
        script_output('hostnamectl hostname; echo; ip a; echo; ip route; echo; cat /etc/hosts'));

    # Wait for all nodes
    barrier_wait('NETWORK_CHECK_DONE');
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
