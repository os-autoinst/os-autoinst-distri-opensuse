# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Registration dialog
# when the system is already registered.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
