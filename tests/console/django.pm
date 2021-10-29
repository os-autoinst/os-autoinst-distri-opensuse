# SUSE's Django regression test
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-Django
# Summary: Test basic python3-Django
# Maintainer: qe-core@suse.de

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils;
use registration;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    add_suseconnect_product("PackageHub", undef, undef, undef, 300, 1) if is_sle;
    add_suseconnect_product("sle-module-desktop-applications", undef, undef, undef, 300, 1) if is_sle;

    zypper_call "in python3-Django";

    assert_script_run 'mkdir my_django_project';
    assert_script_run 'cd my_django_project';

    assert_script_run 'django-admin startproject config .';
    assert_script_run 'python3 manage.py runserver & sleep 10';
    assert_script_run 'curl -s http://localhost:8000/ | grep "The install worked successfully"';
    assert_script_run 'kill $!';
    assert_script_run 'cd -';
}

1;

