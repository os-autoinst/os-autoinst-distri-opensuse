use strict;
use base "consoletest";
use testapi;
use ttylogin;

sub run() {
    my $self = shift;
    become_root;
    my $script = <<EOS;

# comment
systemctl stop packagekit.service || :
echo -e "\n\n\n"
zypper -n in a2ps
curl https://www.suse.com > /tmp/suse.html
a2ps -o /tmp/suse.ps /tmp/suse.html
EOS

    validate_script_output $script, sub { m/saved into the file/ || m/Total:./ }, 20;
    $self->clear_and_verify_console;
    script_run('exit');
}

1;
#vim: set sw=4 et:
