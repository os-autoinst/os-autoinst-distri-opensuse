# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Introduces business actions for Navigation on installation
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Navigation::NavigationController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Navigation::NavigationBase;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{NavigationBase} = Installation::Navigation::NavigationBase->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_navigation_base {
    my ($self) = @_;
    return $self->{NavigationBase};
}

sub proceed_next_screen {
    my ($self) = @_;
    $self->get_navigation_base()->press_next();
}

1;
