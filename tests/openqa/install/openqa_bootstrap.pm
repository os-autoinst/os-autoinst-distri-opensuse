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
use version_utils qw(has_selinux is_leap);

sub run {
    select_console 'root-console';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }

    # allow connect to httpd_port
    if (has_selinux) {
        script_run('setsebool -P httpd_can_network_connect 1');
    }
    if (is_leap) {
        # https://progress.opensuse.org/issues/180905
        assert_script_run('mkdir -p /usr/share/openqa/script/');
        assert_script_run('curl -L https://raw.githubusercontent.com/os-autoinst/openQA/refs/heads/master/script/openqa-bootstrap > /usr/share/openqa/script/openqa-bootstrap');
        assert_script_run('test -e /usr/share/openqa/script/openqa-bootstrap && chmod +x /usr/share/openqa/script/openqa-bootstrap');
    }
    else { zypper_call('in openQA-bootstrap'); }

    my $proxy_var = get_var('OPENQA_WEB_PROXY') ? 'setup_web_proxy=' . get_var('OPENQA_WEB_PROXY') . ' ' : '';
    assert_script_run($proxy_var . "/usr/share/openqa/script/openqa-bootstrap", 4000);
}

sub test_flags {
    return {fatal => 1};
}

1;
