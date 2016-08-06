# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

sub show_debug() {
    type_string "ps auxf\n";
    save_screenshot;
    type_string "dmesg\n";
    save_screenshot;
}

sub format_dasd() {
    my $self = shift;
    my $r;

    # activate install-shell to do pre-install dasd-format
    select_console('install-shell');

    # bring dasd online
    # exit status 0 -> everything ok
    # exit status 8 -> unformatted but still usable (e.g. from previous testrun)
    script_run("dasd_configure 0.0.0150 1; echo dasd_configure-status-\$? > /dev/$serialdev", 0);
    wait_serial(qr/dasd_configure-status-[08]/) || die "DASD in undefined state";

    # make sure that there is a dasda device
    $r = script_run("lsdasd");
    assert_screen("ensure-dasd-exists");
    # always calling debug output, trying to help with poo#12596
    show_debug();
    die "dasd_configure died with exit code $r" unless (defined($r) && $r == 0);

    # format dasda (this can take up to 20 minutes depending on disk size)
    $r = script_run("echo yes | dasdfmt -b 4096 -p /dev/dasda", 1200);
    show_debug();
    die "dasdfmt died with exit code $r" unless (defined($r) && $r == 0);
}

sub run() {
    # we also want to test the formatting during the installation if the variable is set
    if (!get_var("FORMAT_DASD_YAST") && !get_var('S390_DISK')) {
        format_dasd;
    }

    $self->result('ok');
}

1;
