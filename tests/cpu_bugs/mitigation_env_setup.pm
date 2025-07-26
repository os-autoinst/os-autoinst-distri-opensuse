# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup test environment for mitigation test
# Maintainer: An Long <lan@suse.com>

use base "opensusebasetest";
use testapi;
use utils;

sub run {
    my $self = shift;
    my $newlabel = get_required_var('SPECIFIC_DISK') . '-' . get_required_var('DISTRI') . '-' . get_required_var('VERSION') . '-';

    # for mitigation test, add build tag or build number to disk label
    if (lc(get_var('MYBUILD')) =~ /alpha|beta|rc|gm/) {
        $newlabel .= get_var('MYBUILD');
    }
    else {
        $newlabel .= 'BUILD' . get_required_var('BUILD');
    }

    assert_script_run("btrfs filesystem label / $newlabel");

}

1;
