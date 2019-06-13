# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Role Page of Expert
# Partitioner Wizard, that are common for all the versions of the page
# (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
}

sub press_next {
    my ($self) = @_;
    assert_screen(ROLE_PAGE);
    $self->SUPER::press_next(ROLE_PAGE);
}

1;
