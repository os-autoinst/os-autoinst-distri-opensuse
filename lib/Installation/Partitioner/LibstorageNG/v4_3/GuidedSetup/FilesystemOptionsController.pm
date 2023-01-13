# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces business actions for Filesystem Options page
#          in Guided Partitioning using YuiRestClient.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsController;
use strict;
use warnings;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsPage;
use YuiRestClient;

=head1 FILESYSTEM_OPTIONS

=head2 SYNOPSIS

The class introduces business actions for Filesystem Options Screen of Guided Setup with libstorage-ng
using REST API.

=cut

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{FilesystemOptionsPage} = Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_filesystem_options_page {
    my ($self) = @_;
    die "Filesystem Options is not displayed" unless $self->{FilesystemOptionsPage}->is_shown();
    return $self->{FilesystemOptionsPage};
}

sub do_not_propose_separate_home {
    my ($self) = @_;
    $self->get_filesystem_options_page()->unselect_propose_separate_home();
}

sub select_root_filesystem_type {
    my ($self, $fs_type) = @_;
    $self->get_filesystem_options_page()->select_root_filesystem($fs_type);
}

sub go_forward {
    my ($self, $args) = @_;
    $self->get_filesystem_options_page()->press_next();
}

1;
