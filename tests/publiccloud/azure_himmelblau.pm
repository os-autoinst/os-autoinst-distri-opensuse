# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in Azure using azure-cli binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    assert_script_run('az version');

    my $provider = $self->provider_factory();
    my $region = get_var('PUBLIC_CLOUD_REGION');
    my $resource_group = "openqa-$job_id";
    
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $created_by = "$openqa_url/t$job_id";
    my $tags = "openqa-job=$job_id openqa_created_by=$created_by openqa_var_server=$openqa_url";

    our $TEST_USER = "";
    our $ALLOWED_DOMAINS = "";
    our $ALLOWED_GROUPS = "";
    our $ALLOWED_USERS = "";

    # Install Himmelblau
    zypper_call("update -y");
    assert_script_run("sudo zypper install himmelblau -y");

    # Disable name caching
    assert_script_run("sudo systemctl disable nscd --now");
    
    configure_himmelblau;
    configure_nss;
    configure_pam;

    assert_script_run("sudo systemctl enable himmelblaud himmlaud-tasks --now");
    
    # Test if Himmelblau can get the user and generate the /etc/shadow entry
    getent passwd $TEST_USER

    # Test if Himmelblau can authenticate with the user from Azure Entra ID
    su -l $TEST_USER
}

sub configure_himmelblau {
    my $CONFIG_FILE = "/etc/himmelblau/himmelblau.conf";
    my $ENABLE_DEBUG_LOGS = "true";

    assert_script_run("sudo sed -i -e 's/# domains =/domains = $ALLOWED_DOMAINS/g' $CONFIG_FILE");
    assert_script_run("sudo sed -i -e 's/# pam_allow_groups =.*/pam_allow_groups = $ALLOWED_GROUPS,$ALLOWED_USERS/g' $CONFIG_FILE");
    assert_script_run("sudo sed -i -e 's/# debug =.*/debug = $ENABLE_DEBUG_LOGS/g' $CONFIG_FILE");
}

sub configure_pam {
    assert_script_run('pam-config --add --himmelblau');
    assert_script_run('sudo sed -i -e "/account requisite pam_unix.so try_first_pass/account sufficient pam_unix.so try_first_pass/g" /etc/pam.d/common-account');
}

sub configure_nss {
    my $NSSWITCH_CONF_PATH = "/usr/etc/nsswitch.conf";

    assert_script_run("sudo sed -i -e '0,/passwd:.*/!{0,/passwd:.*/s/passwd:.*/passwd:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sudo sed -i -e '0,/group:.*/!{0,/group:.*/s/group:.*/group:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sudo sed -i -e '0,/shadow:.*/!{0,/shadow:.*/s/shadow:.*/shadow:   files himmelblau/}' $NSSWITCH_CONF_PATH");
}
