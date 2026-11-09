# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: yast timezone, list, set and show summary
# - Install yast2-country
# - Check current timezone
# - List available timezones
# - Set timezone to Africa/Cairo
# - Check if timezone was set to Africa/Cairo
# - Return to previous timezone
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use Mojo::Base 'y2_module_basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    zypper_call "in yast2-country";
    my $timezone = script_output 'yast timezone summary 2>&1 | grep "Current Time Zone" | cut -d: -f2';
    # yast may report no timezone, for example when /etc/localtime is a
    # regular file instead of a symlink; ask systemd in that case.
    if (!$timezone) {
        # timedatectl show needs systemd 239, so fall back to status output
        $timezone = script_output('timedatectl show -p Timezone --value 2>/dev/null', proceed_on_failure => 1);
        $timezone ||= script_output(q{timedatectl status | sed -n 's/^ *Time zone: \([^ ]*\).*/\1/p'});
    }
    die 'cannot determine current timezone' if !$timezone || $timezone eq 'n/a';
    record_info 'default timezone', $timezone;
    validate_script_output 'yast timezone list 2>&1', sub { m#Africa/Cairo# };
    assert_script_run('yast timezone set timezone=Africa/Cairo', timeout => 300);
    validate_script_output 'yast timezone summary 2>&1', sub { m#Africa/Cairo# };
    assert_script_run("yast timezone set timezone=$timezone", timeout => 300);
}
sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
