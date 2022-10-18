# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Package: ansible
# Summary: Test Ansible and its components
#   1. System setup
#   2. Ansible basics
#   3. Ansible Galaxy
#   4. Ansible playbook testing
#   5. Ansible playbook execution
#   6. Ansible Vault
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use utils qw(zypper_call random_string systemctl file_content_replace);
use version_utils qw(is_sle is_opensuse is_tumbleweed);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my $self = shift;
    select_serial_terminal;

    # 1. System setup

    if (is_sle) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    # Install ansible and ansible-test
    # Install python3-yamllint needed for ansible-test
    #   python3-yamllint is available from 15-SP2
    # Install git needed for ansible-galaxy
    zypper_call 'in ansible git-core python3-yamllint';

    # Start sshd
    systemctl 'start sshd';

    # add $testapi::username to sudoers without password
    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' | tee -a /etc/sudoers.d/ansible";

    # Logout root and login $testapi::username
    enter_cmd 'exit';
    select_user_serial_terminal;

    # Check that we are logged in as $testapi::username
    validate_script_output('whoami', sub { m/$testapi::username/ });

    # Check that we have sudo root permissions
    validate_script_output('sudo whoami', sub { m/root/ });

    # Generate RSA key
    assert_script_run 'ssh-keygen -b 2048 -t rsa -N "" -f ~/.ssh/id_rsa <<< y';

    # Make sure our public key is in the authorized_keys file
    assert_script_run 'cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys';

    # Learn public SSH host keys
    assert_script_run 'ssh-keyscan localhost >> ~/.ssh/known_hosts';

    # Check that we can connect to localhost via SSH
    validate_script_output 'ssh localhost whoami', sub { m/$testapi::username/ };

    # Download data/console/ansible/ directory
    assert_script_run 'curl ' . data_url('console/ansible/') . ' | cpio -id';

    # In order to use ansible-test we need to follow this directory tree
    assert_script_run "mkdir -p ~/ansible_collections/openqa";
    assert_script_run "mv data ~/ansible_collections/openqa/ansible";
    assert_script_run 'cd ~/ansible_collections/openqa/ansible';

    # Call the zypper module properly (depends on version)
    file_content_replace('roles/test/tasks/main.yaml', COMMUNITYGENERAL => ((is_tumbleweed) ? 'community.general.' : ''));

    # 2. Ansible basics

    # Check Ansible version
    record_info('ansible --version', script_output('ansible --version'));

    my $hostname = script_output 'hostname';
    validate_script_output 'ansible -m setup localhost | grep ansible_hostname', sub { m/$hostname/ };

    my $arch = get_var 'ARCH';
    validate_script_output 'ansible -m setup localhost | grep ansible_architecture', sub { m/$arch/ };

    # 3. Ansible Galaxy

    # Install config_manager role from ansible-network
    # https://galaxy.ansible.com/ansible-network/config_manager
    assert_script_run 'ansible-galaxy install ansible-network.config_manager', timeout => 300;

    # Verify that the config_manager is installed
    my $galaxy_installed = script_output 'ansible-galaxy list';
    die 'config_manager should be installed!' unless $galaxy_installed =~ m/ansible-network\.config_manager/;

    # Verify that network-engine is installed as dependency
    die 'network-engine should be installed!' unless $galaxy_installed =~ m/ansible-network\.network-engine/;

    # 4. Ansible playbook testing

    # Check that community.general.zypper module is available
    assert_script_run 'ansible-doc -l community.general | grep zypper';

    # Check the playbook
    assert_script_run 'ansible-playbook -i hosts main.yaml --check', timeout => 300;

    # Run the ansible sanity test
    if (script_run('ansible-test')) {
        record_soft_failure("boo#1204320 - Ansible: No module named 'ansible_test'");
    } else {
        script_run 'ansible-test --help';
        assert_script_run 'ansible-test sanity';
    }

    # 5. Ansible playbook execution

    # Print the inventory
    assert_script_run 'ansible -i hosts all --list-hosts';

    # Run the playbook
    assert_script_run 'ansible-playbook -i hosts main.yaml', timeout => 600;

    # Test that /tmp/ansible/uname.txt created by ansible has desired content
    my $uname = script_output 'uname -r';
    validate_script_output 'cat /tmp/ansible/uname.txt', sub { m/$uname/ };

    # Test that /tmp/ansible/static.txt contains the static file
    validate_script_output 'cat /tmp/ansible/static.txt', sub { m/stay the same/ };

    # Validate that /tmp/ansible/os-release points to /etc/os-release
    validate_script_output 'readlink /tmp/ansible/os-release', sub { m/\/etc\/os-release/ };

    # Test that /home/johnd/README.txt is readable and contains the expanded template
    validate_script_output 'sudo -u johnd cat /home/johnd/README.txt', sub { m/my $arch dynamic kingdom/ };

    # Check that Ed - the command line text edit is installed
    assert_script_run 'which ed';

    # 6. Ansible Vault

    # Generate random password file and random content file
    my $random_password = random_string(length => 8);
    my $random_content = random_string(length => 30);
    assert_script_run "echo '$random_password' > ./ranom_password.txt";
    assert_script_run "echo '$random_content' > ./ranom_content.txt";

    # Encrypt the content by the password - store it in propperly formated YAML
    assert_script_run 'echo "---" > ./encrypted_content.yaml';
    assert_script_run "cat ./ranom_content.txt | ansible-vault encrypt_string --vault-password-file ./ranom_password.txt --stdin-name random_content | tee -a ./encrypted_content.yaml";

    # Decrypt the content and check that it matches the origin
    validate_script_output 'ansible localhost --vault-password-file ./ranom_password.txt -e "@./encrypted_content.yaml" -m debug -a var=random_content', sub { m/$random_content/ };
}

sub cleanup {
    my $self = shift;
    # Logout $testapi::username
    enter_cmd 'exit';

    # Make sure that root console is logged off before we reset the consoles
    select_console 'root-console';
    enter_cmd 'exit';

    # Make sure that user console is logged off before we reset the consoles
    select_console 'user-console';
    enter_cmd 'exit';

    # Reset consoles and log in root
    reset_consoles;
    select_serial_terminal;

    # Remove all the directories ansible created
    assert_script_run 'rm -rf ~/ansible_collections/ /tmp/ansible/';

    # Remove the ansible sudoers file
    assert_script_run 'rm -rf /etc/sudoers.d/ansible';

    # Remove ansible, yamllint and git
    zypper_call 'rm ansible git-core python3-yamllint ed';
}

sub post_run_hook {
    my $self = shift;
    $self->cleanup;
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup;
    $self->SUPER::post_fail_hook;
}

1;
