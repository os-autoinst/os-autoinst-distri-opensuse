# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Boot Code Options tab
# in Boot Loader Settings.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Migration::MigrationTargetPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;
use testapi 'save_screenshot';

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{lst_migration_target} = $self->{app}->selectionbox({id => 'migration_targets'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{lst_migration_target}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub select_migration_target {
    my ($self, $args) = @_;
    $self->{lst_migration_target}->select($args->{target});
}

1;
