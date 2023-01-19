# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-solv perl-Data-Dump zypper libzypp
# Summary: new test that installs configured packages
# Maintainer: Stephan Kulow <coolo@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    my $packages = get_var("INSTALL_PACKAGES");

    zypper_call('in -l perl-solv perl-Data-Dump');
    my $ex = script_run("~$username/data/lsmfip --verbose $packages > \$XDG_RUNTIME_DIR/install_packages.txt 2> /tmp/lsmfip.log");
    upload_logs '/tmp/lsmfip.log';
    die "lsmfip failed" if $ex;
    # make sure we install at least one package - otherwise this test is pointless
    # better have it fail and let a reviewer check the reason
    assert_script_run("test -s \$XDG_RUNTIME_DIR/install_packages.txt");
    # might take longer for large patches (i.e. 12 kernel flavors)
    assert_script_run("xargs --no-run-if-empty zypper -n in -l < \$XDG_RUNTIME_DIR/install_packages.txt", 1400);
    assert_script_run("grep -Ev '^-' \$XDG_RUNTIME_DIR/install_packages.txt | xargs --no-run-if-empty rpm -q -- | tee /dev/$serialdev");
}

sub test_flags {
    return {fatal => 1};
}

1;
