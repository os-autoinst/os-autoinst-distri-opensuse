# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Selection dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleSelection::ModuleSelectionController;
use strict;
use warnings;
use Installation::ModuleSelection::ModuleSelectionPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ModuleSelectionPage} = Installation::ModuleSelection::ModuleSelectionPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_module_selection_page {
    my ($self) = @_;
    die "Extension and Module Selection page is not displayed" unless $self->{ModuleSelectionPage}->is_shown();
    return $self->{ModuleSelectionPage};
}

sub select_module {
    my ($self, $module) = @_;
    $self->get_module_selection_page()->select_module($module);
    $self->get_module_selection_page()->press_next();
}

sub select_modules {
    my ($self, $modules) = @_;
    $self->get_module_selection_page()->select_modules($modules);
    $self->get_module_selection_page()->press_next();
}

sub skip_selection {
    my ($self) = @_;
    $self->get_module_selection_page()->press_next();
}

1;
