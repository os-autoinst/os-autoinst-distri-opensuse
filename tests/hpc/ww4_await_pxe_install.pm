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
use mmapi;
use utils;
use mm_tests;
use POSIX 'strftime';

sub run ($self) {
    if (check_screen('pxe-start')) {
        send_key "ctrl-B";
        save_screenshot();
        record_info "pxe", "wait for controller";
    }
    mutex_wait "ww4_ready";
    barrier_wait('WWCTL_READY');
    record_info 'WWCTL_READY', strftime("\%H:\%M:\%S", localtime);
    type_string("reboot", lf => 1);
    save_screenshot();
    check_screen('ww4-ready', 180);
    save_screenshot();
    barrier_wait('WWCTL_DONE');
    record_info 'WWCTL_DONE', strftime("\%H:\%M:\%S", localtime);

    barrier_wait('WWCTL_COMPUTE_DONE');
    record_info 'WWCTL_COMPUTE_DONE', strftime("\%H:\%M:\%S", localtime);
}

sub post_run_hook { }
sub post_fail_hook { }
1;
