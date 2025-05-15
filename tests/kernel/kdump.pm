# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure and run kdump test using command line interface
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console('root-console');

    if (is_sle(">=16")) {
    #SLE 16 doesn't have yast or other tooling for kdump configuration and we should configure kdump manually.
    activate_kdump_without_yast();
    } else {
        configure_service(test_type => 'function', yast_interface => 'cli');
    }
        check_function(test_type => 'function');

}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
