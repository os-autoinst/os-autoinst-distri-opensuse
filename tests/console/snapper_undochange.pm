# SUSE's openQA tests
#
# Copyright © 2015-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that snapper can revert file changes between snapshots
# Maintainer: mkravec <mkravec@suse.com>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $snapfile     = '/etc/snapfile';
    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');

    foreach my $snapper (@snapper_runs) {
        $self->snapper_nodbus_setup if $snapper =~ /dbus/;

        assert_script_run "snapbf=`$snapper create -p -d 'before undochange test'`", 90;
        script_run "date > $snapfile";    # simulate system changing by adding new dummy file
        assert_script_run "snapaf=`$snapper create -p -d 'after undochange test'`", 90;

        # Delete snapfile
        script_run "$snapper undochange \$snapbf..\$snapaf $snapfile", 90;
        script_run("test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev", 0);
        wait_serial("snap-ba-ok", 30) || die "Snapper undochange failed";

        # Restore snapfile
        script_run "$snapper undochange \$snapaf..\$snapbf $snapfile", 90;
        assert_script_run("test -f $snapfile", timeout => 10, fail_message => "File $snapfile could not be found");

        assert_screen 'snapper_undochange';
        assert_script_run "rm $snapfile";
        $self->snapper_nodbus_restore if $snapper =~ /dbus/;
    }
}

1;

