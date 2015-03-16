use base "opensusebasetest";
use testapi;

#In the console of Live-CD system, grab the sysauthtests scripts and install the test subjects.
sub run() {
    wait_idle;

    # Password-less login to tty4 on Live-CD
    send_key "ctrl-alt-f4";
    assert_screen "text-login", 10;
    type_string "$username\n";
    become_root;

    # Install test subjects and test scripts
    my @test_subjects =	qw/
        python-pam
        sssd sssd-krb5 sssd-krb5-common sssd-ldap sssd-tools
        openldap2 openldap2-client
        krb5 krb5-client krb5-server krb5-plugin-kdb-ldap
    /;
    script_run "systemctl stop packagekit.service; systemctl mask packagekit.service";
    script_run "zypper -n refresh && zypper -n in @test_subjects";

    script_run "cd; curl -L -v ".autoinst_url."/data/sssd-tests > sssd-tests.data && cpio -id < sssd-tests.data && mv data sssd && ls sssd";

    # The test scenarios are now ready to run
    my @scenario_failures;

    foreach my $scenario (qw/local ldap ldap-inherited-groups ldap-nested-groups krb/) {
        # Download the scenario directory
        script_run "cd ~/sssd && mkdir $scenario && curl -L -v ".autoinst_url."/data/sssd-tests/$scenario > $scenario/cdata";
        script_run "cd $scenario && cpio -idv < cdata && mv data/* ./; ls";
        validate_script_output "./test.sh", sub {
            (/junit testsuite/ && /junit success/ && /junit endsuite/) or push @scenario_failures, $scenario;
        }, 120;
    }
    if (@scenario_failures) {
        die "Some test scenarios failed: @scenario_failures";
    }
}

1;
# vim: set sw=4 et:
