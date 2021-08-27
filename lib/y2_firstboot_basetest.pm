=head1 y2_module_basetest.pm

This module provides common subroutines for YaST2 modules in graphical and text mode.

=cut
# SUSE's openQA tests
#
# Copyright © 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: This module provides common subroutines for YaST Firstboot Configuration
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

package y2_firstboot_basetest;

use parent 'y2_module_basetest';
use strict;
use warnings;
use testapi;

sub post_run_hook {
    save_screenshot;
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    upload_logs('/etc/YaST2/firstboot.xml', log_name => "firstboot.xml.conf");
}

sub test_flags {
    return {fatal => 1};
}

1;
