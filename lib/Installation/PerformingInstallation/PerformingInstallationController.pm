# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the Performing Installation
#          Page in the installer.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::PerformingInstallation::PerformingInstallationController;
use strict;
use warnings;
use Installation::PerformingInstallation::PerformingInstallationPage;
use Installation::Popups::AbstractOKPopup;
use Installation::Popups::OKPopup;
use Installation::Popups::OKStopPopup;
use YuiRestClient;
use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{PerformingInstallationPage} = Installation::PerformingInstallation::PerformingInstallationPage->new({app => YuiRestClient::get_app()});
    $self->{AbstractOKPopup} = Installation::Popups::AbstractOKPopup->new({app => YuiRestClient::get_app()});
    $self->{OKPopup} = Installation::Popups::OKPopup->new({app => YuiRestClient::get_app()});
    $self->{OKStopPopup} = Installation::Popups::OKStopPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_performing_installation_page {
    my ($self) = @_;
    die 'Performing Installation Page is not displayed' unless $self->{PerformingInstallationPage}->is_shown();
    return $self->{PerformingInstallationPage};
}

sub get_system_reboot_popup {
    my ($self) = @_;
    die 'System reboot popup is not displayed' unless $self->{OKPopup}->is_shown();
    return $self->{OKPopup};
}

sub get_system_reboot_with_timeout_popup {
    my ($self) = @_;
    die 'System reboot with timeout popup is not displayed' unless $self->{OKStopPopup}->is_shown();
    return $self->{OKStopPopup};
}

sub wait_installation_popup {
    my ($self, $args) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{AbstractOKPopup}->is_shown({timeout => 0});
    }, %$args);
}

sub confirm_reboot {
    my ($self) = @_;
    $self->get_system_reboot_popup()->press_ok();
}

sub stop_timeout_system_reboot_now {
    my ($self) = @_;
    $self->get_system_reboot_with_timeout_popup->press_stop();
}

1;
