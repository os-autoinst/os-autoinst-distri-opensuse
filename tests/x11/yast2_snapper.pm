# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for yast2-snapper
# Maintainer: Richard Brown <rbrown@suse.de>

use base qw(y2snapper_common x11test);
use strict;
use warnings;
use testapi;
use utils;

# Test for basic yast2-snapper functionality. It assumes the data of the
# opensuse distri to be available at /home/$username/data (as granted by
# console_setup.pm)

sub run {
    my $self = shift;
    # Make sure yast2-snapper is installed (if not: install it)
    ensure_installed "yast2-snapper";

    # Start an xterm as root
    x11_start_program('xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;
    script_run "cd";
    type_string "yast2 snapper\n";
    $self->y2snapper_new_snapshot;

    wait_still_screen;
    $self->y2snapper_untar_testfile;

    type_string "yast2 snapper; echo yast2-snapper-status-\$? > /dev/$serialdev\n";
    $self->y2snapper_show_changes_and_delete;
    $self->y2snapper_clean_and_quit;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->y2snapper_failure_analysis;
}

1;
