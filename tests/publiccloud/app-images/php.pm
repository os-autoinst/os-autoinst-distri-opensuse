# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: PHP image smoke test in public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use utils;
use publiccloud::utils;
use publiccloud::ssh_interactive 'select_host_console';


sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $instance = $args->{my_instance};

    record_info('PHP Version', $instance->ssh_script_output('php -v'));
    record_info('PHP Modules', $instance->ssh_script_output('php -m'));

    my $start_dev_server_script_path = "/usr/local/bin/start-dev-server.sh";
    $self->prepare_assets($start_dev_server_script_path);

    $instance->ssh_assert_script_run($start_dev_server_script_path);

    $instance->ssh_script_retry(
        "curl -f -s http://localhost:8000/ | grep \"Hello SUSE\"",
        retry => 10,
        delay => 60,
        fail_message => "Sample application is not working properly"
    );
}

sub prepare_assets {
    my ($self, $start_dev_server_script_path) = @_;

    my $instance = $self->{run_args}->{my_instance};
    my $htdocs_path = "/srv/www/htdocs/hello-suse";
    $instance->ssh_assert_script_run("sudo mkdir -p $htdocs_path");
    upload_asset_on_remote(
        instance => $instance,
        source_data_url_path => "publiccloud/app_images/php/index.php",
        destination_path => "$htdocs_path/index.php",
        elevated => 1
    );

    upload_asset_on_remote(
        instance => $instance,
        source_data_url_path => "publiccloud/app_images/php/start-dev-server.sh",
        destination_path => $start_dev_server_script_path,
        elevated => 1
    );
    $instance->ssh_assert_script_run("sudo chmod +x $start_dev_server_script_path");
}

1;
