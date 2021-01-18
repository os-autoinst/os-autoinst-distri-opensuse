# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Role Page of Expert
# Partitioner Wizard with Libstorage 4.3. The methods use YuiRestClient to communicate
# with the installer elements.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::RolePage;
use strict;
use warnings;
use testapi;
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
    $self->{rb_system}   = $self->{app}->radiobutton({id => 'system'});
    $self->{rb_data}     = $self->{app}->radiobutton({id => 'data'});
    $self->{rb_swap}     = $self->{app}->radiobutton({id => 'swap'});
    $self->{rb_efi_boot} = $self->{app}->radiobutton({id => 'efi_boot'});
    $self->{rb_raw}      = $self->{app}->radiobutton({id => 'raw'});
    $self->{btn_next}    = $self->{app}->button({id => 'next'});
    return $self;
}

sub select_role_radiobutton {
    my ($self, $role) = @_;
    if ($role eq 'operating-system') {
        $self->{rb_system}->select();
    }
    if ($role eq 'data') {
        $self->{rb_data}->select();
    }
    if ($role eq 'swap') {
        $self->{rb_swap}->select();
    }
    if ($role eq 'efi') {
        $self->{rb_efi_boot}->select();
    }
    if ($role eq 'raw-volume') {
        $self->{rb_raw}->select();
    }
    else {
        die "Unknown role: \"$role\"";
    }
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}
