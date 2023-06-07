# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure that the openQA job is actually running
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils 'zypper_call';

sub run {
    zypper_call('in ack');
    assert_script_run q{ret=false; for i in {1..5} ; do openqa-cli api jobs state=running state=done | ack --passthru --color 'running|done' && ret=true && break ; sleep 30 ; done ; [ "$ret" = "true" ]}, 300;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    script_run 'lsmod | grep kvm';
    save_screenshot;
    $self->get_log('grep --color -z -E "(vmx|svm)" /proc/cpuinfo' => 'cpuinfo');
    assert_script_run 'grep --color -z -E "(vmx|svm)" /proc/cpuinfo', fail_message => 'Machine does not support nested virtualization, please enable in worker host';
}

sub test_flags {
    # continue with other tests as we could use their information for
    # debugging in case of failures.
    return {important => 1};
}

1;
