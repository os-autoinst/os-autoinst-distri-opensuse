# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Role Page of Expert
# Partitioner Wizard, that are common for all the versions of the page
# (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::RolePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ROLE_PAGE => 'partition-role'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        raw_volume_shortcut => $args->{raw_volume_shortcut}
    }, $class;
}

sub select_role_radiobutton {
    my ($self, $role) = @_;
    assert_screen(ROLE_PAGE);
    if ($role eq 'raw-volume') {
        send_key($self->{raw_volume_shortcut});
    }
    if ($role eq 'operating-system') {
        send_key('alt-o');
    }
    if ($role eq 'swap') {
        send_key('alt-s');
    }
    if ($role eq 'data') {
        send_key('alt-d');
    }
    if ($role eq 'efi') {
        send_key('alt-e');
    }
}

sub press_next {
    my ($self) = @_;
    assert_screen(ROLE_PAGE);
    $self->SUPER::press_next(ROLE_PAGE);
}

1;
