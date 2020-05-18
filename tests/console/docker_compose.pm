# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test docker-compose installation
#    Cover the following aspects of docker-compose:
#      * package can be installed
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>


use base "consoletest";
use testapi;
use registration;
use utils;
use version_utils 'is_sle';
use containers::common;
use strict;
use warnings;

sub run {
    select_console("root-console");

    install_docker_when_needed;
    add_suseconnect_product(get_addon_fullname('phub')) if is_sle();

    record_info 'Test #1', 'Test: Installation';
    zypper_call("in docker-compose");
    assert_script_run 'docker-compose --version';

    assert_script_run 'mkdir -p dcproject; cd dcproject';
    assert_script_run("wget " . data_url("containers/docker-compose.yml") . " -O docker-compose.yml");
    assert_script_run 'docker-compose pull';
    assert_script_run 'docker-compose up -d';
    assert_script_run 'docker-compose ps';
    assert_script_run 'docker-compose top';
    assert_script_run 'docker-compose logs > logs.txt';
    upload_logs "logs.txt";
    assert_script_run 'docker-compose down', 180;
    assert_script_run 'cd';

    remove_suseconnect_product(get_addon_fullname('phub')) if is_sle();
    clean_docker_host();
}

1;
