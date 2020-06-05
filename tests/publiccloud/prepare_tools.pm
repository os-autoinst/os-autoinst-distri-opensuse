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

sub install_in_venv {
    my ($pip_packages, $binary) = @_;
    die("Missing pip packages") unless ($pip_packages);
    die("Missing binary name")  unless ($binary);
    my $install_timeout = 15 * 60;
    $pip_packages = [$pip_packages] unless ref $pip_packages eq 'ARRAY';

    my $venv = '/root/.venv_' . $binary;
    assert_script_run("virtualenv '$venv'");
    assert_script_run(". '$venv/bin/activate'");
    assert_script_run('pip install --force-reinstall ' . join(' ', map("'$_'", @$pip_packages)), timeout => $install_timeout);
    assert_script_run('deactivate');
    my $script = <<EOT;
#!/bin/sh
. "$venv/bin/activate"
if [ ! -e "$venv/bin/$binary" ]; then
   echo "Missing $binary in virtualenv $venv"
   deactivate
   exit 2
fi
$binary "\$@"
exit_code=\$?
deactivate
exit \$exit_code
EOT
    my $run           = $binary . '-run-in-venv';
    my $run_full_path = "$venv/bin/$run";
    save_tmp_file($run, $script);
    assert_script_run(sprintf('curl -o "%s" "%s/files/%s"', $run_full_path, autoinst_url, $run));
    assert_script_run(sprintf('chmod +x "%s"', $run_full_path));
    assert_script_run(sprintf('ln -s "%s" "/usr/bin/%s"', $run_full_path, $binary));
}

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    if (my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO')) {
        for my $repo (split(/\s+/, $tools_repo)) {
            zypper_call('ar ' . $repo);
        }
    }

    # Install prerequesite packages test
    zypper_call('-q in python3-pip python3-virtualenv python3-img-proof python3-img-proof-tests');
    record_info('python', script_output('python --version'));

    # Install AWS cli
    install_in_venv('awscli', 'aws');
    record_info('EC2', script_output('aws --version'));

    # Install ec2imgutils
    install_in_venv('ec2imgutils', 'ec2uploadimg');
    assert_script_run("curl " . data_url('publiccloud/ec2utils.conf') . " -o /root/.ec2utils.conf");
    record_info('ec2imgutils', 'ec2uploadimg:' . script_output('ec2uploadimg --version'));

    # Install Azure cli
    install_in_venv('azure-cli', 'az');
    record_info('Azure', script_output('az -v'));

    # Install Google Cloud SDK
    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl sdk.cloud.google.com | bash");
    assert_script_run("echo . /root/google-cloud-sdk/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/google-cloud-sdk/path.bash.inc >> ~/.bashrc");
    record_info('GCE', script_output('source ~/.bashrc && gcloud version'));

    # Create some directories, ipa will need them
    assert_script_run("img-proof list");
    record_info('img-proof', script_output('img-proof --version'));

    # Install Terraform from repo
    zypper_call('ar https://download.opensuse.org/repositories/systemsmanagement:/terraform/SLE_15_SP1/systemsmanagement:terraform.repo');
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
