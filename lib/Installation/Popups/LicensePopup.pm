# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles License Popup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::LicensePopup;
use parent 'YaST::PageBase';
use strict;
use warnings;
use YuiRestClient;

sub init {
    my $self = shift;
    $self->{btn_accept} = $self->{app}->button({id => "accept"});
    $self->{rct_license} = $self->{app}->richtext({id => "lic"});
    return $self;
}

sub get_license_popup {
    my ($self) = @_;
    die "License popup is not shown" unless $self->{rct_license}->exist();
    return $self;
}

sub accept {
    my ($self) = @_;
    $self->get_license_popup()->{btn_accept}->click();
}

1;
