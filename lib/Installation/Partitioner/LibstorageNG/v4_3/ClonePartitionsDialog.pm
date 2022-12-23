# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to operate clone partitioning dialog
# of an expert partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::ClonePartitionsDialog;
use strict;
use warnings;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;

    return $self->init();
}

sub init {
    my $self = shift;

    $self->{btn_ok} = $self->{app}->button({id => 'ok'});
    $self->{lst_target_disks} = $self->{app}->selectionbox({
            id => '"Y2Partitioner::Dialogs::PartitionTableClone::DevicesSelector"'
    });

    return $self;
}

sub select_disks {
    my ($self, @disks) = @_;

    my @available = $self->{lst_target_disks}->items();

    foreach my $disk (@disks) {
        # Find list item which matches wanted disk
        if (my ($lst_item) = grep $_ =~ $disk, @available) {
            $self->{lst_target_disks}->check($lst_item);
        }
        else {
            die "$disk cannot be found in the list of target disks";
        }
    }
    return $self;
}

sub select_all_disks {
    my ($self) = @_;

    my @disks = $self->{lst_target_disks}->items();
    #Select all disks
    foreach my $disk (@disks) {
        $self->{lst_target_disks}->check($disk);
    }
    return $self;
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

1;
