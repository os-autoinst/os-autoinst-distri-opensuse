# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Basic aistack test

# Summary: This test performs the following actions
#  - Calls AI Stack sanity tests
# Maintainer: Rhuan Queiroz <rqueiroz@suse.com>
#

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use publiccloud::utils;
use version_utils;
use transactional qw(process_reboot trup_install trup_shell trup_call);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $args) = @_;

    my $instance = $self->{my_instance};
    my $provider = $self->{provider};

    my $test_archive = get_required_var('OPENWEBUI_SANITY_TESTS_ARCHIVE');
    my $sanity_tests_url = data_url("aistack/" . $test_archive);

    my $test_folder = $test_archive;
    $test_folder =~ s/\.tar(\.gz)?$//;

    assert_script_run("curl -O " . $sanity_tests_url);
    assert_script_run("mkdir " . $test_folder);
    assert_script_run("tar -xzvf " . $test_archive . " -C " . $test_folder);
    assert_script_run("python3.11 -m venv " . $test_folder . "/venv");
    assert_script_run("source " . $test_folder . "/venv/bin/activate");
    assert_script_run("pip3 install -r ./" . $test_folder . "/requirements.txt");
    assert_script_run("cp " . $test_folder . "/env.example " . $test_folder . "/.env");
    assert_script_run("pytest $test_folder/tests/");
}

1;
