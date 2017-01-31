# SUSE's openQA tests
#
# Copyright © 2015-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that snapper can revert file changes between snapshots
# Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils 'service_action';

sub run() {
    select_console 'root-console';

    my $snapfile     = '/root/snapfile';
    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');

    foreach my $snapper (@snapper_runs) {
        service_action('dbus', {type => ['socket', 'service'], action => ['stop', 'mask']}) if ($snapper =~ /dbus/);

        my $snapbf = script_output "$snapper create -p -d 'before undochange test'", 90;
        script_run "date > $snapfile";
        my $snapaf = script_output "$snapper create -p -d 'after undochange test'", 90;

        # Delete snapfile
        script_run "$snapper undochange $snapbf..$snapaf $snapfile", 90;
        script_run("test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev", 0);
        wait_serial("snap-ba-ok", 30) || die "Snapper undochange $snapbf..$snapaf failed";

        # Restore snapfile
        script_run "$snapper undochange $snapaf..$snapbf $snapfile", 90;
        assert_script_run("test -f $snapfile", timeout => 10, fail_message => "File $snapfile could not be found");

        assert_screen 'snapper_undochange';
        service_action('dbus', {type => ['socket', 'service'], action => ['unmask', 'start']}) if ($snapper =~ /dbus/);
        assert_script_run "rm $snapfile";
    }
}

sub post_fail_hook() {
    my ($self) = @_;

    upload_logs('/var/log/snapper.log');
}

sub test_flags() {
    return {important => 1};
}

1;
