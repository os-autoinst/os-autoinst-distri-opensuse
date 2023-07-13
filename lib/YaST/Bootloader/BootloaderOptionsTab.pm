# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Bootloader Options tab
# in Boot Loader Settings.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Bootloader::BootloaderOptionsTab;
use strict;
use warnings;
use testapi;

sub new {
    my $self = shift;
    return $self;
}

sub navigate {
    my ($self) = @_;
    send_key 'tab' unless match_has_tag 'inst-bootloader-settings-first_tab_highlighted';
    send_key_until_needlematch 'inst-bootloader-options-highlighted', 'right';
}

1;
