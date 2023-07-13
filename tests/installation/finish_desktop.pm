# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: move all inst/$DESKTOP.pm into one global 999_finish_desktop and run the tests from start.pl
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "installbasetest";
use testapi;
use strict;
use warnings;
use main_common 'opensuse_welcome_applicable';
use x11utils 'turn_off_plasma_tooltips';
use Utils::Logging qw(save_and_upload_log export_logs);

# using this as base class means only run when an install is needed
sub run {
    my $self = shift;

    # live may take ages to boot
    my $timeout = 600;

    my @tags = qw(generic-desktop);
    push(@tags, qw(opensuse-welcome)) if opensuse_welcome_applicable;
    push(@tags, 'gnome-activities') if check_var('DESKTOP', 'gnome');

    assert_screen \@tags, $timeout;
    # Starting with GNOME 40, upon login, the activities screen is open (assuming the
    # user will want to start something. For openQA, we simply press 'esc' to close
    # it again and really end up on the desktop
    if (match_has_tag('gnome-activities')) {
        send_key 'esc';
        @tags = grep { !/gnome-activities/ } @tags;
        assert_screen \@tags, $timeout;
    }

    # This only works with generic-desktop. In the opensuse-welcome case,
    # the opensuse-welcome module will handle it instead.
    turn_off_plasma_tooltips if match_has_tag('generic-desktop');
}

sub post_fail_hook {
    my $self = shift;

    export_logs();

    # Also list branding packages (help to debug desktop branding issues)
    save_and_upload_log('zypper --no-refresh se *branding*', '/tmp/list_branding_packages.txt', {screenshot => 1});
}

1;
