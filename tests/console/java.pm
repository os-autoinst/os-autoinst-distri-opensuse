# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Description: Basic Java test
# Summary: It installs every Java version which is available into
#          the repositories and then it performs a series of basic
#          tests, such as verifying the version, compile and run
#          the Hello World program
# Maintainer: Panos Georgiadis <pgeorgiadis@suse.com>
# Maintainer: Andrej Semen <asemen@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Make sure that PackageKit is not running
    pkcon_quit;

    # Capture the return code value of the following scenarios
    my $bootstrap_pkg_rt = zypper_call("se java-*bootstrap", exitcode => [0, 104]);
    my $bootstrap_conflicts_rt = zypper_call("in --auto-agree-with-licenses --dry-run java-*", exitcode => [0, 4]);

    # logs / debugging purposes
    diag "checking variable: bootstrap_pkg_rt = $bootstrap_pkg_rt";
    diag "checking variable: bootstrap_conflicts_rt = $bootstrap_conflicts_rt";

    if (check_var("DISTRI", "sle")) {
        zypper_call("in --auto-agree-with-licenses java-*", timeout => 1400);
    }

    if (check_var("DISTRI", "opensuse")) {
        if ($bootstrap_pkg_rt == 0) {
            diag "There are java bootstrap packages available to be installed";
            print "There are java bootstrap packages available to be installed\n";
            if ($bootstrap_conflicts_rt == 0) {
                diag "There is no conflict installing the java bootstrap packages";
                print "There is no conflict installing the java bootstrap packages\n";
                zypper_call "in java-*";
            }
            else {
                diag "There are conflicts with the installation of java bootstrap packages";
                print "There are conflicts with the installation of java bootstrap packages\n";
                record_soft_failure 'boo#1019090';
                # Workaround: install java-* except from the problematic bootstrap packages
                zypper_call "in `(zypper se java-* | grep -v bootstrap | grep -v 'i ' | awk '{print \$2}' | sed -n -E -e '/java/,\$ p')`";
            }
        }
        else {
            diag "There are no java bootstrap packages";
            print "There are no java bootstrap packages\n";
            zypper_call("in java-*", exitcode => [0, 107]);
        }
    }

    zypper_call 'in wget';
    assert_script_run 'wget --quiet ' . data_url('console/test_java.sh');
    assert_script_run 'chmod +x test_java.sh';
    assert_script_run './test_java.sh';
}
1;
