# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class represents Sle15 distribution and provides access to its
# features.
# Follows the "Factory first" rule. So that the feature first appears in
# Tumbleweed distribution, and only if it behaves different in Sle15 then it
# should be overriden here.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Distribution::Sle::15;
use strict;
use warnings FATAL => 'all';
use parent 'Distribution::Opensuse::Tumbleweed';

1;
