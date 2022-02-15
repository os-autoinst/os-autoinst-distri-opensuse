# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-ec2metadata iproute2 ca-certificates
# Summary: This is just bunch of random commands overviewing the public cloud instance
# We just register the system, install random package, see the system and network configuration
# This test module will fail at the end to prove that the test run will continue without rollback
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils;
use Mojo::Base 'publiccloud::ssh_interactive_init';
use publiccloud::utils "select_host_console";
our $root_dir = '/root';


sub run {
    my ($self, $args) = @_;
    # Preserve args for post_fail_hook
    $self->{provider} = $args->{my_provider};

    script_run("hostname -f");
    assert_script_run("uname -a");
    select_console('root-console');
    my $url = get_var('PUBLIC_CLOUD_DMS_IMAGE_LOCATION');
    my $package = get_var('PUBLIC_CLOUD_DMS_PACKAGE');
    my $dms_rpm = "$url"."$package";
    my $instance;
    my $source_rpm_path = $root_dir . '/' . $package;
    my $remote_rpm_path = '/tmp/' . $package;
    print "DMS remote $remote_rpm_path \n";
    print "DMS source  $source_rpm_path \n";
    my $wgt_cmd = "wget $dms_rpm -O $remote_rpm_path"; 
    print "DMS wgt_cmd $wgt_cmd \n";
    exec ($wgt_cmd);
    $instance->run_ssh_command(cmd => 'sudo zypper in ' . $remote_rpm_path, timeout => 600);
    print "DMS run_ssh_command \n";
}

1;
