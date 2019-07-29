# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add simple machinery test thanks to greygoo (#1592)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration qw(add_suseconnect_product register_product);


sub run {
    select_console 'root-console';

    if (is_sle) {
        assert_script_run 'source /etc/os-release';
        if (is_sle '>=15') {
            add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        }
        else {
            register_product();
            if (script_run('SUSEConnect -p sle-module-adv-systems-management/12/${CPU}') == 67) {
                record_soft_failure 'bsc#1124343 - ASMM Module not yet available for SLE12SP5';
                return;
            }
        }
    }

    if (zypper_call('in machinery', exitcode => [0, 4]) == 4) {
        if (is_sle) {
            record_soft_failure 'bsc#1124304 - Dependency of machinery missing (dep is in HA module)';
        }
        elsif (is_opensuse) {
            record_soft_failure 'boo#1142975 - Dependency of machinery missing in TW';
        }
        return;
    }
    validate_script_output 'machinery --help', sub { m/machinery - A systems management toolkit for Linux/ }, 100;
    prepare_ssh_localhost_key_login 'root';
    if (get_var('ARCH') =~ /aarch64|ppc64le/ && \
        script_run("machinery inspect localhost | grep 'no machinery-helper for the remote system architecture'", 300) == 0) {
        record_soft_failure 'boo#1125785 - no machinery-helper for this architecture.';
    } else {
        assert_script_run 'machinery inspect localhost',               300;
        assert_script_run 'machinery show localhost | grep machinery', 100;
    }
}

1;
