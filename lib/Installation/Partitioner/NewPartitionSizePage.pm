# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for New Partition Size
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
