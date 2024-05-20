# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Other Desktop Environments: sway
#          Update the openQA internal configuration after the DE has been installed
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    
    set_var('DESKTOP', 'sway');
    
    set_var('DISPLAYMANAGER', 'lightdm');
    set_var('DM_NEEDS_USERNAME', 0);
    
    $self->result('ok');
}

1;
