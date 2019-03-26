# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check HAWK GUI with the a python+selenium script and firefox
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use selenium;
use x11test;
use x11utils;
use version_utils 'is_desktop_installed';

sub install_geckodriver {
    my $arch             = check_var('ARCH', 'x86_64') ? 'linux64' : 'linux32';
    my $geckodriver_from = "https://github.com/mozilla/geckodriver/releases/download";
    # Using latest stable version of geckodriver
    my $geckodriver_ver = "v0.24.0";
    my $geckodriver_pkg = "geckodriver-$geckodriver_ver-$arch.tar.gz";

    assert_script_run "wget -P /tmp $geckodriver_from/$geckodriver_ver/$geckodriver_pkg";
    type_string "cd /tmp\n";
    assert_script_run "tar -zxvf $geckodriver_pkg";
    assert_script_run "mv -i geckodriver /usr/local/bin/";
    type_string "cd\n";
}

sub install_required_python_pkgs {
    my $inst_cmd = '';
    assert_script_run "zypper in -y python3-pip || zypper in -y python-pip || zypper in -y python-setuptools";

    # Determine how to install python packages
    if (is_package_installed('python3-pip') or is_package_installed('python-pip')) {
        $inst_cmd = 'pip install';
    }
    elsif (is_package_installed('python-setuptools')) {
        $inst_cmd = 'easy_install';
    }
    die "Couldn't find a way to install python packages" unless ($inst_cmd);

    # Install paramiko and selenium driver for python and determine which python to use
    my $output = script_output "$inst_cmd -U selenium paramiko";
    my $python = '';
    if ($output =~ m|.+(python[0-9])[0-9\.]+/site-packages.+|) {
        $python = $1;    # easy_install way
    }
    else {
        # pip way
        $output = script_output "pip --version";
        $output =~ m|.+(python[0-9])[0-9\.]+/site-packages.+|;
        $python = $1;
    }
    die "Couldn't determine which python is installed in the system: [$python]"
      unless ($python eq 'python2' or $python eq 'python3');
    return $python;
}

sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;

    # Wait for each cluster node to check for its hawk service
    barrier_wait("HAWK_GUI_INIT_$cluster_name");

    unless (is_desktop_installed()) {
        record_info "HAWK GUI test", "HAWK GUI test requires GUI desktop installed";
        return;
    }

    select_console 'root-console';

    my $python = install_required_python_pkgs;
    install_geckodriver;
    enable_selenium_port;

    select_console 'x11';
    x11_start_program('xterm');
    turn_off_gnome_screensaver;

    # Download and prepare python selenium script
    my $pyscr    = 'hawk_test';
    my $test_scr = "$pyscr.py";
    assert_script_run "curl -f -v " . autoinst_url . "/data/ha/$test_scr > /tmp/$test_scr";

    # Run test
    my $browser  = 'firefox';
    my $version  = get_required_var('VERSION');
    my $hostname = choose_node(1);
    my $results  = "/tmp/$pyscr.results";
    my $retcode  = "/tmp/$pyscr.ret";
    my $logs     = "/tmp/$pyscr.log";
    type_string "$python /tmp/$test_scr -b $browser -t $version -H $hostname -s $testapi::password -r $results > $logs 2>&1; echo $pyscr-\$? > $retcode; exit\n";
    assert_screen "hawk-$browser", 120;

    my $loop_count = 120;    # 10 minutes (120*5)
    while (!check_screen('generic-desktop', 0, no_wait => 1)) {
        sleep 5;
        $loop_count--;
        last if ($loop_count < 0);
    }
    if ($loop_count < 0) {
        record_info("$browser failed", "Test with browser [$browser] could not be completed in 10 minutes", result => 'softfail');
        send_key 'alt-f4';    # Force close of browser
    }
    save_screenshot;

    # Error, log and results handling
    select_console 'user-console';
    type_string "touch geckodriver.log\n";    # Create geckodriver.log if it doesn't exist
    upload_logs 'geckodriver.log';

    # Upload output of python/selenium scripts
    my $output = script_output "cat $retcode";
    if ($output =~ m/$pyscr-(\d+)/) {
        my $ret = $1;
        record_info("$browser retcode", "Test [$pyscr] on browser [$browser] failed with code: [$ret]. Check log files for details", result => 'softfail')
          if ($ret != 0);
    }
    else {
        record_info("$browser unknown error", "Test [$pyscr] failed on browser [$browser]. Unknow error: [$output]. Check log files for details", result => 'softfail');
    }
    upload_logs $logs;

    # Upload results
    my $are_results = script_run("ls $results");
    # Fail test if results file does not exist, otherwise parse it
    die "Selenium test [$pyscr] aborted. Check logs" if ($are_results or !defined $are_results);
    parse_extra_log(IPA => $results);

    # Synchronize with the nodes
    barrier_wait("HAWK_GUI_CHECKED_$cluster_name");
}

1;
