# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page that allows to select system/partition to be upgraded.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::SelectForUpdatePage;
use parent 'Yam::PageBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    $self->{tbl_select_for_update} = $self->{app}->table({id => "partition"});
    return $self;
}

sub _get_select_for_update {
    my ($self) = @_;
    die "Select update page not displayed" unless $self->{tbl_select_for_update}->exist();
    return $self;
}

sub next {
    my ($self) = @_;
    $self->_get_select_for_update()->{btn_next}->click();
}

1;
