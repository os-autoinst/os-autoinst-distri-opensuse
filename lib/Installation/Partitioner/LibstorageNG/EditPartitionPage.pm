# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: The class introduces all accessing methods for Edit Partition
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::EditPartitionPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    EDIT_PARTITION_PAGE => 'edit-partition'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        encrypt_checkbox => $args->{encrypt_checkbox}
    }, $class;
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(EDIT_PARTITION_PAGE);
}

sub select_enable_disk_encryption_checkbox {
    my ($self) = shift;
    assert_screen(EDIT_PARTITION_PAGE);
    send_key($self->{encrypt_checkbox});
}

1;
