# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary:
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::FirstbootController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::GenericClient;
use YaST::Firstboot::WelcomeClient;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{GenericClient} = YaST::Firstboot::GenericClient->new({app => YuiRestClient::get_app()});
    $self->{WelcomeClient} = YaST::Firstboot::WelcomeClient->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_generic_client {
    my ($self) = @_;
    return $self->{GenericClient};
}

sub get_welcome_client {
    my ($self) = @_;
    return $self->{WelcomeClient};
}


sub generic_smoketest {
    my ($self, $args) = @_;
    # die "Failed at $args->{client}" unless $self->{GenericClient}->assert_client({debug_label => $args->{client}});
    $self->get_generic_client()->assert_client($args);
    save_screenshot;
    $self->{GenericClient}->press_next();
}

sub welcome_smoketest {
    my ($self, $args) = @_;
    # $self->{WelcomeClient}->assert_client();
    die "Failed at $args->{client}" unless $self->get_welcome_client()->assert_client();
    save_screenshot;
    $self->{GenericClient}->press_next();
}

1;
