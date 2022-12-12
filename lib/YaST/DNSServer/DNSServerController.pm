# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions for DNS Server Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::DNSServer::DNSServerController;
use strict;
use warnings;
use YaST::DNSServer::StartUpPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{StartUpPage} = YaST::DNSServer::StartUpPage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub process_reading_configuration {
    my ($self) = @_;
    $self->continue_with_interfaces_controlled_by_nm();
    return $self->get_startup_page();
}

sub get_startup_page {
    my ($self) = @_;
    die 'StartUp Page is not displayed' unless $self->{StartUpPage}->is_shown();
    return $self->{StartUpPage};
}

sub continue_with_interfaces_controlled_by_nm {
    my ($self) = @_;
    $self->get_weak_password_warning()->press_yes();
}

sub get_weak_password_warning {
    my ($self) = @_;
    die "Popup for too simple password is not displayed" unless $self->{WeakPasswordPopup}->is_shown();
    return $self->{WeakPasswordPopup};
}

sub accept_apply {
    my ($self) = @_;
    $self->get_startup_page()->press_apply();
}

sub accept_ok {
    my ($self) = @_;
    $self->get_startup_page()->press_ok();
}

sub accept_cancel {
    my ($self) = @_;
    $self->get_startup_page()->press_cancel();
}

sub accept_yes {
    my ($self) = @_;
    $self->get_weak_password_warning()->press_yes();
}

sub select_start_after_writing_configuration {
    my ($self) = @_;
    $self->get_startup_page()->set_action('Start');
}

sub select_stop_after_writing_configuration {
    my ($self) = @_;
    $self->get_startup_page()->set_action('Stop');
}

sub select_start_on_boot_after_reboot {
    my ($self) = @_;
    $self->get_startup_page()->set_autostart('Start on boot');
}

sub select_do_not_start_after_reboot {
    my ($self) = @_;
    $self->get_startup_page()->set_autostart('Do not start');
}

1;
