# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base "opensusebasetest";
use strict;

use testapi;

sub post_fail_hook() {
    my $self = shift;

    select_console 'root-console';
    save_screenshot;

    my $fn = sprintf '/tmp/y2logs-%s.tar.bz2', ref $self;
    type_string "save_y2logs $fn\n";
    upload_logs $fn;
    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

# Executes the command line tests from a yast repository (in master or in the
# given optional branch) using prove
sub run_yast_cli_test {
    my ($self, $packname) = @_;
    my $PACKDIR = '/usr/src/packages';

    assert_script_run "zypper -n in $packname";
    assert_script_run "zypper -n si $packname";
    assert_script_run "rpmbuild -bp $PACKDIR/SPECS/$packname.spec";
    script_run "pushd $PACKDIR/BUILD/$packname-*";

    # Run 'prove' only if there is a directory called t
    script_run("if [ -d t ]; then echo -n 'run'; else echo -n 'skip'; fi > /dev/$serialdev", 0);
    my $action = wait_serial(['run', 'skip'], 10);
    if ($action eq 'run') {
        assert_script_run 'prove';
    }

    script_run 'popd';

    # Should we cleanup after?
    #script_run "rm -rf $packname-*";
}

1;
# vim: set sw=4 et:
