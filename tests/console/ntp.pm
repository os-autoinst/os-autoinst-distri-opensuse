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
use services::ntpd;

sub run {
    select_console 'root-console';
    services::ntpd::install_service();
    services::ntpd::enable_service();
    services::ntpd::start_service();

    my $server_count = script_output 'ntpq -p | tail -n +3 | wc -l';
    assert_script_run 'echo "server 3.europe.pool.ntp.org" >> /etc/ntp.conf';
    assert_script_run 'echo "server 2.europe.pool.ntp.org" >> /etc/ntp.conf';
    systemctl 'restart ntpd.service';
    assert_script_run 'ntpq -p';
    $server_count + 2 <= script_output 'ntpq -p | tail -n +3 | wc -l' or die "Configuration not loaded";

    services::ntpd::config_service();
    services::ntpd::check_service();
    services::ntpd::check_function();
}
1;
