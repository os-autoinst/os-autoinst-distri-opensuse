# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for
# YaST Firstboot Finish Setup Configuration.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::ConfigurationCompletedPage;
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
    $self->{btn_next}        = $self->{app}->button({id => 'next'});
    $self->{rt_finish_setup} = $self->{app}->richtext({type => 'YRichText'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rt_finish_setup}->exist();
}

sub get_text {
    my ($self) = @_;
    return $self->{rt_finish_setup}->text();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
