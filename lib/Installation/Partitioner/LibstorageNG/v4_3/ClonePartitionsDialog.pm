# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods to operate clone partitioning dialog
# of an expert partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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

    $self->{btn_ok}           = $self->{app}->button({id => 'ok'});
    $self->{lst_target_disks} = $self->{app}->selectionbox({
            id => '"Y2Partitioner::Dialogs::PartitionTableClone::DevicesSelector"'
    });

    return $self;
}

sub select_all_disks {
    my ($self) = @_;

    my @disks = $self->{lst_target_disks}->items();
    #Select all disks
    foreach (@disks) {
        $self->{lst_target_disks}->select($_);
    }
    return $self;
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

1;
