# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Warning Popups
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::OKPopupController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Popups::OKPopup;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{OKPopup} = Installation::Popups::OKPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_ok_popup {
    my ($self) = @_;
    die 'OK Popup is not displayed' unless $self->{OKPopup}->is_shown();
    return $self->{OKPopup};
}

sub get_text {
    my ($self) = @_;
    $self->get_ok_popup()->text();
}

sub accept {
    my ($self) = @_;
    $self->get_ok_popup()->press_ok();
}

1;
