# SUSE's Flask regression test
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-Flask python3-gevent python3-gunicorn uwsgi uwsgi-python3
# Summary: Test basic flask framework and gunicorn/uwsgi wsgi servers
# Maintainer: qe-core@suse.de

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use package_utils 'install_package';
use version_utils qw(is_sle is_transactional);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('<15') ? '12' : undef)) if is_sle('<16');

    install_package("python3-Flask", trup_continue => 1, trup_reboot => 1);

    assert_script_run "cd ~$username/data/";

    record_info 'flask dev';
    assert_script_run './flask_app.py & sleep 10';
    assert_script_run 'curl -s http://localhost:5000/ | grep "Hello World"';
    assert_script_run 'kill $!';

    if (is_sle('>=15-SP1')) {
        install_package("python3-gunicorn python3-gevent", trup_continue => 1, trup_reboot => 1);
        assert_script_run "cd ~$username/data/" if is_transactional;

        record_info 'gunicorn';
        assert_script_run 'gunicorn -b :6000 flask_app:app & sleep 10';
        assert_script_run 'curl -s http://localhost:6000/ | grep "Hello World"';
        assert_script_run 'kill $!';

        record_info 'gunicorn gevent';
        assert_script_run 'gunicorn -b :6000 flask_app:app -k gevent & sleep 10';
        assert_script_run 'curl -s http://localhost:6000/ | grep "Hello World"';
        assert_script_run 'kill $!';
    }

    # uwsgi is not available on SLE
    unless (is_sle) {
        zypper_call "in uwsgi uwsgi-python3";
        record_info 'uwsgi';
        assert_script_run '/usr/sbin/uwsgi --plugin python3 --http-socket :7000 --mount /=flask_app:app & sleep 10';
        assert_script_run 'curl -s http://localhost:7000/ | grep "Hello World"';
        assert_script_run 'kill $!';
    }

    assert_script_run 'cd -';
}

1;

