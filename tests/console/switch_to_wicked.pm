# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Switch from NetworkManager to wicked.
# Maintainer: QA SLE Functional YaST <qa-sle-yast@suse.de>

use base 'consoletest';
use y2_module_basetest;
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = shift;
    select_console 'root-console';
    return unless is_network_manager_default;
    $self->use_wicked_network_manager;
}

1;
