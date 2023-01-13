# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bind bind-utils
# Summary: Very simple, needle free, bind server test
# - check that named can be enabled and disabled
# - start named service
# - verify that the dns server responds
# Maintainer: sysrich <RBrownCCB@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use Utils::Architectures;
use utils qw(is_bridged_networking systemctl zypper_call);
use Utils::Logging 'save_and_upload_log';

sub run {
    select_console 'root-console';

    # Install bind
    zypper_call "-q in bind";

    # check that it can be enabled and disabled;
    systemctl 'enable named';
    systemctl 'disable named';

    # let's try to run it
    systemctl 'start named';
    systemctl 'show -p ActiveState named.service|grep ActiveState=active';
    systemctl 'show -p SubState named.service|grep SubState=running';

    # verify dns server responds to anything
    if (script_run 'host localhost. localhost') {
        record_soft_failure 'bsc#1064438: "bind" cannot resolve localhost' if is_s390x;
        record_info 'Skip the entire test on bridged networks (e.g. Xen, Hyper-V)' if (is_bridged_networking);
        return if (is_bridged_networking || is_s390x);
        die "Command 'host localhost localhost' failed, cannot resolv localhost";
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # see https://bugzilla.suse.com/show_bug.cgi?id=1064438
    select_console 'log-console';
    upload_logs '/etc/named.conf';
    # to see if zone file is present
    save_and_upload_log('ls /var/lib/named', 'named_files.log');
    upload_logs '/var/lib/named/localhost.zone';
    script_run '/usr/sbin/named-checkzone localhost /var/lib/named/localhost.zone';
    $self->SUPER::post_fail_hook;
}

1;
