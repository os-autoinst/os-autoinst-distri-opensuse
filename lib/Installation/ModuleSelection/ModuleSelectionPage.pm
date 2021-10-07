# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act with Module Selection page
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
    $self->{ch_hide_dev_versions}  = $self->{app}->checkbox({id => 'filter_devel'});
    $self->{rt_items}              = $self->{app}->richtext({id => 'items'});
    $self->{rt_item_containers}    = 'sle-module-containers';
    $self->{rt_item_desktop}       = 'sle-module-desktop-applications';
    $self->{rt_item_development}   = 'sle-module-development-tools';
    $self->{rt_item_legacy}        = 'sle-module-legacy';
    $self->{rt_item_transactional} = 'sle-module-transactional-server';
    $self->{rt_item_web}           = 'sle-module-web-scripting';
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rt_items}->exist();
}

sub get_modules {
    my ($self) = @_;
    my @modules = ($self->{rt_items}->text() =~ /<a href='(.*?)'.*<\/a>/g);
    return \@modules;
}

sub get_selected_modules {
    my ($self) = @_;
    my @modules = ($self->{rt_items}->text() =~ /<a href='(.*?)'.*inst_checkbox-on.*<\/a>/g);
    return \@modules;
}

sub select_module {
    my ($self, $module) = @_;
    my $module_name = $self->{"rt_item_$module"};
    my ($module_full_name) = grep { /$module_name/ } $self->get_modules()->@*;
    return $self->{rt_items}->activate_link($module_full_name);
}

sub select_modules {
    my ($self, $modules) = @_;
    $self->select_module($_) for ($modules->@*);
    return $self;
}

sub uncheck_hide_development_versions {
    my ($self) = @_;
    return $self->{ch_hide_dev_versions}->uncheck();
}

1;
