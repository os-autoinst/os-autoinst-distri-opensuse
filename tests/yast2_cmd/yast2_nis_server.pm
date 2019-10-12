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
# Summary: Setup nis server
# Enviroment:
# - external server: wotan.suse.de, hilbert.suse.de
# - qemu user mode networking disables broadcast so broadcast functionality is not covered.
#
# 1. Reproduce Bug 1146030
# 2. Setup master server and bind locally.
# 3. Setup slave server and bind locally.
# Maintainer: Tony Yuan <tyuan@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    zypper_call("in yast2-nis-server ypserv", exitcode => [0, 102, 103, 106]);
    my $flg = is_sle('=12-SP2') ? 1 : 0;    #"yast2 nis-server summary" return 16 on 12sp2 so set proceed_on_failure=1 to avoid throwing exception. BUG#1143516.

    # reproduce bug
    my $out = script_output("yast2 nis-server summary 2>&1", proceed_on_failure => $flg);
    record_soft_failure("Bug 1146030") if ($out =~ /A NIS slave server is configured/);

    # master server test
    assert_script_run("yast nis-server master domain=nismaster.test");
    validate_script_output("yast2 nis-server summary 2>&1", sub { /A NIS master server is configured/ }, timeout => 30, proceed_on_failure => $flg);
    assert_script_run("yast2 nis enable domain=nismaster.test server=10.0.2.15");
    validate_script_output("ypwhich 2>&1", sub { /10.0.2.15/ });
    assert_script_run("yast2 nis-server stop");
    validate_script_output("yast2 nis-server summary 2>&1", sub { /NIS Master Server: Not configured yet/ }, timeout => 30, proceed_on_failure => $flg);

    # slave server
    assert_script_run("yast nis-server slave domain=suse.de master_ip=10.160.0.1");
    validate_script_output("yast2 nis-server summary 2>&1", sub { /A NIS slave server is configured/ }, timeout => 30, proceed_on_failure => $flg);
    assert_script_run("yast2 nis configure domain=suse.de server=10.0.2.15");
    validate_script_output("ypwhich 2>&1", sub { /10.0.2.15/ });
    assert_script_run("yast nis disable");
    assert_script_run("yast2 nis-server stop");
}

1;
