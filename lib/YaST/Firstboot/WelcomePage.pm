# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Welcome dialog
# in YaST Firstboot Configuration.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::WelcomePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{rt_welcome} = $self->{app}->richtext({id => 'welcome_text'});
    return $self;
}

sub get_welcome_text {
    my ($self) = @_;
    return $self->{rt_welcome}->text();
}

sub is_shown {
    my ($self) = @_;
    return $self->{rt_welcome}->exist();
}

1;
