# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basics ntp test - add ntp servers, obtain time
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call "in ntp";

    my $server_count = script_output 'ntpq -p | tail -n +3 | wc -l';
    assert_script_run 'echo "server 3.europe.pool.ntp.org" >> /etc/ntp.conf';
    assert_script_run 'echo "server 2.europe.pool.ntp.org" >> /etc/ntp.conf';
    systemctl 'restart ntpd.service';
    assert_script_run 'ntpq -p';
    $server_count + 2 <= script_output 'ntpq -p | tail -n +3 | wc -l' or die "Configuration not loaded";

    assert_script_run 'echo "server ntp1.suse.de iburst" >> /etc/ntp.conf';
    assert_script_run 'echo "server ntp2.suse.de iburst" >> /etc/ntp.conf';
    assert_script_run 'date -s "Tue Jul 03 10:42:42 2018"';
    validate_script_output 'date', sub { m/2018/ };
    systemctl 'restart ntpd.service';
    sleep 180;
    validate_script_output 'date', sub { not m/2018/ };
}
1;
