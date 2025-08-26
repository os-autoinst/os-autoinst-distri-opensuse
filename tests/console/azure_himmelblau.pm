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

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);


sub configure_himmelblau {
    my $CONFIG_FILE = "/etc/himmelblau/himmelblau.conf";
    my $ENABLE_DEBUG_LOGS = "true";
    my $ALLOWED_DOMAINS = get_required_var('HIMMELBLAU_ALLOWED_DOMAINS');
    my $ALLOWED_GROUPS = get_required_var('HIMMELBLAU_ALLOWED_GROUPS');
    my $ALLOWED_USERS = get_required_var('HIMMELBLAU_ALLOWED_USERS');

    assert_script_run("sed -i -e 's/# domains =/domains = $ALLOWED_DOMAINS/g' $CONFIG_FILE");
    assert_script_run("sed -i -e 's/# pam_allow_groups =.*/pam_allow_groups = $ALLOWED_GROUPS,$ALLOWED_USERS/g' $CONFIG_FILE");
    assert_script_run("sed -i -e 's/# debug =.*/debug = $ENABLE_DEBUG_LOGS/g' $CONFIG_FILE");
}

sub configure_pam {
    assert_script_run('pam-config --add --himmelblau');
    assert_script_run('sed -i -e "/account requisite pam_unix.so try_first_pass/account sufficient pam_unix.so try_first_pass/g" /etc/pam.d/common-account');
}

sub configure_nss {
    my $NSSWITCH_CONF_PATH = "/usr/etc/nsswitch.conf";

    assert_script_run("sed -i -e '0,/passwd:.*/!{0,/passwd:.*/s/passwd:.*/passwd:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sed -i -e '0,/group:.*/!{0,/group:.*/s/group:.*/group:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sed -i -e '0,/shadow:.*/!{0,/shadow:.*/s/shadow:.*/shadow:   files himmelblau/}' $NSSWITCH_CONF_PATH");
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    #if (script_run("which az") != 0) {
    #    add_suseconnect_product(get_addon_fullname('pcm'), undef);
    #    zypper_call('in azure-cli jq python3-susepubliccloudinfo');
    #}
    #assert_script_run('az version');

    # Install Himmelblau
    zypper_call("update -y");
    zypper_call("lr -U");
    zypper_call("install himmelblau");

    # Disable name caching  ( TODO: not exists actually by default . do we really need this ?)
    script_run("systemctl disable nscd --now");

    configure_himmelblau;
    configure_nss;
    configure_pam;

    assert_script_run("systemctl enable himmelblaud himmlaud-tasks --now");

    my  $user = get_required_var('HIMMELBLAU_USER');

    # Test if Himmelblau can get the user and generate the /etc/shadow entry
    assert_script_run("getent passwd $user");

    # Test if Himmelblau can authenticate with the user from Azure Entra ID
    assert_script_run("su -l $user");
}

1;
