# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install IPA tool
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use registration 'add_suseconnect_product';
use version_utils qw(is_sle is_opensuse);
use repo_tools 'generate_version';

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    if (is_sle) {
        my $modver = get_required_var('VERSION') =~ s/-SP\d+//gr;
        add_suseconnect_product('sle-module-public-cloud', $modver);
    }


    my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO', '');
    if ($tools_repo eq '') {
        $tools_repo = 'http://download.opensuse.org/repositories/Cloud:/Tools/' . generate_version() . '/Cloud:Tools.repo';
    }
    zypper_call('ar ' . $tools_repo);
    zypper_call('--gpg-auto-import-keys -q in python3-ipa python3-ipa-tests git-core');

    # Install AWS cli
    zypper_call('-q in gcc python3-pip');
    if (is_opensuse) {
        zypper_call('-q in python3-devel');
        assert_script_run("pip3 install -q pycrypto");
        assert_script_run("pip3 install -q awscli");
        assert_script_run("pip3 install -q keyring");
    }
    elsif (is_sle) {
        zypper_call('rr Cloud_Tools');
        zypper_call('ref');
        zypper_call('-q in aws-cli');
    }
    zypper_call('-q in python-ec2uploadimg');
    assert_script_run("curl " . data_url('publiccloud/ec2utils.conf') . " -o /root/.ec2utils.conf");

    # install azure cli
    zypper_call('-q in curl');
    assert_script_run('sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc');
    zypper_call('addrepo --name "Azure CLI" --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli');
    zypper_call('-q in --from azure-cli -y azure-cli');

    # Install Google Cloud SDK
    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl sdk.cloud.google.com | bash");
    assert_script_run("echo . /root/google-cloud-sdk/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/google-cloud-sdk/path.bash.inc >> ~/.bashrc");

    # Create some directories, ipa will need them
    assert_script_run("mkdir -p ~/ipa/tests/");
    assert_script_run("mkdir -p .config/ipa");
    assert_script_run("touch .config/ipa/config");
    assert_script_run("ipa list");
    assert_script_run("ipa --version");

    # Download and Install Terraform
    my $terraform_url = get_var('TERRAFORM_URL', 'https://releases.hashicorp.com/terraform/0.11.10/terraform_0.11.10_linux_amd64.zip');
    assert_script_run("wget -q $terraform_url");
    assert_script_run('unzip terraform_* terraform -d /usr/bin/');
    assert_script_run('terraform -v');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

=head1 Discussion

Install public cloud tools in SLE image. This image gets published and can be used
for specific tests for azure, amazon and google CSPs.

=head1 Configuration

=head2 PUBLIC_CLOUD_PREPARE_TOOLS

Activate this test module by setting this variable.

=head2 PUBLIC_CLOUD_TOOLS_REPO

The URL to the cloud:tools repo (optional).
(e.g. http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo)

=cut
