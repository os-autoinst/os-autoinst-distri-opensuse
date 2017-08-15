# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run simple checks after installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    # Check that system is using UTC timezone
    assert_script_run 'date +"%Z" | grep -x UTC';

    return if get_var('EXTRA', '') =~ /RCSHELL/;

    # bsc#1019652 - Check that snapper is configured
    assert_script_run "snapper list";

    if (check_var('SYSTEM_ROLE', 'worker')) {
        # poo#16574 - Check salt master configuration
        assert_script_run "grep \"master: 'dashboard-url'\" /etc/salt/minion.d/master.conf";
        # poo#18668 - Check ntp client configuration
        assert_script_run 'grep "^NTP=dashboard-url" /etc/systemd/timesyncd.conf';
    }

    # check if installation script was executed https://trello.com/c/PJqM8x0T
    if (check_var('SYSTEM_ROLE', 'admin')) {
        assert_script_run 'zgrep manifests/activate.sh /var/log/YaST2/y2log-1.gz';
        # bsc#1039863 - Check we are running only sles12 docker images
        assert_script_run '! docker images | sed 1d | grep -v ^sles12';
        assert_script_run 'grep "^server ns.openqa.test" /etc/ntp.conf';
    }
}

1;
# vim: set sw=4 et:
