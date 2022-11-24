# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install openQA using openqa-bootstrap-container
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use Utils::Logging 'save_and_upload_log';

sub run {
    select_console 'root-console';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'Creating dummy /dev/kvm');
        assert_script_run('mknod /dev/kvm c 10 232');
    }

    zypper_call('in openQA-bootstrap');
    assert_script_run('DEFAULT_REPO=' . get_var('MIRROR_HTTP') . ' /usr/share/openqa/script/openqa-bootstrap-container', 1600);

    assert_screen('openqa-container-created');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    save_and_upload_log("journalctl -M openqa1 -b -o short-precise --no-pager", "journal_container.log", {screenshot => 1});
}

1;
