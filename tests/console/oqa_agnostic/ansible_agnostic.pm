# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run openQA-agnostic ansible tests
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle is_transactional);
use registration qw(add_suseconnect_product get_addon_fullname);
use transactional qw(trup_call check_reboot_changes);
use agnosticTestRunner;

my @pkgs = qw(sudo git-core ansible);

sub run {
    select_serial_terminal;

    # ansible and ansible-test come from different modules depending on the product
    if (is_sle('<15-SP6') && !main_common::is_updates_tests()) {
        add_suseconnect_product(get_addon_fullname('desktop'));
        add_suseconnect_product(get_addon_fullname('sdk'));
        add_suseconnect_product(get_addon_fullname('phub'));
        zypper_call '--gpg-auto-import-keys ref';
    }
    if (is_sle('<15-SP4') && main_common::is_updates_tests()) {
        add_suseconnect_product(get_addon_fullname('phub'));
        zypper_call '--gpg-auto-import-keys ref';
    }

    push @pkgs, qw(ansible-test python3-yamllint) unless is_sle;
    if (is_transactional) {
        trup_call("pkg install @pkgs");
        check_reboot_changes;
    }
    else {
        zypper_call "in @pkgs";
    }

    systemctl 'start sshd';

    # Provide the ansible collection used by the test and set the login user
    assert_script_run 'mkdir -p ~/ansible_collections/openqa';
    assert_script_run 'curl ' . data_url('console/ansible/') . ' | cpio -id';
    assert_script_run 'mv data ~/ansible_collections/openqa/ansible';
    assert_script_run "sed -i 's/ANSIBLEUSER/$testapi::username/' ~/ansible_collections/openqa/ansible/hosts";

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testAnsible',
            domain => 'console',
            # PackageHub is enabled above only when the product needs it
            skip_phub => 1,
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
