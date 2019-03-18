# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: A library that provides the certain distribution depending on the
# version of the product that is specified for a Test Suite.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package DistributionProvider;
use strict;
use warnings FATAL => 'all';
use version_utils;

use Distribution::Sle::15;
use Distribution::Sle::12;
use Distribution::Opensuse::Leap::42;
use Distribution::Opensuse::Leap::15;
use Distribution::Opensuse::Tumbleweed;

=head2 provide

  provide();

Returns the certain distribution depending on the version of the product.

If there is no matched version, then returns Tumbleweed as the default one.

=cut
sub provide {
    return Distribution::Sle::15->new()            if version_utils::is_sle('15+');
    return Distribution::Sle::12->new()            if version_utils::is_sle('12+');
    return Distribution::Opensuse::Leap::15->new() if version_utils::is_leap('15.0+');
    return Distribution::Opensuse::Leap::42->new() if version_utils::is_leap('42.0+');
    return Distribution::Opensuse::Tumbleweed->new();
}

1;
