# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for YaST Firstboot Welcome Configuration
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
