# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: kernel-default-debuginfo yast2-kdump kdump crash mokutil
# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;

sub run {
    select_console('root-console');
    if (kdump_utils::configure_service(test_type => 'function') == 16) {
        record_info 'Not supported', 'Kdump is not supported in a PV DomU';
        return;
    }
    kdump_utils::check_function(test_type => 'function');
}

sub post_fail_hook {
    my ($self) = @_;

    send_key 'ctrl-z';
    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
