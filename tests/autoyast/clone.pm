# Copyright 2015-2019 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Clone the existing installation for use in validation
# - remove existing autoinst.xml
# - call yast2 clone_system
# - upload autoinst.xml
# - upload original installedSystem.xml
# - run save_y2logs and upload the generated tar.bz2
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;
use utils qw(zypper_call);

sub run {
    my $self = shift;
    assert_script_run 'rm -f /root/autoinst.xml';
    zypper_call('in autoyast2', 300);
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'clone_system', yast2_opts => '--ncurses');
    if (check_screen 'autoyast2-install-accept', 10) {
        send_key 'alt-i';    # confirm package installation
    }
    wait_serial("$module_name-0", 700) || die "'yast2 clone_system' exited with non-zero code";
    upload_logs '/root/autoinst.xml';

    # original autoyast on kernel cmdline
    upload_logs '/var/adm/autoinstall/cache/installedSystem.xml';
    assert_script_run 'save_y2logs /tmp/y2logs_clone.tar.bz2';
    upload_logs '/tmp/y2logs_clone.tar.bz2';
    save_screenshot;
}

1;

