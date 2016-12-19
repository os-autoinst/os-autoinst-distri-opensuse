# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SLE12 release notes
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2logsstep";
use strict;
use testapi;

sub run() {

    if (!check_screen('release-notes-button', 5)) {
        record_soft_failure 'workaround missing release notes';
        return;
    }

    # workaround for bsc#1014178
    wait_still_screen(5);
    if (check_screen('zfcp-popup', 0)) {
        record_soft_failure 'bsc#1014178';
        send_key 'alt-o';
    }
    my $addons = get_var('ADDONS', get_var('ADDONURL', get_var('DUD_ADDONS', '')));
    my @addons = split(/,/, $addons);
    if (check_var('SCC_REGISTER', 'installation')) {
        push @addons, split(/,/, get_var('SCC_ADDONS', ''));
    }
    if (get_var("UPGRADE")) {
        send_key "alt-e";    # open release notes window
    }
    else {
        # In text mode we can't click anything. On Xen PV we don't have
        # correct exis coordinates, so we miss the button: POO#13536.
        if (
            check_var('VIDEOMODE', 'text')
            or (    check_var('VIRSH_VMM_FAMILY', 'xen')
                and check_var('VIRSH_VMM_TYPE', 'linux')))
        {
            send_key "alt-l";    # open release notes window
        }
        else {
            assert_and_click('release-notes-button');
        }
    }
    wait_still_screen(2);
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'tab';          # select tab area
    }

    # no release-notes for WE and all modules
    my @no_relnotes = qw(we lgm asmm certm contm pcm tcm wsm);

    # no relnotes for ltss in QAM_MINIMAL
    push @no_relnotes, qw(ltss) if get_var('QAM_MINIMAL');
    if (@addons) {
        for my $a (@addons) {
            next if grep { $a eq $_ } @no_relnotes;
            send_key_until_needlematch("release-notes-$a", 'right', 4, 60);
            send_key 'left';     # move back to first tab
            send_key 'left';
            send_key 'left';
            send_key 'left';
        }
        send_key_until_needlematch("release-notes-sle", 'right');
    }
    else {
        assert_screen 'release-notes-sle';    # SLE release notes
    }

    # exit release notes window
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-o'; };
    }
    else {
        assert_screen([qw(release-notes-sle-ok-button release-notes-sle-close-button)]);
        if (match_has_tag('release-notes-sle-ok-button')) {
            wait_screen_change { send_key 'alt-o' };
        }
        else {
            wait_screen_change { send_key 'alt-c'; };
        }
    }
    if (!get_var("UPGRADE")) {
        send_key 'alt-e';    # select timezone region as previously selected
    }
}

1;

# vim: sw=4 et
