# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Module Selection page
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleSelection::ModuleSelectionPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{slb_addons} = $self->{app}->selectionbox({id => 'addon_repos'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{slb_addons}->exist();
}

sub get_modules {
    my ($self) = @_;
    return $self->{slb_addons}->items();
}

sub get_selected_modules {
    my ($self) = @_;
    return $self->{slb_addons}->selected_items();
}

sub select_module {
    my ($self, $module) = @_;
    my @modules = $self->get_modules();
    my ($module_full_name) = grep(/$module/i, @modules);
    return $self->{slb_addons}->check($module_full_name);
}

sub select_modules {
    my ($self, $modules) = @_;
    $self->select_module($_) for ($modules->@*);
    return $self;
}

1;
