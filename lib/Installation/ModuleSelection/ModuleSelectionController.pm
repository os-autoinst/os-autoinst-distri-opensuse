# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Module Selection dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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

sub register_module {
    my ($self, $module) = @_;
    $self->get_module_selection_page()->select_module($module);
    $self->get_module_selection_page()->press_next();
}

sub register_modules {
    my ($self, $modules) = @_;
    $self->get_module_selection_page()->select_modules($modules);
    $self->get_module_selection_page()->press_next();
}

sub skip_selection {
    my ($self) = @_;
    $self->get_module_selection_page()->press_next();
}

sub view_development_versions {
    my ($self) = @_;
    $self->get_module_selection_page()->uncheck_hide_development_versions();
}

1;
