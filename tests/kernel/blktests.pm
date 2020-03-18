# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: new test that runs NVMe over Fabrics testsuite
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_ar(get_required_var('BENCHMARK_REPO'));
    if (get_var('DEVEL_LANG_PYTHON_REPO')) {
        zypper_ar(get_var('DEVEL_LANG_PYTHON_REPO'));
    }
    else {
        assert_script_run('python -m ensurepip --default-pip');
        assert_script_run('pip install nose nose2 natsort pep8 flake8 pylint epydoc');
    }
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('in --no-recommends nvmftests');

    assert_script_run('cd /var/lib/nvmftests');
    assert_script_run('ln -sf tests/config config');
    assert_script_run('nose2 --verbose', 1200);

    power_action('poweroff');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook { }

1;


=head1 Configuration

=head2 Required Repositories

The NVMe over Fabrics Unit Test Framework requires repositories from OBS to run:
- devel:languages:python
- benchmark

Apart from that, no further repositories are required for SLE and openSUSE.

=head2 Example
Example Leap 15 test suite configuration

BENCHMARK_REPO="https://download.opensuse.org/repositories/benchmark/openSUSE_Leap_15.0/benchmark.repo"
BOOT_HDD_IMAGE=1
DESKTOP=textmode
DEVEL_LANG_PYTHON_REPO="https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.0/devel:languages:python.repo"
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
HDDMODEL_2='nvme'
NUMDISKS=2
ISO=SLE-%VERSION%-Server-DVD-%ARCH%-Build%BUILD%-Media1.iso
ISO_1=SLE-%VERSION%-SDK-DVD-%ARCH%-Build%BUILD_SDK%-Media1.iso
ISO_2=SLE-%VERSION%-WE-DVD-%ARCH%-Build%BUILD_WE%-Media1.iso
NVMFTESTS=1
PUBLISH_HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_ltp_installed.qcow2
QEMUCPUS=4
QEMURAM=4096
START_AFTER_TEST=create_hdd_textmode
TEST='nvmftests'

For SLE the configuration is similar, but the two repositories need to be adjusted with the correct builds.

=head2 NVMFTESTS
Set this to "1" to enable the execution of nvmftests

=head2 DEVEL_LANG_PYTHON_REPO
This variable points to the devel_languages:python project's repo in OBS.

=head2 BENCHMARK_REPO
This variable points to the benchmark project's repo in OBS.

