# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    kdump_utils::configure_service('function');
    kdump_utils::check_function('function');
}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
