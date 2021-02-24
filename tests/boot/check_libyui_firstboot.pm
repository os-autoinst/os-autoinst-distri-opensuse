# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Check that libyui is available before firstboot
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'bootbasetest';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    YuiRestClient::connect_to_app();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
