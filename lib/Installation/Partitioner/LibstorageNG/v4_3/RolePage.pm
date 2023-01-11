# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles role selection for partitions/logical volumes
# using Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::RolePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

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
    $self->{rdb_operating_system} = $self->{app}->radiobutton({id => 'system'});
    $self->{rdb_data_isv_apps} = $self->{app}->radiobutton({id => 'data'});
    $self->{rdb_swap} = $self->{app}->radiobutton({id => 'swap'});
    $self->{rdb_efi_boot_part} = $self->{app}->radiobutton({id => 'efi_boot'});
    $self->{rdb_raw_volume} = $self->{app}->radiobutton({id => 'raw'});
    return $self;
}

sub set_role {
    my ($self, $role) = @_;
    $self->select_role($role) if $role;
    $self->press_next();
}

sub select_role {
    my ($self, $role) = @_;
    my %rb_roles = (
        'operating-system' => $self->{rdb_operating_system},
        data => $self->{rdb_data_isv_apps},
        swap => $self->{rdb_swap},
        'efi-boot' => $self->{rdb_efi_boot_part},
        'raw-volume' => $self->{rdb_raw_volume}
    );
    return $rb_roles{$role}->select() if $rb_roles{$role};
    die "Wrong test data provided when selecting role.\n" .
      "Avalaible options: operating-system, data, swap, efi-boot, raw-volume";
}

1;
