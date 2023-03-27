# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Add repos from corresponding mirror only if do not exist
# Maintainer: Max Lin <mlin@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils 'is_staging';
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    # Trying to switch to more scalable solution with updated rsync.pl
    if (my $urlprefix = get_var('MIRROR_PREFIX')) {
        my @repos_to_add = qw(OSS NON_OSS OSS_DEBUGINFO ALP LEAP_MICRO);
        my $repourl;
        foreach (@repos_to_add) {
            next unless get_var("REPO_$_");    # Skip repo if not defined
            $repourl = $urlprefix . "/" . get_var("REPO_$_");
            # Skip add repo if already added
            my $rc = script_run "zypper lr | grep -w $_ || zypper ar -c $repourl $_";
            # treat OSS error as test failure, others can be just recorded
            if ($rc) {
                ($_ =~ m/^OSS$/) ? die 'Adding OSS repo failed!' : record_info("$_ repo failure", "zypper exited with code $rc");
            }
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
