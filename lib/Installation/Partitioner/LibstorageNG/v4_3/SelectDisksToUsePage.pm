# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Select Hard Disk(s)
# Page in Guided Setup in case multiple disks are available in the system.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::SelectDisksToUsePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings FATAL => 'all';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self) = shift;
    $self->SUPER::init();
    $self->{lbl_select_disks_to_use} = $self->{app}->label({label => 'Select one or more (max 3) hard disks'});
    return $self;
}

sub _get_disk_checkbox {
    my ($self, $disk) = @_;
    return $self->{app}->checkbox({id => "\"/dev/$disk\""});
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_select_disks_to_use}->exist();
}

sub select_hard_disks {
    my ($self, @disks) = @_;
    foreach my $disk (@disks) {
        $self->_get_disk_checkbox($disk)->check();
    }
}

1;
