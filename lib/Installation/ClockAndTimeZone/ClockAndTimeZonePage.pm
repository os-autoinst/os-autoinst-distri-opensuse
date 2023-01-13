# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Clock and Time Zone page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
    $self->{cmb_region} = $self->{app}->combobox({id => 'region'});
    $self->{cmb_time_zone} = $self->{app}->combobox({id => 'timezone'});
    $self->{chb_hw_clock} = $self->{app}->checkbox({id => 'hwclock'});
    return $self;
}

sub get_region {
    my ($self) = @_;
    return $self->{cmb_region}->value();
}

sub get_time_zone {
    my ($self) = @_;
    return $self->{cmb_time_zone}->value();
}

sub is_hw_clock_set_to_UTC {
    my ($self) = @_;
    return $self->{chb_hw_clock}->is_checked();
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_time_zone}->exist();
}

1;
