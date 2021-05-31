# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles Clock and Time Zone page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ClockAndTimeZone::ClockAndTimeZonePage;
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
    $self->{btn_next}     = $self->{app}->button({id => 'next'});
    $self->{cb_region}    = $self->{app}->combobox({id => 'region'});
    $self->{cb_time_zone} = $self->{app}->combobox({id => 'timezone'});
    $self->{chb_hw_clock} = $self->{app}->checkbox({id => 'hwclock'});
    return $self;
}

sub get_region {
    my ($self) = @_;
    return $self->{cb_region}->value();
}

sub get_time_zone {
    my ($self) = @_;
    return $self->{cb_time_zone}->value();
}

sub is_hw_clock_set_to_UTC {
    my ($self) = @_;
    return $self->{chb_hw_clock}->is_checked();
}

sub is_shown {
    my ($self) = @_;
    return $self->{cb_time_zone}->exist();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
