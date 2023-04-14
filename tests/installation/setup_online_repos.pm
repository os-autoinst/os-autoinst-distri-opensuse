# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: New test: Test installation with update repos
#    Basically for Leap only. https://progress.opensuse.org/issues/9620
# Maintainer: Max Lin <mlin@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils;

sub run {
    # ordered according to real repos lists
    my @default_repos;
    if (is_leap('<15.1')) {
        @default_repos = qw(update-non-oss update-oss main-non-oss main-oss debug-main untested-update debug-update source);
    }
    elsif (is_leap('>=15.3')) {
        # 15.3 has introduced additional repositories
        @default_repos = qw(update-sle update-backports update-non-oss main-non-oss update-oss main-oss debug-backports-update debug-update untested-update source debug-main);
    }
    else {
        @default_repos = qw(update-non-oss main-non-oss update-oss main-oss debug-update untested-update source debug-main);
    }
    # maybe slow due to network connectivity
    assert_screen [qw(setup_online_repos-configure setup_online_repos-configure-text online-repos)], 200;

    if (match_has_tag('setup_online_repos-configure-text')) {
        send_key 'alt-o';
    }
    elsif (match_has_tag('setup_online_repos-configure')) {
        assert_and_click 'setup_online_repos-configure';
    }

    if (!match_has_tag('online-repos')) {
        assert_screen 'online-repos', 200;
    }

    # move the cursor to repos lists
    if (check_var("VIDEOMODE", "text")) {
        send_key_until_needlematch 'setup_online_repos-repos-list', 'tab';
    }
    else {
        send_key is_sle('<15') || is_leap('<15.0') ? 'alt-i' : 'alt-u';
    }

    foreach my $repotag (@default_repos) {
        my $needs_to_be_selected = 0;

        if (get_var("WITH_UPDATE_REPO") && $repotag =~ /^update/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_MAIN_REPO") && $repotag =~ /^main/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_DEBUG_REPO") && $repotag =~ /^debug/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_SOURCE_REPO") && $repotag =~ /^source/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_UNTESTED_REPO") && $repotag =~ /^untested/) {
            $needs_to_be_selected = 1;
        }
        # check current entry is selected or not
        if (!check_screen("$repotag-selected", 5)) {
            send_key "spc" if $needs_to_be_selected;
        }
        else {
            send_key "spc" unless $needs_to_be_selected;
        }
        send_key "down";
    }

    if (get_var("WITH_UPDATE_REPO")) {
        assert_screen 'update-repos-selected', 10;
    }
    # TODO: assert screen for the rest of repos in case they are enabled

    send_key $cmd{next};    # Next

    if (get_var("WITH_MAIN_REPO")) {
        # older product versions check for same license multiple times so we
        # need to check that
        if (is_sle('<15') || is_leap('<15.0')) {
            assert_screen 'license-dialog-oss-repo';
            send_key $cmd{next};    # Next
        }
    }

    if (get_var("WITH_UNTESTED_REPO")) {
        assert_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48';
        while (1) {
            send_key 'alt-t';    # Trust
                                 # for some reason the key is prompted twice, bug?
            last unless check_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48', 30;
        }
    }
}

1;
