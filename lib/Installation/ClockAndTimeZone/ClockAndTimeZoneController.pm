# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Clock and Time Zone
#          dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ClockAndTimeZone::ClockAndTimeZoneController;
use strict;
use warnings;
use Installation::ClockAndTimeZone::ClockAndTimeZonePage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ClockAndTimeZonePage} = Installation::ClockAndTimeZone::ClockAndTimeZonePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_clock_and_time_zone_page {
    my ($self) = @_;
    die "Clock and Time Zone page is not displayed" unless $self->{ClockAndTimeZonePage}->is_shown();
    return $self->{ClockAndTimeZonePage};
}

sub collect_current_clock_and_time_zone_info {
    my ($self) = @_;
    return {
        region              => $self->get_clock_and_time_zone_page()->get_region(),
        time_zone           => $self->get_clock_and_time_zone_page()->get_time_zone(),
        hw_clock_set_to_UTC => $self->get_clock_and_time_zone_page()->is_hw_clock_set_to_UTC()};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_clock_and_time_zone_page()->press_next();
}

1;
