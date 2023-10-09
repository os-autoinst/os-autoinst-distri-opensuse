# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python3?
# Summary: Run python3 testsuite
# - Test suitable only for SLE15SPs+
# - Check that Python 3.x is the main version installed based on SPs
# - Check that Python 3.1? is available to install
# - Install some python package using pip (e.g. pysample_package)
# - Test installed package by importing it in python script
# - Uninstall previously installed python package using pip
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use utils "zypper_call";
use registration "add_suseconnect_product";

sub run{
    select_serial_terminal;
    # Test system python3 version
    my @system_python3_version = script_output(qq[zypper se --installed-only --provides '/usr/bin/python3' | awk -F '|' '/python3[0-9]*/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq | head -1]);
    die "There are many python3 versions installed " if (scalar(@system_python3_version) > 1);
    my $sys_python3_version = get_python3_version($system_python3_version[0]);
    record_info("System python version", "$sys_python3_version");
    my ($python_version, $pip_version) = get_pip_version($sys_python3_version);
    #Test system python3 pip
    test_python_pip($python_version, $pip_version);
    #Test other available python versions
    test_available_python_versions();
}

sub test_available_python_versions {
    # Test all avaiable new python3 versions if any
    my $ret = zypper_call('se "python3[0-9]*"', exitcode => [0, 104]);
    die('No new python3 packages available') if ($ret == 104);
    my @python3_versions = split(/\n/, script_output(qq[zypper se 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
    record_info("Available versions", "All available new python3 versions are: @python3_versions");
    foreach my $python3_spec_release (@python3_versions) {
	record_info("Installing $python3_spec_release", "$python3_spec_release is tested now");
        zypper_call("install $python3_spec_release");
        my $python3_version = get_python3_version($python3_spec_release);
	my ($python_version, $pip_version) = get_pip_version($python3_version);
	#Test system python3 pip
        test_python_pip($python_version, $pip_version);
     }
}

sub test_python_pip {
    #Test pip package installation and uninstallation
    my ($python_version, $pip_version) = @_;
    my $package = "pysample_package-1.0.tar.gz";
    my $script = "test_pysample_package.py";
    assert_script_run("[ -f $package ] || curl -O " . data_url("console/$package") . " || true");
    record_info("Testing pip version $pip_version", "$pip_version is tested now");
    my $pip_install_cmd = "$pip_version install ".((split(/-/, $package))[0])." --no-index --find-links .";
    my $pip_install_output = script_output("$pip_install_cmd");
    record_info("Pip installed package:","$pip_install_output");
    my $pip_show_cmd = "$pip_version show ".((split(/-/, $package))[0]);
    my $pip_show_output = script_output("$pip_show_cmd");
    record_info("Verify package installation", "$pip_show_output");
    assert_script_run("[ -f $script ] || curl -O " . data_url("console/$script") . " || true");
    my $output = script_output("$python_version $script");
    record_info("Script output", "$output");
    my $pip_uninstall_cmd = "$pip_version uninstall -y ".((split(/-/, $package))[0]);
    $output = script_output("$pip_uninstall_cmd");
    record_info("Uninstall package: ", "$output");
}

sub get_python3_version {
    #Get specific version of python e.g."Python 3.6.15"
    my ($python3_version) = @_;
    if ($python3_version eq "python3") {
	return script_output("$python3_version --version");
    }
    my $sub_version = substr($python3_version, 7);
    return script_output("python3.$sub_version --version");
}

sub get_pip_version {
    #Get python and associated pip version e.g. "python3.6" and "pip3.6"
    my ($python_version) = @_;
    my ($major, $minor) = split(/\./, substr($python_version, 7),3);
    my ($pip_version) = script_output("pip$major.$minor --version");
    die "No associated pip installed for $python_version" if ($pip_version eq "");
    record_info("Pip version associated to $python_version is", "$pip_version");
    return ("python$major.$minor", "pip$major.$minor")
}


sub post_fail_hook {
    select_console 'log-console';
    assert_script_run 'save_y2logs /tmp/python3_pip_version_check_y2logs.tar.bz2';
    upload_logs '/tmp/python3_pip_version_check_y2logs.tar.bz2';
}

1;
