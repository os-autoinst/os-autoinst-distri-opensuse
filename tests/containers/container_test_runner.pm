# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Container test runner.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(get_os_release);

sub run {
    my ($self) = @_;
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_docker_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => 'docker');

    assert_script_run "git clone https://gitlab.com/b10n1k/madtes.git";
    assert_script_run "cd madtes";
    assert_script_run "zypper -n in python3-pip";
    assert_script_run "pip install -r requirements.txt";
    assert_script_run "py.test -v --rootdir=/root/madtes/tests/ --junitxml=report.xml";
    parse_extra_log("XUnit" => "report.xml");
}

1;
