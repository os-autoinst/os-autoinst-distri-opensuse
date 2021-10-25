# SUSE's Flask regression test
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-Flask python3-gevent python3-gunicorn uwsgi uwsgi-python3
# Summary: Test basic flask framework and gunicorn/uwsgi wsgi servers
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

    add_suseconnect_product("sle-module-public-cloud", undef, undef, undef, 300, 1) if is_sle;

    zypper_call "in python3-Flask";

    assert_script_run "cd ~$username/data/";

    record_info 'flask dev';
    assert_script_run './flask_app.py & sleep 10';
    assert_script_run 'curl -s http://localhost:5000/ | grep "Hello World"';
    assert_script_run 'kill $!';

    if (!is_sle('<15-SP1')) {
        zypper_call "in python3-gunicorn python3-gevent";

        record_info 'gunicorn';
        assert_script_run 'gunicorn -b :6000 flask_app:app & sleep 10';
        assert_script_run 'curl -s http://localhost:6000/ | grep "Hello World"';
        assert_script_run 'kill $!';

        record_info 'gunicorn gevent';
        assert_script_run 'gunicorn -b :6000 flask_app:app -k gevent & sleep 10';
        assert_script_run 'curl -s http://localhost:6000/ | grep "Hello World"';
        assert_script_run 'kill $!';
    }

    zypper_call "in uwsgi uwsgi-python3";
    record_info 'uwsgi';
    assert_script_run '/usr/sbin/uwsgi --plugin python3 --http-socket :7000 --mount /=flask_app:app & sleep 10';
    assert_script_run 'curl -s http://localhost:7000/ | grep "Hello World"';
    assert_script_run 'kill $!';

    assert_script_run 'cd -';
}

1;

