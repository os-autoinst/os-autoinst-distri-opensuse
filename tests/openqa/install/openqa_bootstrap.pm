# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install openQA using openqa-bootstrap
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }

    my $script_path;
    if (get_var('BETA')) {
        assert_script_run('wget https://raw.githubusercontent.com/os-autoinst/openQA/master/script/openqa-bootstrap');
        $script_path = 'bash -e openqa-bootstrap';
    }
    else {
        zypper_call('in openQA-bootstrap');
        $script_path = '/usr/share/openqa/script/openqa-bootstrap';
    }

    my $proxy_var = get_var('OPENQA_WEB_PROXY') ? 'setup_web_proxy=' . get_var('OPENQA_WEB_PROXY') . ' ' : '';
    assert_script_run($proxy_var . $script_path, 4000);
}

sub test_flags {
    return {fatal => 1};
}

1;
