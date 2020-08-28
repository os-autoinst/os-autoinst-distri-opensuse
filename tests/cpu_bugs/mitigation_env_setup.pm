# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup test environment for mitigation test
# Maintainer: An Long <lan@suse.com>

use warnings;
use strict;
use base "opensusebasetest";
use testapi;
use utils;

sub run {
    my $self = shift;

    my $newlabel = get_required_var('DISTRI') . '-' . get_required_var('VERSION') . '-';

    # for mitigation test, disk label with build tag, while with Build number
    if (lc(get_var('MYBUILD')) =~ /alpha|beta|rc|gm/) {
        $newlabel .= get_var('MYBUILD');
    }
    else {
        $newlabel .= 'BUILD' . get_required_var('BUILD');
    }

    assert_script_run("btrfs filesystem label / $newlabel");

}

1;
