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
    $self->{$rb_name}->exist();
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{$rb_name}->select();
            $self->{$rb_name}->is_selected();
    });
}

sub select_available_device {
    my ($self, $device) = @_;
    return $self->{tbl_available_devices}->select(value => "/dev/$device");
}

sub get_added_devices {
    my ($self) = @_;
    return $self->{tbl_selected_devices}->items();
}

sub is_device_added {
    my ($self, $device) = @_;
    my @added_devices = $self->get_added_devices();
    my $device_clmn   = $self->{tbl_selected_devices}->get_index('Device');
    return (grep { $_->[$device_clmn] eq "/dev/$device" } @added_devices);
}

sub add_device {
    my ($self, $device) = @_;
    $self->{tbl_available_devices}->exist();
    YuiRestClient::Wait::wait_until(object => sub {
            $self->select_available_device($device);
            $self->press_add_button();
            # Verify that entry was added
            return $self->is_device_added($device);
    });
}

1;
