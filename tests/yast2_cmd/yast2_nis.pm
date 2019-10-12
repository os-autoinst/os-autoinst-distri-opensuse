# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup nis client and bind nis server
# Enviroment:
# - external server: wotan.suse.de, hilbert.suse.de
# - qemu user mode networking disables broadcast so that functionality is not covered.
#
# 1. Bind a nis server and veirfy it succeed.
# 2. Change binding to another server, configure automount.
# 3. Disable binding, automount
# Maintainer: Tony Yuan <tyuan@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    zypper_call("in yast2-nis-client ypbind", exitcode => [0, 102, 103, 106]);
    my $flg = is_sle('=12-SP2') ? 1 : 0;    #"yast2 nis-server summary" return 16 on 12sp2 so set proceed_on_failure=1 to avoid throwing exception. BUG#1143516.

    #Binding
    assert_script_run("yast nis enable server=wotan.suse.de domain=suse.de");
    validate_script_output("ypwhich 2>&1", sub { /wotan.suse.de|dns2.suse.de/ });

    #Change binding, configure automount.
    assert_script_run("yast nis configure server=hilbert.suse.de");
    validate_script_output("ypwhich 2>&1", sub { /hilbert.suse.de/ });
    assert_script_run("yast nis configure automounter=yes");
    systemctl('is-enabled autofs.service');
    validate_script_output("yast nis summary 2>&1", sub { m/Servers:\s(.*?)\n.*Automounter\senabled:\s(.*)/s && $1 eq "hilbert.suse.de" && $2 eq "Yes" }, timeout => 30, proceed_on_failure => $flg);

    #Disable binding, automount
    assert_script_run("yast nis disable");
    assert_script_run("yast nis configure automounter=no");
    validate_script_output("yast nis summary 2>&1", sub { m/Client\sEnabled:\s(.*?)\n.*Automounter\senabled:\s(.*)/s && $1 eq "No" && $2 eq "No" }, timeout => 30, proceed_on_failure => $flg);
}

1;
