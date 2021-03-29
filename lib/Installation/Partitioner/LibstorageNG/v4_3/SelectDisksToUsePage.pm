# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Select Hard Disk(s)
# Page in Guided Setup in case multiple disks are available in the system.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::SelectDisksToUsePage;
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
    $self->{btn_next}                = $self->{app}->button({id => 'next'});
    $self->{lbl_select_disks_to_use} = $self->{app}->label({label => 'Select one or more (max 3) hard disks'});
    return $self;
}

sub get_disk_checkbox {
    my ($self, $disk) = @_;
    return $self->{app}->checkbox({id => "\"/dev/$disk\""});
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_select_disks_to_use}->exist();
}

sub press_next {
    my ($self) = @_;
    $self->{btn_next}->click();
}

sub select_hard_disks {
    my ($self, @disks) = @_;
    foreach my $disk (@disks) {
        $self->get_disk_checkbox($disk)->check();
    }
    $self->press_next();
}

1;
