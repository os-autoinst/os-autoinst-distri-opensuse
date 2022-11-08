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

    turn_off_plasma_tooltips();
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();

    # Also list branding packages (help to debug desktop branding issues)
    $self->save_and_upload_log('zypper --no-refresh se *branding*', '/tmp/list_branding_packages.txt', {screenshot => 1});
}

1;
