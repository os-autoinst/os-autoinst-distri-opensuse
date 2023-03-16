# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Restart Info Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::RestartInfoPage;
use parent 'YaST::PageBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->{btn_ok} = $self->{app}->button({id => 'ok_msg'});
    return $self;
}

sub get_restart_info_page {
    my ($self) = @_;
    die 'Restart Info Page is not displayed' unless $self->{btn_ok}->exist();
    return $self;
}

sub confirm_reboot_needed {
    my ($self) = @_;
    $self->get_restart_info_page()->{btn_ok}->click();
}

sub wait_restart_info_popup {
    my ($self) = @_;

    YuiRestClient::Wait::wait_until(object => sub {
            $self->{btn_ok}->exist({timeout => 0});
    }, timeout => 180, message => "btn_ok does not exist");
}

1;
