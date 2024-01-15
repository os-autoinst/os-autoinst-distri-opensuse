# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python3-setuptools
# Summary: testsuite python3-setuptools
# - verify the systems python3-setuptools and python3-pip
# - creating and installing source distribution package using pip
# - install available python3-setuptools via python3 installation.
# - verify the available python3-setuptools with creation of package locally.
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use python_version_utils;
use utils "zypper_call";

sub run {
    select_serial_terminal;
    # Verify the system's python3 version
    my $system_python_version = get_system_python_version();
    record_info("System python version", "$system_python_version");

    # Import the project directory for creating a source distribution package.
    # The directory should contain setup.py and a Python module named test_module.py
    assert_script_run('curl -L -s ' . data_url('python/python3-setuptools') . ' | cpio --make-directories --extract && cd data');

    # Creating and installing the source distribution package
    build_install_package($system_python_version);
    cleanup_package($system_python_version);

    # Test all avaiable new python3 versions in SLEs if any
    if (is_sle) {
        my @python3_versions = get_available_python_versions();
        foreach my $python3_spec_release (@python3_versions) {
            zypper_call("install $python3_spec_release");
            build_install_package($python3_spec_release);
            cleanup_package($python3_spec_release);
        }
    }
}


# Creating the source package with the name 'dist/user_package_setuptools-1.0.tar.gz' in the dist folder.
# Installing the package and verifying it using the sample Python module 'test_module.py'.
sub build_install_package {
    my ($python3_release_version) = @_;
    record_info("pip3 version:", script_output("rpm -q $python3_release_version-pip"));
    record_info("python3-setuptools:", script_output("rpm -q $python3_release_version-setuptools"));
    my $python_version = get_python3_binary($python3_release_version);
    my @python_spec_release = split("python", $python_version);
    assert_script_run("$python_version -m venv myenv");
    assert_script_run("source myenv/bin/activate");
    assert_script_run("$python_version setup.py sdist ");
    validate_script_output("ls", sub { m/dist/ });
    validate_script_output("pip$python_spec_release[1] install dist/user_package_setuptools-1.0.tar.gz", sub { m/Successfully installed/ });
    my @package_loc = split(/:/, script_output("pip$python_spec_release[1] show user_package_setuptools | grep Location"));
    validate_script_output("ls $package_loc[1]", sub { m/user_package_setuptools/ });
    assert_script_run("python$python_spec_release[1] sample_test_module/test_module.py");
}

# Uninstall the installed user_package_setuptools and verify it.
sub cleanup_package {
    my ($python3_release_version) = @_;
    my $python_version = get_python3_binary($python3_release_version);
    my @python_spec_release = split("python", $python_version);
    assert_script_run("pip$python_spec_release[1] uninstall user_package_setuptools -y");
    my $out = script_output "$python_version sample_test_module/test_module.py", proceed_on_failure => 1;
    die("pip uninstall failed for the package") if (index($out, "ModuleNotFoundError") == -1);
    # Deletion of user_package_setuptools.egg-info and dist folder
    assert_script_run("rm -r user_package_setuptools.egg-info");
    assert_script_run("rm -r dist");
    assert_script_run("deactivate");

}

sub post_run_hook {
    remove_installed_pythons() if (is_sle);
}

sub post_fail_hook {
    remove_installed_pythons() if (is_sle);
}

1;
