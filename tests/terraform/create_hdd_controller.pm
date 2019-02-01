# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: create a qcow2 image with all the needed tools for tests using
#          Terraform.
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    if (is_sle && (get_required_var('VERSION') eq '15-SP1')) {
        zypper_call('-q ar -G  https://download.opensuse.org/repositories/systemsmanagement:/sumaform/SLE_15/systemsmanagement:sumaform.repo');
    } else {
        die("This HDD creation is to be done on SLE15-SP1 images");
    }

    zypper_call('-q in -y terraform-provider-libvirt');

    my $version = get_var('TERRAFORM_VERSION', '0.11.11');
    assert_script_run("wget -q https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip", 300);
    assert_script_run("unzip terraform_${version}_linux_amd64.zip");
    assert_script_run('mv terraform /usr/bin/terraform');
    assert_script_run('terraform -v');

    assert_script_run('mkdir -p /root/.ssh');
    assert_script_run('chmod 700 /root/.ssh');
    assert_script_run('echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config');
    assert_script_run('echo "LogLevel ERROR" >> /etc/ssh/ssh_config');

    # this is needed for the test 'sle15_workarounds' to work as it fails
    # if the previous test has selected virtio console
    select_console('root-console');
}

1;
