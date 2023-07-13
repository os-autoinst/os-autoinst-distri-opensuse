=head1 y2_module_basetest.pm

This module provides common subroutines for YaST2 modules in graphical and text mode.

=cut
# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module provides common subroutines for YaST Firstboot Configuration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
