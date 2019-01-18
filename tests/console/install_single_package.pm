# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Testing Installation of any given package which
# has openqa-ci-tools package as dependency and obey the provided contract
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    pkcon_quit;

    # add specific repository which contains the package
    if (get_var('PACKAGE_REPO')) {
        zypper_call("ar -f " . get_var('PACKAGE_REPO') . " testrepo");
        # flow suggested in this test requires 'openqa-ci-tools' package
        # which currently exists in single repo in the world so point to give flexibility here
        zypper_call("ar -f http://download.suse.de/ibs/Devel:/HPC:/CI/SLE_12_SP2_HPC_CI/ hpc_ci");
        zypper_call("--gpg-auto-import-keys ref");
    }

    # write 'zypper lr' to $serialdev for having more debug information
    script_run("zypper lr -d | tee /dev/$serialdev");

    # install desired package
    my $pkgname = get_required_var('PACKAGETOINSTALL');
    zypper_call "in $pkgname";

    # ensure that package was installed correctly
    assert_script_run("rpm -q $pkgname");
    my $exit_code = script_run('ci-openqa-tests');
    upload_logs("/var/lib/openqa/CI/results/summary.results");
    assert_script_run("tar -zcvf logs.tar.gz /var/lib/openqa/CI/log/");
    upload_logs("logs.tar.gz");
    die("\'ci-openqa-tests\' failed with $exit_code. Failing the test") if $exit_code;
}

# we don't need any system log for this package test.
sub post_fail_hook {
}

1;
