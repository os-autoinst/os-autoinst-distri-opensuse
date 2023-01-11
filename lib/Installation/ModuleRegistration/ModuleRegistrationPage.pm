# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Module Registration page
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleRegistration::ModuleRegistrationPage;
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
    $self->{chb_hide_dev_versions} = $self->{app}->checkbox({id => 'filter_devel'});
    $self->{rct_items} = $self->{app}->richtext({id => 'items'});
    $self->{rct_item_we} = 'sle-we';
    $self->{rct_item_ha} = 'sle-ha';
    $self->{rct_item_base} = 'sle-module-basesystem';
    $self->{rct_item_contm} = 'sle-module-containers';
    $self->{rct_item_desktop} = 'sle-module-desktop-applications';
    $self->{rct_item_sdk} = 'sle-module-development-tools';
    $self->{rct_item_legacy} = 'sle-module-legacy';
    $self->{rct_item_tsm} = 'sle-module-transactional-server';
    $self->{rct_item_script} = 'sle-module-web-scripting';
    $self->{rct_item_python2} = 'sle-module-python2';
    $self->{rct_item_python3} = 'sle-module-python3';
    $self->{rct_item_pcm} = 'sle-module-public-cloud';
    $self->{rct_item_serverapp} = 'sle-module-server-applications';
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rct_items}->exist();
}

sub get_modules_full_name {
    my ($self) = @_;
    my @modules = ($self->{rct_items}->text() =~ /<a href="(.*?)">|<a href='(.*?)' /g);
    @modules = grep defined, @modules;
    return \@modules;
}

sub get_modules {
    my ($self) = @_;
    my @modules = ($self->{rct_items}->text() =~ /<a href='?"?(.*?)-\d+/g);
    return \@modules;
}

sub get_registered_modules {
    my ($self) = @_;
    my @modules = ($self->{rct_items}->text() =~ /<a href='(.*?)-\d+.*inst_checkbox-on|<a href="(.*?)-\d+.*\[x\]/g);
    @modules = grep defined, @modules;
    return \@modules;
}

sub register_module {
    my ($self, $module) = @_;
    my $module_name = $self->{"rct_item_$module"};
    my ($module_full_name) = grep { /$module_name/ } $self->get_modules_full_name()->@*;
    return $self->{rct_items}->activate_link($module_full_name);
}

sub register_extension_and_modules {
    my ($self, $modules) = @_;
    $self->register_module($_) for ($modules->@*);
    return $self;
}

sub uncheck_hide_development_versions {
    my ($self) = @_;
    return $self->{chb_hide_dev_versions}->uncheck();
}

1;
