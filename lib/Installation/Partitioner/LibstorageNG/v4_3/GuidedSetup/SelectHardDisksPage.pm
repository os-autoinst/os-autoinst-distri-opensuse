# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Select Hard Disk(s)
#          Page in Guided Setup in case multiple disks are available in the system.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = shift;
    $self->SUPER::init();
    $self->{lbl_select_disks_to_use} = $self->{app}->label({label => 'Select one or more (max 3) hard disks'});
    $self->{lbl_wizard} = $self->{app}->label({id => 'wizard'});
    return $self;
}

sub _get_disk_checkbox {
    my ($self, $disk) = @_;
    return $self->{app}->checkbox({id => "\"/dev/$disk\""});
}

sub is_shown {
    my ($self) = @_;
    my $result;
    eval {
        $result = YuiRestClient::Wait::wait_until(object => sub {
                return $self->{lbl_wizard}->property('debug_label') eq 'Select Hard Disk(s)';
        });
    };
    $result ? 1 : 0;
}

sub select_hard_disks {
    my ($self, $disks) = @_;
    foreach my $disk ($disks) {
        $self->_get_disk_checkbox($disk)->check();
    }
}

1;
