# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the network speed of the public cloud instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive qw(select_host_console);

sub network_speed_test {
    my ($instance) = @_;
    my ($cmd, $ret);

    # Curl stats output format
    my $write_out
      = 'time_namelookup:\t%{time_namelookup} s\ntime_connect:\t\t%{time_connect} s\ntime_appconnect:\t%{time_appconnect} s\ntime_pretransfer:\t%{time_pretransfer} s\ntime_redirect:\t\t%{time_redirect} s\ntime_starttransfer:\t%{time_starttransfer} s\ntime_total:\t\t%{time_total} s\n';
    # PC RMT server domain name
    my $rmt_host = "smt-" . lc(get_required_var('PUBLIC_CLOUD_PROVIDER')) . ".susecloud.net";

    $cmd = "grep \"$rmt_host\" /etc/hosts";
    $ret = $instance->ssh_script_run(cmd => $cmd, apply_graceful_timeout => 1);
    record_info("RMT_HOST", printf('$ %s\n%s', $cmd, $ret));

    $cmd = "ping -c3 1.1.1.1";
    $ret = $instance->ssh_script_run(cmd => $cmd, apply_graceful_timeout => 1);
    record_info("PING", printf('$ %s\n%s', $cmd, $ret));

    $cmd = "curl -w '$write_out' -o /dev/null -v https://$rmt_host/";
    $ret = $instance->ssh_script_run(cmd => $cmd, apply_graceful_timeout => 1);
    record_info("CURL", printf('$ %s\n%s', $cmd, $ret));
}

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    network_speed_test($args->{my_instance});
}

sub test_flags {
    return {fatal => 0};
}

1;
