# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page that allows to select system/partition to be upgraded.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::PreviouslyUsedReposPage;
use parent 'Yam::PageBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    $self->{tbl_previously_used_repos} = $self->{app}->table({id => "\"table_of_repos\""});
    return $self;
}

sub _get_previously_used_repos {
    my ($self) = @_;
    die "Previous repositories page not shown" unless $self->{tbl_previously_used_repos}->exist();
    return $self;
}

sub next {
    my ($self) = @_;
    $self->_get_previously_used_repos()->{btn_next}->click();
}

1;
