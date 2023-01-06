# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Registration dialog
# when the system is already registered.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Registration::RegisteredSystemController;
use strict;
use warnings;
use Installation::Registration::RegisteredSystemPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{RegisteredSystemPage} = Installation::Registration::RegisteredSystemPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_registered_system_page {
    my ($self) = @_;
    die "Registration page for the system already registered is not displayed" unless $self->{RegisteredSystemPage}->is_shown();
    return $self->{RegisteredSystemPage};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_registered_system_page()->press_next();
}

1;
