# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Very simple, needle free, bind server test
# Maintainer: sysrich <RBrownCCB@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils qw(is_bridged_networking systemctl);

sub run {
    select_console 'root-console';

    # Install bind
    assert_script_run "zypper -n -q in bind";

    # check that it can be enabled and disabled;
    systemctl 'enable named';
    systemctl 'disable named';

    # let's try to run it
    systemctl 'start named';
    systemctl 'show -p ActiveState named.service|grep ActiveState=active';
    systemctl 'show -p SubState named.service|grep SubState=running';

    # verify dns server responds to anything
    my $e = script_run "host localhost localhost";
    if ($e) {
        record_soft_failure 'bsc#1064438: "bind" cannot resolve localhost' if check_var('ARCH', 's390x');
        record_info 'Skip the entire test on bridged networks (e.g. Xen, Hyper-V)' if (is_bridged_networking);
        return if (is_bridged_networking || check_var('ARCH', 's390x'));
        die "Command 'host localhost localhost' failed, cannot resolv localhost";
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # see https://bugzilla.suse.com/show_bug.cgi?id=1064438
    select_console 'log-console';
    upload_logs '/etc/named.conf';
    # to see if zone file is present
    $self->save_and_upload_log('ls /var/lib/named', 'named_files.log');
    upload_logs '/var/lib/named/localhost.zone';
    script_run '/usr/sbin/named-checkzone localhost /var/lib/named/localhost.zone';
    $self->SUPER::post_fail_hook;
}

1;
