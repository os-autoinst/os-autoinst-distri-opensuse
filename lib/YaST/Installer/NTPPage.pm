# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

package YaST::Firstboot::NTPPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{radiobutton_sync} = $self->{app}->radiobutton({id => 'sync'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{radiobutton_sync}->exist();
    save_screenshot;
}

1;
