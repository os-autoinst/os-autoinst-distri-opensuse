# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for RAID Options Page of
# Expert Partitioner Wizard, that are common for all the versions of the page
# (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::RaidOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    RAID_OPTIONS_PAGE => 'partitioning_raid-add_raid-chunk_size'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        chunk_size_shortcut => $args->{chunk_size_shortcut}
    }, $class;
}

sub select_chunk_size {
    my ($self, $chunk_size) = @_;
    assert_screen(RAID_OPTIONS_PAGE);
    send_key($self->{chunk_size_shortcut});
    type_string($chunk_size);
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(RAID_OPTIONS_PAGE);
}

1;
