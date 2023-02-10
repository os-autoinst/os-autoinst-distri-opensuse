# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Popups with Accept option
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::AcceptPopupController;
use strict;
use warnings;
use YuiRestClient;
use YuiRestClient::Wait;
use Installation::Popups::AcceptPopup;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{AcceptPopup} = Installation::Popups::AcceptPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub wait_accept_popup {
    my ($self, $args) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{AcceptPopup}->is_shown({timeout => 0});
    }, %$args);
}

sub get_accept_popup {
    my ($self) = @_;
    die 'Accept Popup is not displayed' unless $self->{AcceptPopup}->is_shown();
    return $self->{AcceptPopup};
}

sub accept {
    my ($self) = @_;
    $self->get_accept_popup()->press_accept();
}

1;
