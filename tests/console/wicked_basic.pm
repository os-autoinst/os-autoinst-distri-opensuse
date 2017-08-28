# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sanity checks of wicked
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils qw(systemctl snapper_revert_system);

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
    type_string("#STOP WICKED CLIENT\n");
    systemctl('stop wicked.service');
    assert_wicked_state(wicked_client_down => 1, interfaces_down => 1);
    type_string("#START WICKED CLIENT\n");
    systemctl('start wicked.service');
    assert_wicked_state();
    type_string("#STOP WICKED DAEMON\n");
    systemctl('stop wickedd.service');
    assert_wicked_state(wicked_daemon_down => 1);
    assert_script_run('! ifdown $(ls -d /sys/class/net/!(lo) | head -1 | sed "s/.*\///")');
    save_and_upload_log();
    $self->snapper_revert_system();
}

1;
