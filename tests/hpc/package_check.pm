# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: HPC package(s) checks
#  The test is meant as rudimentary check of some white-listed specific
#  packages. The white list should be located in data folder and should
#  contain the list of rpms with expected minimal versions. This white
#  list is then used for basic checks if packages are installable, if
#  the version is as expected and then (if feasible) single basic tests
#  is run for each package.
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base 'hpcbase';
use strict;
use warnings;
use testapi;
use utils;
use Sort::Versions;

sub check_version {
    my ($rpm, $expected_version) = @_;

    my $installed_rpm_ver;

    $installed_rpm_ver = script_output("rpm -q --qf \"%{VERSION}\" $rpm");

    if (versioncmp($installed_rpm_ver, $expected_version) == 0) {
        record_info('PASS: ver. check', script_output("echo $rpm version is satisfied: EQUAL"));
        record_info('DEBUG', script_output("echo expected vs installed: $installed_rpm_ver: $expected_version"));
    } elsif (versioncmp($installed_rpm_ver, $expected_version) == 1) {
        record_info('PASS: ver. check', script_output("echo $rpm version is satisfied: HIGHER"));
        record_info('DEBUG', script_output("echo expected vs installed: $installed_rpm_ver: $expected_version"));
    } else {
        record_info('FAIL: ver. check', script_output("echo $rpm version is not satisfied"));
	record_info('DEBUG', script_output("echo expected vs installed: $installed_rpm_ver: $expected_version"));
    }
}

sub run_test {
    my ($rpm) = @_;

    record_info("test: $rpm");
    if ($rpm eq "cpuid") {
        test_cpuid($rpm);
    } elsif ($rpm eq "papi") {
        test_papi($rpm);
    }
}

sub test_cpuid {
    my ($rpm) = @_;

    assert_script_run('cpuid --one-cpu');
    record_info("PASS: $rpm", script_output('cpuid --one-cpu'));
}

sub test_papi {
    my ($rpm) = @_;

    zypper_call('in git gcc');

    script_run("wget --quiet " . data_url("hpc/papi.sh") . " -O papi.sh");
    script_run('chmod +x papi.sh');
    script_run('./papi.sh');

    record_info("PASS: $rpm", script_output('./papi/src/examples/PAPI_hw_info'));
}

sub acquire_rpm_list {
    my ($version) = @_;
    my $rpm_file = "package_list-$version";
    my @rpm_list;

    assert_script_run("wget --quiet " . data_url("hpc/$rpm_file") . " -O /tmp/$rpm_file");
    assert_script_run("wget --quiet " . data_url("hpc/pars_packages_list.pl") . " -O pars_packages_list-$version.pl");

    assert_script_run("chmod +x pars_packages_list-$version.pl");
    my $rpm_list = script_output("./pars_packages_list-$version.pl");

    @rpm_list = split(/\|/, $rpm_list);

    return @rpm_list;
}

sub run {
    my $self    = shift;
    my $version = get_required_var('VERSION');
    my $arch    = get_required_var('ARCH');
    my @rpms;

    @rpms = acquire_rpm_list($version);

    ## Install expected, white-listed rpms
    if ($arch eq 'aarch64') {
        ##TODO: blacklist cpuid
    }

    my @rpms_install = @rpms;
    foreach (@rpms_install) {
        if ($_ =~ /rpm:/) {
            $_ =~ s/rpm://;
            $_ =~ s{^\s+|\s+$}{}g;
            zypper_call("in $_\*" );
	    record_info("INST: $_", script_output("echo $_ installed"));
        }
    }

    ## Check versions of white-listed rpms on the SUT
    my $rpm;
    my $ver;
    foreach (@rpms) {
        my $tmp = $_;
	if ($_ =~ /version:/) {
            $_ =~ s/version://;
	    $_ =~ s{^\s+|\s+$}{}g;
	    $ver = $_;
            check_version($rpm, $ver);
            run_test($rpm);
        }
        $rpm = $tmp;
        $rpm =~ s/rpm://;
        $rpm =~ s{^\s+|\s+$}{}g;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
}

1;
