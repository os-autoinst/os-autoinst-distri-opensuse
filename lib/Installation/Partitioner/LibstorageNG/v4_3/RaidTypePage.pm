# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page to setup RAID level and select devices in the Expert Partitioner
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::RaidTypePage;
use parent 'Installation::Navigation::NavigationBase';
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
    $self->SUPER::init();
    $self->{btn_add} = $self->{app}->button({id => 'add'});
    $self->{btn_add_all} = $self->{app}->button({id => 'add_all'});

    $self->{rdb_raid0} = $self->{app}->radiobutton({id => 'raid0'});
    $self->{rdb_raid1} = $self->{app}->radiobutton({id => 'raid1'});
    $self->{rdb_raid5} = $self->{app}->radiobutton({id => 'raid5'});
    $self->{rdb_raid6} = $self->{app}->radiobutton({id => 'raid6'});
    $self->{rdb_raid10} = $self->{app}->radiobutton({id => 'raid10'});

    $self->{tbl_available_devices} = $self->{app}->table({id => '"unselected"'});
    $self->{tbl_selected_devices} = $self->{app}->table({id => '"selected"'});

    $self->{txb_raid_name} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::Md::NameEntry"'});

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

sub set_raid_level {
    my ($self, $raid_level) = @_;

    my $rdb_name = "rdb_raid$raid_level";

    die "No control defined for raid level: $raid_level" unless $self->{$rdb_name};
    $self->{$rdb_name}->exist();
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{$rdb_name}->select();
            $self->{$rdb_name}->is_selected();
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

=head2 bidi_strip

  bidi_strip("\x{2066}/\x{2068}dev\x{2069}/\x{2068}sdb1\x{2069}\x{2069}");
  # -> "/dev/sdb1"

Remove BiDirectional Text formatting characters from a string.

In Right-to-left languages such as Arabic and Hebrew, /dev/sda1 looked like
dev/sda1/ so we fixed it in YaST by adding BiDi control characters.
https://en.wikipedia.org/wiki/Bidirectional_text#Explicit_formatting

But if you look for "/dev/sda1" in partitioner tables, it is no longer there
unless you apply bidi_strip first.

=cut

sub bidi_strip {
    my ($self, $string) = @_;

    return $string =~ tr/\x{202A}\x{202B}\x{202C}\x{202D}\x{202E}\x{2066}\x{2067}\x{2068}\x{2069}//rd;
}

sub is_device_added {
    my ($self, $device) = @_;
    my @added_devices = $self->get_added_devices();
    my $device_clmn = $self->{tbl_selected_devices}->get_index('Device');
    return (grep { $self->bidi_strip($_->[$device_clmn]) eq "/dev/$device" } @added_devices);
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
