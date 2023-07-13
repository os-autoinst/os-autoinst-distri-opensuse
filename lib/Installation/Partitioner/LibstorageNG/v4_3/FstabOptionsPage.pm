# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page for fstab options when adding
# or editing a partition using Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::FstabOptionsPage;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4_3::FormatMountOptionsPage';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my $self = shift;
    $self->{btn_fstab_options} = $self->{app}->button({id => '"Y2Partitioner::Widgets::FstabOptionsButton"'});
    $self->{cmb_mount_by} = $self->{app}->combobox({id => '"Y2Partitioner::Widgets::MountBy"'});
    $self->{btn_ok} = $self->{app}->button({id => 'ok'});
    return $self;
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

sub edit_fstab_options {
    my ($self, $args) = @_;
    $self->press_fstab_options();
    $self->edit_fstab_mount_by($args);
    $self->press_ok();
}

sub edit_fstab_mount_by {
    my ($self, $args) = @_;
    my $default = "UUID";
    my @acceptable_options = ("Device ID", "Device Name", "Device Path", "UUID", "Volume Label");
    die "The mounting option, $args->{mount_by} doesn't belong in the acceptable values :"
      . join(", ", @acceptable_options) unless (grep(/^$args->{mount_by}$/, @acceptable_options));
    $self->check_default_mount_option($default);
    $self->set_mount_by($args->{mount_by}) unless ($default eq $args->{mount_by});
}

sub press_fstab_options {
    my ($self) = @_;
    return $self->{btn_fstab_options}->click();
}

sub set_mount_by {
    my ($self, $mount_by) = @_;
    return $self->{cmb_mount_by}->select($mount_by);
}

sub check_default_mount_option {
    my ($self, $default) = @_;
    my $preselected = $self->{cmb_mount_by}->value();
    die "The default mounting option was expected to be $default, but is $preselected" if ($preselected ne $default);
}

1;
