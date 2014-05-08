use base "basetest";
use bmwqemu;

sub is_applicable() { 0 }

sub run() {
    my $self = shift;
    script_sudo("/sbin/yast2 ca_mgm");
    waitstillimage( 12, 90 );
    send_key "alt-c", 1;    # create root CA
    type_string "autoinstCA\tsusetest.zq1.de\t\t\t\tOrg\tOU\topenQAserver\tfranconia\t\b\b\bGermany";
    send_key "alt-n", 1;
    type_string "$password\t$password";
    send_key "alt-n", 1;
    send_key "alt-t", 1;    # create CA

    if (1) {
        send_key "alt-e";    # enter CA
        type_string $password;
        send_key "alt-o";    # OK
        send_key "alt-e";    # cErtificates
        send_key "alt-a";    # add
        send_key "ret", 1;     # Server cert
        type_string "susetest.zq1.de";
        send_key "alt-n", 1;
        send_key "alt-u";     # Use CA pw
        send_key "alt-n", 1;
        send_key "alt-t", 1;    # creaTe cert

        send_key "alt-x";     # eXport
        send_key "down";
        send_key "down";
        send_key "ret", 1;      # Export as Common Server Certificate
        $self->check_screen();
        sleep 1;
        send_key "alt-o";     # hostname warning - might or might not be needed
        send_key "alt-p", 1;    # select PW field
        type_string $password;
        send_key "alt-o";    # OK
        send_key "alt-o";     # OK "has been written"
                             # files are in /etc/ssl/servercerts/server*

        send_key "alt-o";     # OK

    }

    send_key "alt-f", 1;        # finish
    script_run('echo $?');
    script_run('wget http://openqa.opensuse.org/opensuse/qatests/imapcert.sh');
    script_sudo('bash -x imapcert.sh');
}

1;
# vim: set sw=4 et:
