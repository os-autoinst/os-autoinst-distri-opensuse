# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Compute node of warewulf4 cluster
#     Once controller is up and running, run a VM which is provisioned
#     by the controller, and run checks.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase), -signatures;
use testapi;
use lockapi;
use utils;
use mm_tests;
use POSIX 'strftime';

sub run ($self) {
    my $i = 0;

    while ($i < 10) {
        check_screen('pxe-start');
        record_info "pxe", "$i";
        sleep(1);
        send_key "ctrl-B";
        sleep(20);
        type_string("reboot", lf => 1);
        save_screenshot();
        $i++;
    }

    while (1) {
        unless (check_screen('ww4-ready')) {
            record_info('Booting', '');
            next;
        }
        last;
    }
    barrier_wait('WWCTL_DONE');
    record_info 'WWCTL_DONE', strftime("\%H:\%M:\%S", localtime);

    barrier_wait('WWCTL_COMPUTE_DONE');
    record_info 'WWCTL_COMPUTE_DONE', strftime("\%H:\%M:\%S", localtime);
}

sub post_run_hook { }
sub post_fail_hook { }
1;
