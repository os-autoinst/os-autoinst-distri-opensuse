# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run pulpito the teuthology result webpage and tear down openstack when test passed
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    x11_start_program('firefox http://pulpito.suse.de:8081', valid => 0);
    assert_screen 'pulpito-dashboard';
    # tab over web page to get to pulpito-test-list
    for (1 .. 22) { send_key 'tab' }
    send_key 'ret';
    assert_screen 'pulpito-test-list';
    # tab over web page to get to pulpito-test-description
    for (1 .. 12) { send_key 'tab' }
    send_key 'ret';
    assert_screen 'pulpito-test-description';
    send_key 'alt-f4';
    assert_screen 'firefox-save-and-quit';
    send_key 'ret';
}

sub post_run_hook {
    select_console 'root-console';
    # teardown the machine when tests passed, use bsh variables exported in previous test
    assert_script_run "teuthology-openstack -v --key-filename ~/.ssh/id_rsa --key-name \\
QAM-openqa --name \$instance_name --teardown", 2000;
}

1;
