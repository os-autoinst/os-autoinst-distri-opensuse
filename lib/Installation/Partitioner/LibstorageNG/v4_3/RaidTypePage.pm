# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handle page to setup RAID level and select devices in the Expert Partitioner
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::RaidTypePage;
use strict;
use warnings;
use testapi;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my $self = shift;
    $self->{btn_next}    = $self->{app}->button({id => 'next'});
    $self->{btn_add}     = $self->{app}->button({id => 'add'});
    $self->{btn_add_all} = $self->{app}->button({id => 'add_all'});

    $self->{rb_raid0}  = $self->{app}->radiobutton({id => 'raid0'});
    $self->{rb_raid1}  = $self->{app}->radiobutton({id => 'raid1'});
    $self->{rb_raid5}  = $self->{app}->radiobutton({id => 'raid5'});
    $self->{rb_raid6}  = $self->{app}->radiobutton({id => 'raid6'});
    $self->{rb_raid10} = $self->{app}->radiobutton({id => 'raid10'});

    $self->{tbl_available_devices} = $self->{app}->table({id => '"unselected"'});
    $self->{tbl_selected_devices}  = $self->{app}->table({id => '"selected"'});

    $self->{txtbox_raid_name} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::Md::NameEntry"'});

    return $self;
}


sub press_add_button {
    my ($self) = @_;
    return $self->{btn_add}->click();
}

sub press_add_all_button {
    my ($self) = @_;
    return $self->{btn_add_all}->click();
}

sub press_next {
    my ($self) = @_;
    $self->{btn_next}->click();
}

sub set_raid_level {
    my ($self, $raid_level) = @_;

    my $rb_name = "rb_raid$raid_level";

    die "No control defined for raid level: $raid_level" unless $self->{$rb_name};
    $self->{$rb_name}->select();
}

sub select_available_device {
    my ($self, $args) = @_;
    return $self->{tbl_available_devices}->select(value => $args->{device});
}

sub select_devices_from_list {
    my ($self, $step) = @_;

    for (my $row = 0; $row < $step * 3; $row += $step) {
        $self->{tbl_available_devices}->select(row => $row);
    }

    $self->press_add_button();
}

1;
