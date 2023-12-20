# SUSE"s openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman firewalld-container
# Summary: install and verify firewalld container.
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use warnings;
use strict;
use testapi;
use lockapi;
use mmapi;
use utils qw(set_hostname);
use transactional qw(trup_call check_reboot_changes);
use mm_network 'setup_static_mm_network';
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);


sub remove_builtin_pkg_firewalld {
    record_info("SERVER DEBUG", "removing firewalld and reboot if needed");
    trup_call('pkg remove firewalld');
    check_reboot_changes;
}

sub start_firewalld_container {
    record_info("SERVER DEBUG", "installing firewalld container");
    my $containerpath = 'registry.opensuse.org/suse/alp/workloads/tumbleweed_images/suse/alp/workloads/firewalld';
    assert_script_run 'podman search firewalld';
    assert_script_run "podman container runlabel install $containerpath";
    assert_script_run "podman container runlabel run $containerpath";
}

sub firewall_port {
    my $arg = shift;
    record_info("SERVER DEBUG", "$arg firewall port");
    my $podman_prefix = "podman exec firewalld firewall-cmd ";
    my $options = '--zone=public --permanent ';
    if ($arg eq 'open') { $options .= '--add-port=8080/tcp'; }
    elsif ($arg eq 'close') { $options .= '--remove-port=8080/tcp'; }
    else { die "invalid command for firewalld action"; }
    assert_script_run $podman_prefix . $options;
    assert_script_run $podman_prefix . '--reload';
}

# MM network check: try to ping the gateway, the client and the internet
sub ensure_client_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    assert_script_run('ping -c 1 10.0.2.102');
    assert_script_run('curl conncheck.opensuse.org');
}

sub run {
    my ($self) = @_;
    select_console 'root-console';
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);
    remove_builtin_pkg_firewalld();    # on ALP this needs a reboot
    set_hostname(get_var('HOSTNAME') // 'server');
    barrier_create($_, 2) for ('FIREWALLD_SERVER_READY', 'FIREWALLD_CLIENT_READY', 'FIREWALLD_SERVER_PORT_OPEN',
        'FIREWALLD_SERVER_PORT_CLOSED', 'FIREWALLD_TEST_FINISHED');
    mutex_create 'barrier_setup_done';
    setup_static_mm_network('10.0.2.101/24');
    barrier_wait 'FIREWALLD_CLIENT_READY';
    ensure_client_reachable();
    barrier_wait 'FIREWALLD_SERVER_READY';
    start_firewalld_container();
    # start a basic python http server
    my $python_pid = background_script_run("python3 -m http.server 8080");
    firewall_port('open');
    barrier_wait 'FIREWALLD_SERVER_PORT_OPEN';
    # tells the client server is ready so can probe the port
    # client is checking the server port
    firewall_port('close');
    barrier_wait 'FIREWALLD_SERVER_PORT_CLOSED';
    # here client is checking the port
    barrier_wait 'FIREWALLD_TEST_FINISHED';
    assert_script_run "kill $python_pid";
    assert_script_run "podman stop firewalld";
    wait_for_children();
}

1;

