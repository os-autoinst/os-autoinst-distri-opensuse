# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST migration module.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Migration::MigrationController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Migration::MigrationTargetPage;


sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{MigrationTargetPage} = YaST::Migration::MigrationTargetPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_migration_target_page {
    my ($self) = @_;
    die 'Migration target selection is not shown' unless $self->{MigrationTargetPage}->is_shown();
    return $self->{BootCodeOptionsPage};
}

sub migration_target {
    my ($self, $args) = @_;
    $self->{MigrationTargetPage}->select_migration_target($args);
    $self->{MigrationTargetPage}->press_next();
}

1;
