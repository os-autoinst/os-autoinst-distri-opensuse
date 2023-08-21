# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the
#          ntp Configuration page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::NTPConfiguration::NTPConfigurationPage;
use parent 'Yam::PageBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->{txb_ntp_server} = $self->{app}->textbox({id => '"Y2Caasp::Widgets::NtpServer"'});
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{txb_ntp_server}->exist({timeout => 200});
}

sub get_ntp_servers {
    my ($self) = @_;
    return $self->get_ntp_configuration_page()->{txb_ntp_server}->value();
}

sub get_ntp_configuration_page {
    my ($self) = @_;
    die "Ntp configuration page is not displayed" unless $self->is_shown();
    return $self;
}

sub press_next {
    my ($self) = @_;
    return $self->get_ntp_configuration_page()->{btn_next}->click();
}

1;
