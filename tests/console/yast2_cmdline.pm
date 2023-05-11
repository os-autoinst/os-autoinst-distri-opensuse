# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm-build yast2-network yast2-http-server
# Summary: Support for the new tests for yast command line
# Maintainer: Ancor Gonzalez Sosa <ancor@suse.de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call systemctl);
use repo_tools 'prepare_source_repo';
use version_utils qw(is_sle is_leap);

# Executes the command line tests from a yast repository (in master or in the
# given optional branch) using prove
sub run_yast_cli_test {
    my ($packname) = @_;
    my $PACKDIR = '/usr/src/packages';

    zypper_call "in $packname";
    zypper_call "si $packname";
    assert_script_run "rpmbuild -bp $PACKDIR/SPECS/$packname.spec";
    script_run "pushd $PACKDIR/BUILD/$packname-*";

    # Run 'prove' only if there is a directory called t
    script_run("if [ -d t ]; then echo -n 'run'; else echo -n 'skip'; fi > /dev/$serialdev", 0);
    my $action = wait_serial(['run', 'skip'], 10);
    if ($action eq 'run') {
        assert_script_run('prove -v', timeout => 180, fail_message => 'yast cli tests failed');
    }

    script_run 'popd';

    # Should we cleanup after?
    #script_run "rm -rf $packname-*";
}

sub run {
    select_console 'root-console';
    die "wicked is not used. The yast2_network tests can run only against wicked." if (systemctl("status wicked.service", ignore_failure => 1) != 0);
    prepare_source_repo;

    # Install test requirement
    zypper_call 'in rpm-build';

    # Enable source repo
    zypper_call 'mr -e repo-source';

    # Run YaST CLI tests
    run_yast_cli_test('yast2-network');
    run_yast_cli_test('yast2-http-server') if (is_leap("<16.0") || is_sle("<16"));
}

1;
