# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
