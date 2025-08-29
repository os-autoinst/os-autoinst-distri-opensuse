# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Prepare system with the repositories to be tested
# - Remove repositories by alias and url, as they could be leftovers in zdup scenarios or installer
# - Add to be tested repositories
# Maintainer: Santiago Zarate <santiago.zarate@suse.com>

use base "consoletest";
use testapi;
use version_utils 'is_staging';
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    # Trying to switch to more scalable solution with updated rsync.pl
    if (my $urlprefix = get_var('MIRROR_PREFIX')) {
        my @repos_to_add = qw(OSS NON_OSS OSS_DEBUG LEAP_MICRO);
        my $repourl;
        foreach (@repos_to_add) {
            next unless get_var("REPO_$_");    # Skip repo if not defined
            $repourl = $urlprefix . "/" . get_var("REPO_$_");
            # Remove other repos with the same effective URL, possibly added during installation already
            assert_script_run("zypper rr $repourl");
            assert_script_run("zypper rr ftp://" . get_var("REPO_HOST") . "/" . get_var("REPO_$_")) if get_var("REPO_HOST");
            # zdup scenarios might have already $_ added as a repo but disabled
            assert_script_run("zypper rr $_");
            assert_script_run("zypper ar $repourl $_");
        }
    }
    elsif (is_staging && get_var('ISO_1')) {
        # Use the product DVD as repository if not already there
        if (script_run('grep -qR "baseurl=cd:" /etc/zypp/repos.d/') != 0) {
            zypper_call 'ar -G cd:/ dvd';
        }
    }
    else {
        # non-NET installs have only milestone repo, which might be incompatible.
        my $repourl = 'http://' . get_required_var("SUSEMIRROR");
        unless (get_var("FULLURL")) {
            $repourl = $repourl . "/repo/oss";
        }
        zypper_call "ar -c $repourl Factory";
    }
}

1;
