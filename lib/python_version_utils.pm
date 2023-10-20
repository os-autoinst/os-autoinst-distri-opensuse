# Copyright 2015-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package python_version_utils;

use base Exporter;
use Exporter;
use testapi;
use utils 'zypper_call';
use strict;
use warnings;
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);


our @EXPORT = qw(
  get_system_python_version
  get_available_python_versions
  get_python3_binary
  remove_installed_pythons
);

=head2 get_system_python_version

returns a string with the system's current default python version, for example 'python311'
=cut

sub get_system_python_version() {
    my @system_python_version = script_output(qq[zypper se --installed-only --provides '/usr/bin/python3' | awk -F '|' '/python3[0-9]*/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]);
    die "There are many python3 versions installed " if (scalar(@system_python_version) > 1);
    return $system_python_version[0];
}

=head2 get_available_python_versions

returns an array of strings with all the available python versions in the repository
=cut

sub get_available_python_versions() {
    my @python3_versions = split(/\n/, script_output(qq[zypper se 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
    record_info("Available versions", "All available new python3 versions are: @python3_versions");
    return @python3_versions;
}

=head2 get_python3_binary

given a python package version, e.g. python311, returns the executable name python3.11 
when the package is 'python3', return the system default one (eg python3.6 for SLE15.4)
=cut

sub get_python3_binary ($python3_package) {
    if ($python3_package eq "python3") {
        my $current_version = script_output("rpm -q python3 --queryformat '%{version}'");
        $current_version =~ s/\.\d+$//;
        return "python$current_version";
    }
    my $sub_version = substr($python3_package, 7);
    return "python3.$sub_version";
}

=head2 remove_installed_pythons

remove all the installed available python versions
=cut

sub remove_installed_pythons() {
    my $default_python = script_output("python3 --version | awk -F ' ' '{print \$2}\'");
    my @python3_versions = split(/\n/, script_output(qq[zypper se -i 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
    record_info("Installed versions", "All Installed new python3 versions are: @python3_versions");
    foreach my $python3_spec_release (@python3_versions) {
        my $python_versions = script_output("rpm -q $python3_spec_release | awk -F \'-\' \'{print \$2}\'");
        record_info("Python version", "$python_versions:$default_python");
        next if ($python_versions eq $default_python);
        zypper_call("remove $python3_spec_release-base");
    }
}

1;
