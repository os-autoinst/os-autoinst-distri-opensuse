# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Release Notes Dialog
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::ReleaseNotesPage;
use parent 'Yam::PageBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->{cmb_language} = $self->{app}->combobox({id => 'lang'});
    $self->{btn_help} = $self->{app}->button({id => 'help'});
    $self->{btn_close} = $self->{app}->button({id => 'next'});
    return $self;
}

sub get_release_notes_page {
    my ($self) = @_;
    die 'Release notes dialog is not displayed' unless $self->{cmb_language}->exist();
    return $self;
}

sub close {
    my ($self) = @_;
    $self->get_release_notes_page();
    $self->{btn_close}->click();
}

1;
