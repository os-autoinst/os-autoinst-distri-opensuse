# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Base class for the ssh_interactive initiation phase
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package publiccloud::ssh_interactive_init;
use base "consoletest";
use publiccloud::utils;
use strict;
use warnings;
use testapi;

sub post_fail_hook {
    select_host_console(force => 1);
    assert_script_run('cd /root/terraform');
    script_retry('terraform destroy -no-color -auto-approve', retry => 3, delay => 60, timeout => get_var('TERRAFORM_TIMEOUT', 240), die => 0);
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

1;
