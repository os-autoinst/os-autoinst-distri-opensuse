# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST Firstboot Welcome Configuration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::WelcomeController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::WelcomePage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{WelcomePage} = YaST::Firstboot::WelcomePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_welcome_page {
    my ($self) = @_;
    die "Welcome page is not shown" unless $self->{WelcomePage}->is_shown();
    return $self->{WelcomePage};
}

sub collect_current_welcome_info {
    my ($self) = @_;
    return $self->get_welcome_page()->get_welcome_text();
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_welcome_page()->press_next();
}

1;
