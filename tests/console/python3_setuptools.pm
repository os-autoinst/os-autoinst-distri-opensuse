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
use utils "zypper_call";

sub run {
    select_serial_terminal;
    # Verify the system's python3 version
    my @system_python_version = script_output(qq[zypper se --installed-only --provides '/usr/bin/python3' | awk -F '|' '/python3[0-9]*/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]);
    die "There are many python3 versions installed " if (scalar(@system_python_version) > 1);

    # Import the project directory for creating a source distribution package.
    # The directory should contain setup.py and a Python module named test_module.py
    assert_script_run('curl -L -s ' . data_url('python/python3-setuptools') . ' | cpio --make-directories --extract && cd data');

    # Creating and installing the source distribution package
    build_install_package($system_python_version[0]);
    cleanup_package($system_python_version[0]);

    # Test all avaiable new python3 versions in SLEs if any
    if (is_sle) {
        my $ret = zypper_call('se "python3[0-9]*"', exitcode => [0, 104]);
        die('No new python3 packages available') if ($ret == 104);
        my @python3_versions = split(/\n/, script_output(qq[zypper se 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
        record_info("Available versions", "All available new python3 versions are: @python3_versions");
        foreach my $python3_spec_release (@python3_versions) {
            zypper_call("install $python3_spec_release");
            build_install_package($python3_spec_release);
            cleanup_package($python3_spec_release);
        }
    }
}

sub get_python3_specific_release {
    my ($python3_version) = @_;
    if ($python3_version eq "python3") {
        record_info("System python version is:", script_output("rpm -q python3 | awk -F \'-\' \'{print \$2}\'"));
        return 3;
    }
    my $sub_version = substr($python3_version, 7);
    return "3.$sub_version";
}

# Creating the source package with the name 'dist/user_package_setuptools-1.0.tar.gz' in the dist folder.
# Installing the package and verifying it using the sample Python module 'test_module.py'.
sub build_install_package {
    my ($python3_release_version) = @_;
    record_info("pip3 version:", script_output("rpm -q $python3_release_version-pip"));
    record_info("python3-setuptools:", script_output("rpm -q $python3_release_version-setuptools"));
    my $python_version = get_python3_specific_release($python3_release_version);
    assert_script_run("python$python_version -m venv myenv");
    assert_script_run("source myenv/bin/activate");
    assert_script_run("python$python_version setup.py sdist ");
    validate_script_output("ls", sub { m/dist/ });
    validate_script_output("pip$python_version install dist/user_package_setuptools-1.0.tar.gz", sub { m/Successfully installed/ });
    my @package_loc = split(/:/, script_output("pip$python_version show user_package_setuptools | grep Location"));
    validate_script_output("ls $package_loc[1]", sub { m/user_package_setuptools/ });
    assert_script_run("python$python_version sample_test_module/test_module.py");
}

# Uninstall the installed user_package_setuptools and verify it.
sub cleanup_package {
    my ($python3_release_version) = @_;
    my $python_version = get_python3_specific_release($python3_release_version);
    assert_script_run("pip$python_version uninstall user_package_setuptools -y");
    my $out = script_output "python$python_version sample_test_module/test_module.py", proceed_on_failure => 1;
    die("pip uninstall failed for the package") if (index($out, "ModuleNotFoundError") == -1);
    # Deletion of user_package_setuptools.egg-info and dist folder
    assert_script_run("rm -r user_package_setuptools.egg-info");
    assert_script_run("rm -r dist");
    assert_script_run("deactivate");

}

# Remove the installed availble python versions.
sub remove_installed_pythons {
    my $default_python = script_output("python3 --version | awk -F ' ' '{print \$2}\'");
    my @python3_versions = split(/\n/, script_output(qq[zypper se -i 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
    record_info("Available versions", "All available new python3 versions are: @python3_versions");
    foreach my $python3_spec_release (@python3_versions) {
        my $python_versions = script_output("rpm -q $python3_spec_release | awk -F \'-\' \'{print \$2}\'");
        record_info("Python version", "$python_versions:$default_python");
        next if ($python_versions == $default_python);
        zypper_call("remove $python3_spec_release-base");
    }
}

sub post_run_hook {
    remove_installed_pythons() if (is_sle);
}

sub post_fail_hook {
    remove_installed_pythons() if (is_sle);
}

1;
