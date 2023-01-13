# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Page to handle partition type (exteded, primary) for msdos partitions
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::MsdosPartitionTypePage;
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
    my $self = shift;
    $self->SUPER::init();
    $self->{rdb_primary} = $self->{app}->radiobutton({id => '"primary"'});
    $self->{rdb_extended} = $self->{app}->radiobutton({id => '"extended"'});
    return $self;
}

sub set_type {
    my ($self, $type) = @_;
    $self->select_type($type) if $type;
    $self->press_next();
}

sub select_type {
    my ($self, $type) = @_;
    my %types = (
        primary => $self->{rdb_primary},
        extended => $self->{rdb_extended}
    );
    return $types{$type}->select();
}

1;
