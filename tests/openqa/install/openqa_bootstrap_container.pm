# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install openQA using openqa-bootstrap-container
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use base "consoletest";
use testapi;
use utils;


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

1;
