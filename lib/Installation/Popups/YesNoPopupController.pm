# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for yes/no Popups
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::YesNoPopupController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Popups::YesNoPopup;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{YesNoPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_yes_no_popup {
    my ($self) = @_;
    die 'YesNo Popup is not displayed' unless $self->{YesNoPopup}->is_shown();
    return $self->{YesNoPopup};
}

sub get_text {
    my ($self) = @_;
    $self->get_yes_no_popup()->text();
}

sub accept {
    my ($self) = @_;
    $self->get_yes_no_popup()->press_yes();
}

sub decline {
    my ($self) = @_;
    $self->get_yes_no_popup()->press_no();
}

1;
