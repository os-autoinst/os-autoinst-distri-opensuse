# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for New Partition Size
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::NewPartitionSizePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    NEW_PARTITION_SIZE_PAGE => 'partition-size'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        custom_size_shortcut => $args->{custom_size_shortcut}
    }, $class;
}

sub enter_size {
    my ($self, $size) = @_;
    assert_screen(NEW_PARTITION_SIZE_PAGE);
    send_key('alt-s');
    type_string($size);
}

sub select_custom_size_radiobutton {
    my ($self) = @_;
    assert_screen(NEW_PARTITION_SIZE_PAGE);
    send_key($self->{custom_size_shortcut});
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(NEW_PARTITION_SIZE_PAGE);
}

1;
