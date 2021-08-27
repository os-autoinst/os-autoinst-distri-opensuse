# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for YaST Firstboot Configuration Completed
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::ConfigurationCompletedController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::ConfigurationCompletedPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ConfigurationCompletedPage} = YaST::Firstboot::ConfigurationCompletedPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_configuration_completed_page {
    my ($self) = @_;
    die "Configuration Completed page is not shown" unless $self->{ConfigurationCompletedPage}->is_shown();
    return $self->{ConfigurationCompletedPage};
}

sub collect_current_configuration_completed_info {
    my ($self) = @_;
    return {text => $self->get_configuration_completed_page()->get_text()};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_configuration_completed_page()->press_next();
}

1;
