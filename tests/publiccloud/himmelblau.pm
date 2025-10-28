# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the himmelblau identity provider package
# Maintainer: qa-c team <qa-c@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);

sub configure_himmelblau {
    # Allow login from users in the provided domain and groups.
    # If users are provided directly (e.g. user@domain.com for `pam_allow_groups`) they will be allowed.
    my ($allowed_domain, $allowed_user) = @_;
    my $CONFIG_FILE = "/etc/himmelblau/himmelblau.conf";
    my $ENABLE_DEBUG_LOGS = "true";

    assert_script_run("sed -i -e 's/# domains =/domains = $allowed_domain/g' $CONFIG_FILE");
    assert_script_run("sed -i -e 's/# pam_allow_groups =.*/pam_allow_groups = $allowed_user/g' $CONFIG_FILE");
    assert_script_run("sed -i -e 's/# debug =.*/debug = $ENABLE_DEBUG_LOGS/g' $CONFIG_FILE");

    record_info("Himmelblau configured");
}

sub configure_nss {
    my $NSSWITCH_CONF_PATH = "/usr/etc/nsswitch.conf";

    assert_script_run("sed -i -e '0,/passwd:.*/!{0,/passwd:.*/s/passwd:.*/passwd:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sed -i -e '0,/group:.*/!{0,/group:.*/s/group:.*/group:    files systemd himmelblau/}' $NSSWITCH_CONF_PATH");
    assert_script_run("sed -i -e '0,/shadow:.*/!{0,/shadow:.*/s/shadow:.*/shadow:   files himmelblau/}' $NSSWITCH_CONF_PATH");

    record_info("NSS configured");
}

sub configure_pam {
    assert_script_run('pam-config --add --himmelblau');
    assert_script_run('sed -i -e "/account requisite pam_unix.so try_first_pass/account sufficient pam_unix.so try_first_pass/g" /etc/pam.d/common-account');
    record_info("PAM configured");
}

sub run {
    my ($self, $args) = @_;
    my $allowed_domain = get_required_var('HIMMELBLAU_ALLOWED_DOMAINS');
    my $allowed_user = get_required_var('HIMMELBLAU_ALLOWED_USERS');
    my $user = "$allowed_user\@$allowed_domain";
    select_serial_terminal;

    # Install Himmelblau
    zypper_call("update");
    zypper_call("lr -U");
    zypper_call("install himmelblau");

    # Configure the relevant services
    configure_himmelblau($allowed_domain, $user);
    configure_nss();
    configure_pam();

    # Start Himmelblau
    assert_script_run("systemctl enable himmelblaud himmelblaud-tasks --now");

    # Test if Himmelblau can get the user and generate the /etc/passwd entry
    validate_script_output("getent passwd $user", qr/\/home\/$user/);

    # Test if Himmelblau can map the user from Azure Entra ID
    validate_script_output("su -l $user -c whoami", qr/$allowed_user/);
}

1;
