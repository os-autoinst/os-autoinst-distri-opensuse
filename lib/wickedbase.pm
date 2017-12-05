# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base module for all wicked scenarios
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

package wickedbase;

use base 'consoletest';
use utils 'systemctl';
use testapi qw(assert_script_run upload_logs type_string);

sub assert_wicked_state {
    my ($self, %args) = @_;
    systemctl('is-active wicked.service',  expect_false => $args{wicked_client_down});
    systemctl('is-active wickedd.service', expect_false => $args{wicked_daemon_down});
    my $status = $args{interfaces_down} ? 'down' : 'up';
    assert_script_run("for dev in /sys/class/net/!(lo); do grep \"$status\" \$dev/operstate || (echo \"device \$dev is not $status\" && exit 1) ; done");
}


sub save_and_upload_wicked_log {
    my ($self, $prefix) = @_;
    my $log_name = join('', map { ("a" .. "z")[rand 26] } 1 .. 8);
    assert_script_run("journalctl -o short-precise > /tmp/$prefix$log_name.log");
    upload_logs("/tmp/$prefix$log_name.log");
}

sub write_journal {
    my ($self, $message) = @_;
    my $module_name = $self->{name};
    type_string "logger -t $module_name \"$message\" \n";
}

1;
