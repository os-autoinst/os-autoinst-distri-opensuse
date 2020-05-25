# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing docker
# Maintainer: Anna Minou <anna.minou@suse.de>

package containers::docker;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;

our @EXPORT = qw(set_up get_vars build_img test_built_img);

my $dir     = '';
my $id      = '';
my $version = '';

# Setup environment
sub set_up() {
    $dir = "/root/DockerTest";
    assert_script_run("mkdir $dir");
    assert_script_run("cd $dir");
    assert_script_run("mkdir BuildTest");
    assert_script_run("cd BuildTest");
    assert_script_run("wget --quiet " . data_url('containers/app.py'));
    assert_script_run("wget --quiet " . data_url('containers/Dockerfile'));
    assert_script_run("wget --quiet " . data_url('containers/requirements.txt'));
    assert_script_run("cd ..");
}

# Get job id and version variables

sub get_vars() {
    my $name = get_var('NAME');
    $id      = (split('-', $name))[0];
    $version = get_var('VERSION');
}

# Build the image
sub build_img() {
    assert_script_run("docker pull python:3", timeout => 300);
    assert_script_run("docker build -t myapp BuildTest");
    assert_script_run("docker images| grep myapp");
}

# Run the built image
sub test_built_img() {
    assert_script_run("cd");
    assert_script_run("mkdir templates");
    assert_script_run("cd templates");
    assert_script_run("wget --quiet " . data_url('containers/index.html'));
    assert_script_run("docker run -dit -p 8888:5000 -v ~/templates:\/usr/src/app/templates myapp https://openqa.suse.de//api/v1/jobs/${id}");
    assert_script_run("docker ps -a");
    assert_script_run('curl http://localhost:8888/ | grep "You shall not pass in version: ' . $version . '"');
}
1;
