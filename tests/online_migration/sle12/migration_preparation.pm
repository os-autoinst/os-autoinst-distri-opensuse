use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # add migration repo
    my $script = "zypper ar -f ".get_var('MIGRATION_REPO')." migration"."\n";
    validate_script_output $script, sub {m/successfully added/};

    # dup from migration repo
    assert_script_run "zypper --gpg-auto-import-keys refresh";
    script_run "zypper -n dup --from migration | tee /dev/$serialdev";
    wait_serial qr/^There are some running programs that might use files/m, 200;

    # install yast2 migration or zypper migration plugin
    assert_script_run "zypper -n in yast2-migration" if (get_var('MIGRATION_METHOD') eq 'yast');
    assert_script_run "zypper -n in zypper-migration-plugin" if (get_var('MIGRATION_METHOD') eq 'zypper');
}

sub test_flags {
    return { 'fatal' => 1, 'important' => 1};
}

1;
# vim: set sw=4 et:
