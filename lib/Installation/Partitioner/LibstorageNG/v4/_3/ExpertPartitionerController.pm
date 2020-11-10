# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Libstorage-NG (ver.4.3+)
# Expert Partitioner.
# Libstorage-NG ver.4.3 introduces reworked UI which heavily relies on new
# menu widget bar
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4::_3::ExpertPartitionerController;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController';
use Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage;
use Installation::Partitioner::LibstorageNG::v4::_3::ExpertPartitionerPage;
use Installation::Partitioner::NewPartitionSizePage;
use Installation::Partitioner::RolePage;
use Installation::Partitioner::LibstorageNG::FormattingOptionsPage;
use Installation::Partitioner::RaidTypePage;
use Installation::Partitioner::RaidOptionsPage;
use Installation::Partitioner::LibstorageNG::EncryptionPasswordPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage->new(),
        ExpertPartitionerPage     => Installation::Partitioner::LibstorageNG::v4::_3::ExpertPartitionerPage->new({app => YuiRestClient::get_app()}),
        NewPartitionSizePage      => Installation::Partitioner::NewPartitionSizePage->new({
                custom_size_shortcut => 'alt-o'
        }),
        EditPartitionSizePage => Installation::Partitioner::NewPartitionSizePage->new({
                custom_size_shortcut => 'alt-u'
        }),
        RolePage => Installation::Partitioner::RolePage->new({
                raw_volume_shortcut => 'alt-r'
        }),
        FormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({
                do_not_format_shortcut => 'alt-t',
                format_shortcut        => 'alt-r',
                filesystem_shortcut    => 'alt-f',
                do_not_mount_shortcut  => 'alt-u'
        }),
        EditFormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({
                do_not_format_shortcut  => 'alt-t',
                format_shortcut         => 'alt-a',
                filesystem_shortcut     => 'alt-f',
                do_not_mount_shortcut   => 'alt-o',
                encrypt_device_shortcut => 'alt-e'
        }),
        RaidTypePage    => Installation::Partitioner::RaidTypePage->new(),
        RaidOptionsPage => Installation::Partitioner::RaidOptionsPage->new({
                chunk_size_shortcut => 'alt-u'
        }),
        EncryptionPasswordPage => Installation::Partitioner::LibstorageNG::EncryptionPasswordPage->new({
                enter_password_shortcut  => 'alt-e',
                verify_password_shortcut => 'alt-v'
        })
    }, $class;

}

sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

1;
