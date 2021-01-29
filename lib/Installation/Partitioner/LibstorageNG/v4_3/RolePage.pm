# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles role selection for partitions/logical volumes
# using Expert Partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::RolePage;
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
    $self->{rb_operating_system} = $self->{app}->radiobutton({id => 'system'});
    $self->{rb_data_isv_apps}    = $self->{app}->radiobutton({id => 'data'});
    $self->{rb_swap}             = $self->{app}->radiobutton({id => 'swap'});
    $self->{rb_efi_boot_part}    = $self->{app}->radiobutton({id => 'efi_boot'});
    $self->{rb_raw_volume}       = $self->{app}->radiobutton({id => 'raw'});
    $self->{btn_next}            = $self->{app}->button({id => 'next'});
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
        'operating-system' => $self->{rb_operating_system},
        data               => $self->{rb_data_isv_apps},
        swap               => $self->{rb_swap},
        'efi-boot'         => $self->{rb_efi_boot_part},
        'raw-volume'       => $self->{rb_raw_volume}
    );
    return $rb_roles{$role}->select() if $rb_roles{$role};
    die "Wrong test data provided when selecting role.\n" .
      "Avalaible options: operating-system, data, swap, efi-boot, raw-volume";
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
