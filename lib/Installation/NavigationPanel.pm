# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Navigation Panel of
# installation wizard (which is shown in the bottom).
# The panel is extracted to the separate package as all the pages of
# installation wizard contain it, so this allows to reuse its accessing
# functions instead of duplicating them.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::NavigationPanel;
use strict;
use warnings FATAL => 'all';
use testapi;

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub press_next {
    send_key('alt-n');
}

1;
