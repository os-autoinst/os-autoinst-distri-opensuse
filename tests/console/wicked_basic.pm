# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sanity checks of wicked
# Test scenarios:
# Test 1: Bring down the wicked client service
# Test 2: Bring up the wicked client service
# Test 3: Bring down the wicked server service
# Test 4: Bring up the wicked server service
# Test 5: List the network interfaces with wicked
# Test 6: Bring an interface down with wicked
# Test 7: Bring an interface up with wicked
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Sebastian Chlad <schlad@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils qw(systemctl snapper_revert_system arrays_differ);

sub assert_wicked_state {
    my (%args) = @_;
    systemctl('is-active wicked.service',  expect_false => $args{wicked_client_down});
    systemctl('is-active wickedd.service', expect_false => $args{wicked_daemon_down});
    my $status = $args{interfaces_down} ? 'down' : 'up';
    assert_script_run("for dev in /sys/class/net/!(lo); do grep \"$status\" \$dev/operstate || (echo \"device \$dev is not $status\" && exit 1) ; done");
}

sub save_and_upload_log {
    my $log_name = join('', map { ("a" .. "z")[rand 26] } 1 .. 8);
    assert_script_run("journalctl -o short-precise > /tmp/$log_name.log");
    upload_logs("/tmp/$log_name.log");
}

sub run {
    my ($self) = @_;
    my $iface = script_output('echo $(ls /sys/class/net/ | grep -v lo | head -1)');
    type_string("#***Test 1: Bring down the wicked client service***\n");
    systemctl('stop wicked.service');
    assert_wicked_state(wicked_client_down => 1, interfaces_down => 1);
    type_string("#***Test 2: Bring up the wicked client service***\n");
    systemctl('start wicked.service');
    assert_wicked_state();
    type_string("#***Test 3: Bring down the wicked server service***\n");
    systemctl('stop wickedd.service');
    assert_wicked_state(wicked_daemon_down => 1);
    assert_script_run("! ifdown $iface");
    type_string("#***Test 4: Bring up the wicked server service***\n");
    systemctl('start wickedd.service');
    assert_wicked_state();
    assert_script_run("ifup $iface");
    type_string("#***Test 5: List the network interfaces with wicked***\n");
    my @wicked_all_ifaces = split("\n", script_output("wicked show --brief all"));
    foreach (@wicked_all_ifaces) {
        $_ = substr($_, 0, index($_, ' '));
    }
    my @ls_all_ifaces = split(' ', script_output("ls /sys/class/net/"));
    die "Wrong list of interfaces from wicked" if arrays_differ(\@wicked_all_ifaces, \@ls_all_ifaces);
    type_string("#***Test 6: Bring an interface down with wicked***\n");
    assert_script_run("ifdown $iface");
    assert_script_run("ping -q -c1 -W1 -I $iface 10.0.2.2 2>&1 | grep -q ' Network is unreachable'");
    assert_script_run("! \$(ip address show dev $iface | grep -q 'inet')");
    type_string("#***Test 7: Bring an interface up with wicked***\n");
    assert_script_run("ifup $iface");
    assert_script_run("ping -q -c1 -W1 -I $iface 10.0.2.2");
    assert_script_run("ip address show dev $iface | grep -q 'inet'");
    save_and_upload_log();
    $self->snapper_revert_system();
}

1;
