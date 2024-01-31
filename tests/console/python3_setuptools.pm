# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python3-setuptools
# Summary: testsuite python3-setuptools
# - verify the systems python3-setuptools and python3-pip
# - creating and installing source distribution package using pip
# - install available python3-setuptools via python3 installation.
# - verify the available python3-setuptools with creation of package locally.
# - install also the package via http server
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use python_version_utils;
use utils "zypper_call";
use feature qw(signatures);
no warnings qw(experimental::signatures);

sub run {
    select_serial_terminal;
    # Verify the system's python3 version
    my $system_python_version = get_system_python_version();
    record_info("System python version", "$system_python_version");
    # Import the project directory for creating a source distribution package.
    # The directory should contain setup.py and a Python module named test_module.py
    assert_script_run('curl -L -s ' . data_url('python/python3-setuptools') . ' | cpio --make-directories --extract && cd data');
    # Run the package creation and install test for system python
    run_tests($system_python_version);
    # Test all available new python3 versions in SLEs if any
    if (is_sle()) { run_tests($_) foreach (get_available_python_versions()); }
}

sub run_tests ($python3_spec_release) {
    zypper_call("install $python3_spec_release");
    record_info("pip3 version:", script_output("rpm -q $python3_spec_release-pip"));
    record_info("python3-setuptools:", script_output("rpm -q $python3_spec_release-setuptools"));
    my $python_binary = get_python3_binary($python3_spec_release);
    my $version_number = (split("python", $python_binary))[1];    # yields only the version e.g. 3.11
    build_package($python_binary);
    http_install_test($version_number);
    local_install_test($version_number);
}

# Creating the source package with the name 'dist/user_package_setuptools-1.0.tar.gz' in the dist folder.
sub build_package ($python_binary) {
    assert_script_run("$python_binary -m venv myenv");
    assert_script_run("source myenv/bin/activate");
    assert_script_run("$python_binary setup.py sdist ");
    validate_script_output("ls", sub { m/dist/ });
}

# Installs the package from local archive and verify it using the sample Python module 'test_module.py'.
sub local_install_test ($version_number) {
    validate_script_output("pip$version_number install dist/user_package_setuptools-1.0.tar.gz", sub { m/Successfully installed/ });
    my @package_loc = split(/:/, script_output("pip$version_number show user_package_setuptools | grep Location"));
    validate_script_output("ls $package_loc[1]", sub { m/user_package_setuptools/ });
    assert_script_run("python$version_number sample_test_module/test_module.py");
    uninstall_package($version_number);
}

# Installs the package from http server and verify it using the sample Python module 'test_module.py'.
sub http_install_test ($version_number) {
    # Prepare repository structure. Notice the directory must be in normalized form
    # (https://packaging.python.org/en/latest/specifications/name-normalization/#name-normalization)
    assert_script_run "mkdir -p repo_webroot/user-package-setuptools && cp dist/*.tar.gz repo_webroot/user-package-setuptools && pushd repo_webroot";
    assert_script_run "pip$version_number install wheel";
    # spin up a local http server just for this installation
    my $server_pid = background_script_run "python$version_number -m http.server";
    # install the package from http server
    assert_script_run "pip$version_number install --no-build-isolation -i http://localhost:8000 user_package_setuptools";
    # close server and restore directory
    assert_script_run "kill $server_pid && popd";
    assert_script_run("python$version_number sample_test_module/test_module.py");
    uninstall_package($version_number);
}

# Uninstall the installed user_package_setuptools and verify it.
sub uninstall_package ($version_number) {
    assert_script_run("pip$version_number uninstall user_package_setuptools -y");
    my $out = script_output "python$version_number sample_test_module/test_module.py", proceed_on_failure => 1;
    die("pip uninstall failed for the package") if (index($out, "ModuleNotFoundError") == -1);
}

sub cleanup {
    # Deletion of work folders
    assert_script_run("rm -rf dist user_package_setuptools.egg-info repo_webroot");
    assert_script_run("deactivate");    # leave the virtual env
}

sub post_run_hook {
    remove_installed_pythons() if (is_sle);
    cleanup();
}

sub post_fail_hook {
    remove_installed_pythons() if (is_sle);
    cleanup();
}

1;
