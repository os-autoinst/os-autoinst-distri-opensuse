# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;
use lockapi;

sub run() {
    my $self = shift;
    # NET isos are slow to install
    my $timeout = 2000;

    # workaround for yast popups
    my @tags = qw/rebootnow/;
    if (get_var("UPGRADE")) {
        push(@tags, "ERROR-removing-package");
        push(@tags, "DIALOG-packages-notifications");
        $timeout = 5500;    # upgrades are slower
    }
    my $keep_trying = 1;
    while ($keep_trying) {
        # try gracefully on aarch64 because of boo#982136
        if (check_var('ARCH', 'aarch64')) {
            my $ret = check_screen \@tags, $timeout;
            if (!$ret) {
                die 'timed out installation even after retrying' unless $keep_trying;
                record_soft_failure 'boo#982136: timed out after ' . $timeout . 'seconds, trying once more';
                $keep_trying = 0;
                next;
            }
        }
        else {
            assert_screen \@tags, $timeout;
        }
        if (match_has_tag("DIALOG-packages-notifications")) {
            send_key 'alt-o';    # ok
            next;
        }
        # can happen multiple times
        if (match_has_tag("ERROR-removing-package")) {
            record_soft_failure;
            send_key 'alt-d';    # details
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';    # ignore
            next;
        }
        last;
    }

    if (get_var("REMOTE_MASTER")) {
        mutex_create("installation_finished");
    }
    else {
        send_key 'alt-s';        # Stop the reboot countdown
        select_console 'install-shell';
        $self->get_ip_address();
        $self->save_upload_y2logs();
        select_console 'installation';
        assert_screen 'rebootnow';
    }

    if (get_var("LIVECD")) {
        # LiveCD needs confirmation for reboot
        send_key $cmd{rebootnow};
    }
    else {
        send_key 'alt-o';
    }
}

1;
# vim: set sw=4 et:
