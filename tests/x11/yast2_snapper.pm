# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-snapper
# Summary: Test for yast2-snapper
# - Disable gnome-screensaver
# - Install yast2-snapper
# - Launch a xterm as root and run yast2 snapper
# - Setup another snapper config for /test
# - In yast2 snapper, create a new snapshot, named "awesome snapshot"
# - Apply some modification to filesystem
# - Launch yast2 snapper again, select created snapshot, display the differences
# - Delete "awesome snapshot"
# - Close yast2 snapper, delete testadata
# Maintainer: Richard Brown <rbrown@suse.de>

use base qw(y2snapper_common x11test);
use testapi;
use utils;
use x11utils 'turn_off_gnome_screensaver';
use y2_module_consoletest;

# Test for basic yast2-snapper functionality. It assumes the data of the
# opensuse distri to be available at /home/$username/data (as granted by
# console_setup.pm)

sub run {
    my $self = shift;

    # Make sure that the module runs on graphical mode
    unless (check_screen 'generic-desktop', 0) {
        select_console 'x11';
        $self->handle_displaymanager_login() if (check_screen 'linux-login', 0);
    }

    # Turn off screensaver
    x11_start_program('xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    send_key("alt-f4");    # close xterm

    # Make sure yast2-snapper is installed (if not: install it)
    ensure_installed "yast2-snapper";

    # Start an xterm as root
    x11_start_program('xterm');
    # Wait before typing to avoid typos
    wait_still_screen(5);
    become_root;
    script_run "cd";
    $self->y2snapper_adding_new_snapper_conf;
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'snapper');
    $self->y2snapper_new_snapshot;
    wait_serial("$module_name-0") || die "yast2 snapper failed";

    $self->y2snapper_apply_filesystem_changes;
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'snapper');
    $self->y2snapper_show_changes_and_delete;
    $self->y2snapper_clean_and_quit($module_name);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->y2snapper_failure_analysis;
}

1;
