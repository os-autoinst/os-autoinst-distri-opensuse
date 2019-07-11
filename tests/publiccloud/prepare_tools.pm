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
use warnings;
use testapi;
use utils;
use registration 'add_suseconnect_product';
use version_utils qw(is_sle is_opensuse);
use repo_tools 'generate_version';

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    if (my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO')) {
        for my $repo (split(/\s+/, $tools_repo)) {
            zypper_call('ar ' . $repo);
        }
    }

    # Install AWS cli
    if (is_opensuse) {
        zypper_call('-q in python3-devel');
        assert_script_run("pip3 install -q pycrypto");
        assert_script_run("pip3 install -q awscli");
        assert_script_run("pip3 install -q keyring");
    }
    elsif (is_sle) {
        zypper_call('-q in --force-resolution aws-cli');

        if (script_output('aws --version', 60, proceed_on_failure => 1) =~ /No module named vendored.requests.packages.urllib3.exceptions/m) {
            record_soft_failure('workaround for boo#1122199');
            my $repo      = 'http://download.opensuse.org/repositories/devel:/languages:/python:/aws/' . generate_version();
            my $repo_name = 'devel_languages_python_aws';
            zypper_ar($repo, name => $repo_name);
            zypper_call('-q in -f --repo ' . $repo_name . ' python-s3transfer');
            zypper_call('rr ' . $repo_name);
        }
        assert_script_run('aws --version');
    }
    zypper_call('-q in python-ec2uploadimg');
    assert_script_run("curl " . data_url('publiccloud/ec2utils.conf') . " -o /root/.ec2utils.conf");
    record_info('EC2', script_output('aws --version'));

    # install azure cli
    assert_script_run('sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc');
    zypper_call('addrepo --name "Azure CLI" --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli');
    zypper_call('-q in --from azure-cli -y azure-cli');
    record_info('Azure', script_output('az -v'));


    # Install Google Cloud SDK
    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl sdk.cloud.google.com | bash");
    assert_script_run("echo . /root/google-cloud-sdk/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/google-cloud-sdk/path.bash.inc >> ~/.bashrc");
    record_info('GCE', script_output('source ~/.bashrc && gcloud version'));


    # Create some directories, ipa will need them
    assert_script_run("mkdir -p ~/ipa/tests/");
    assert_script_run("mkdir -p .config/ipa");
    assert_script_run("touch .config/ipa/config");
    assert_script_run("img-proof list");
    record_info('IPA', script_output('img-proof --version'));

    # Install Terraform from repo
    zypper_call('ar https://download.opensuse.org/repositories/systemsmanagement:/terraform/SLE_15/systemsmanagement:terraform.repo');
    zypper_call('--gpg-auto-import-keys -q in terraform');
    record_info('Terraform', script_output('terraform -v'));

    select_console 'root-console';
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
