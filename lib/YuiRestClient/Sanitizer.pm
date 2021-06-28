# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Sanitizer;
use strict;
use warnings;

sub sanitize {
    my ($item) = shift;
    # remove shortcut
    $item =~ s/&//;
    return $item;
}

1;
