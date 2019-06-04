# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Support for the new tests for yast command line
# Maintainer: Ancor Gonzalez Sosa <ancor@suse.de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use repo_tools 'prepare_source_repo';

# Executes the command line tests from a yast repository (in master or in the
# given optional branch) using prove
sub run_yast_cli_test {
    my ($packname) = @_;
    my $PACKDIR = '/usr/src/packages';

    assert_script_run "zypper -n in $packname";
    assert_script_run "zypper -n si $packname";
    assert_script_run "rpmbuild -bp $PACKDIR/SPECS/$packname.spec";
    script_run "pushd $PACKDIR/BUILD/$packname-*";

    # Run 'prove' only if there is a directory called t
    script_run("if [ -d t ]; then echo -n 'run'; else echo -n 'skip'; fi > /dev/$serialdev", 0);
    my $action = wait_serial(['run', 'skip'], 10);
    if ($action eq 'run') {
        assert_script_run('prove -v', timeout => 90, fail_message => 'yast cli tests failed');
    }

    script_run 'popd';

    # Should we cleanup after?
    #script_run "rm -rf $packname-*";
}

sub run {
    select_console 'root-console';

    prepare_source_repo;

    # Install test requirement
    assert_script_run 'zypper -n in rpm-build';

    # Enable source repo
    assert_script_run 'zypper mr -e repo-source';

    # Run YaST CLI tests
    run_yast_cli_test('yast2-network');
    run_yast_cli_test('yast2-http-server');
}

1;
