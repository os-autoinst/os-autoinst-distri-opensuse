# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for YaST Firstboot
# NTP Configuration page
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::NTPConfigurationPage;
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
    $self->{rb_only_manually} = $self->{app}->radiobutton({id => '"never"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rb_only_manually}->exist();
}

1;
