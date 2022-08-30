# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: SLE12 release notes
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle is_microos);

sub run {
    return if is_microos();
    assert_screen('release-notes-button', 60);

    # workaround for bsc#1014178
    wait_still_screen(5);
    if (check_screen('zfcp-popup', 0)) {
        record_soft_failure 'bsc#1014178';
        send_key 'alt-o';
    }
    my $addons = get_var('ADDONS', get_var('ADDONURL', get_var('DUD_ADDONS', '')));
    my @addons = split(/,/, $addons);
    if (check_var('SCC_REGISTER', 'installation') || (get_var("UPGRADE") && is_sle('15+'))) {
        my @scc_addons = grep { $_ ne "" } split(/,/, get_var('SCC_ADDONS', ''));

        push @addons, @scc_addons;
    }
    # Unique addons
    my %seen;
    for (@addons) { $seen{$_}++; }
    @addons = keys %seen;

    if (get_var("UPGRADE")) {
        send_key "alt-e";    # open release notes window
    }
    else {
        # In text mode we can't click anything.
        if (check_var('VIDEOMODE', 'text')) {
            send_key "alt-l";    # open release notes window
        }
        else {
            assert_and_click('release-notes-button');
        }
    }
    wait_still_screen(2);
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'tab';    # select tab area
    }

    # no release-notes for WE and all modules
    my @no_relnotes = qw(all-packages asmm certm contm hpcm ids idu lgm pcm phub sapapp tcm tsm we wsm);

    # No release-notes for basic modules and Live-Patching on SLE 15
    if (is_sle('15+')) {
        push @no_relnotes, qw(base script desktop serverapp legacy sdk live);
        # WE has release-notes on SLE 15
        @no_relnotes = grep(!/^we$/, @no_relnotes);
    }

    # No HA-GEO on ppc64le before SLE 15 (OFW firmware is only used on ppc* at this time)
    # But HA-GEO in now (SLE 15+) included in HA extension for all platforms
    # So we can remove it on ppc64le and SLE 15+
    @addons = grep(!/^geo$/, @addons) if get_var('OFW') or is_sle('15+');

    # no relnotes for ltss in QAM_MINIMAL
    push @no_relnotes, qw(ltss) if get_var('QAM_MINIMAL');
    # no HA-GEO release-notes for s390x on SLE12-SP1 GM media, see bsc#1033504
    if (is_s390x and check_var('BASE_VERSION', '12-SP1')) {
        push @no_relnotes, qw(geo);
    }
    if (@addons) {
        if (!check_var('VIDEOMODE', 'text')) {
            # Make sure release notes window is shown to avoid sending key too early
            # It takes longer time to show multilple release notes for addons
            assert_screen([qw(release-notes-sle-ok-button release-notes-sle-close-button)], 300);
        }
        wait_still_screen(2);
        for my $i (@addons) {
            next if grep { $i eq $_ } @no_relnotes;
            send_key_until_needlematch("release-notes-$i", 'right', 5, 60);
            send_key 'left';    # move back to first tab
            send_key 'left';
            send_key 'left';
            send_key 'left';
        }
        send_key_until_needlematch("release-notes-sle", 'right');
    }
    else {
        assert_screen 'release-notes-sle', 150;    # SLE release notes
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
