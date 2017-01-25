package susedistribution;
use base 'distribution';
use serial_terminal ();
use strict;

# Base class for all openSUSE tests

# don't import script_run - it will overwrite script_run from distribution and create a recursion
use testapi qw(send_key %cmd assert_screen check_screen check_var get_var
  match_has_tag set_var type_password type_string wait_idle wait_serial
  mouse_hide send_key_until_needlematch record_soft_failure
  wait_still_screen wait_screen_change);


sub handle_password_prompt {
    if (!get_var("LIVETEST") && !get_var('LIVECD')) {
        assert_screen "password-prompt";
        type_password;
        send_key('ret');
    }
}

sub init() {
    my ($self) = @_;

    $self->SUPER::init();
    $self->init_cmd();
    $self->init_consoles();
}

sub init_cmd() {
    my ($self) = @_;

    ## keyboard cmd vars
    %testapi::cmd = qw(
      next alt-n
      xnext alt-n
      install alt-i
      update alt-u
      finish alt-f
      accept alt-a
      ok alt-o
      continue alt-o
      createpartsetup alt-c
      custompart alt-c
      addpart alt-d
      donotformat alt-d
      addraid alt-i
      add alt-a
      raid0 alt-0
      raid1 alt-1
      raid5 alt-5
      raid6 alt-6
      raid10 alt-i
      mountpoint alt-m
      filesystem alt-s
      expertpartitioner alt-e
      resize alt-i
      acceptlicense alt-a
      instdetails alt-d
      rebootnow alt-n
      otherrootpw alt-s
      noautologin alt-a
      change alt-c
      software s
      package p
      bootloader b
    );

    if (check_var('INSTLANG', "de_DE")) {
        $testapi::cmd{next}            = "alt-w";
        $testapi::cmd{createpartsetup} = "alt-e";
        $testapi::cmd{custompart}      = "alt-b";
        $testapi::cmd{addpart}         = "alt-h";
        $testapi::cmd{finish}          = "alt-b";
        $testapi::cmd{accept}          = "alt-r";
        $testapi::cmd{donotformat}     = "alt-n";
        $testapi::cmd{add}             = "alt-h";

        #	$testapi::cmd{raid6}="alt-d"; 11.2 only
        $testapi::cmd{raid10}      = "alt-r";
        $testapi::cmd{mountpoint}  = "alt-e";
        $testapi::cmd{rebootnow}   = "alt-j";
        $testapi::cmd{otherrootpw} = "alt-e";
        $testapi::cmd{change}      = "alt-n";
        $testapi::cmd{software}    = "w";
    }
    if (check_var('INSTLANG', "es_ES")) {
        $testapi::cmd{next} = "alt-i";
    }
    if (check_var('INSTLANG', "fr_FR")) {
        $testapi::cmd{next} = "alt-s";
    }
    ## keyboard cmd vars end
}

sub x11_start_program($$$) {
    my ($self, $program, $timeout, $options) = @_;
    # enable valid option as default
    $options->{valid} //= 1;
    send_key "alt-f2";
    mouse_hide(1);
    if (!check_screen("desktop-runner", $timeout)) {
        # if "desktop-runner" not found send alt-f2 three times with 10 seconds timeout
        record_soft_failure 'bsc#978027';
        send_key_until_needlematch 'desktop-runner', 'alt-f2', 3, 10;
    }
    type_string $program;
    wait_idle 5;
    if ($options->{terminal}) {
        send_key('alt-t');
        sleep 3;
    }
    send_key('ret');
    wait_still_screen unless $options->{no_wait};
    # lrunner has auto-completion feature, sometimes it causes high load while
    # typing and the following 'ret' fails to work
    # make sure desktop runner executed and closed when have had valid value
    # exec x11_start_program( $program, $timeout, { valid => 1 } );
    if ($options->{valid}) {
        for (1 .. 3) {
            last unless check_screen "desktop-runner-border", 2;
            wait_screen_change {
                send_key "ret";
            };
        }
    }
}

sub ensure_installed {
    my ($self, $pkgs, %args) = @_;
    my $pkglist = ref $pkgs eq 'ARRAY' ? join ' ', @$pkgs : $pkgs;
    $args{timeout} //= 90;

    testapi::x11_start_program("xterm");
    assert_screen('xterm');
    testapi::assert_script_sudo("chown $testapi::username /dev/$testapi::serialdev");
    my $retries = 5;    # arbitrary

    # make sure packagekit service is available
    testapi::assert_script_sudo('systemctl is-active -q packagekit || (systemctl unmask -q packagekit ; systemctl start -q packagekit)');
    $self->script_run(
"for i in {1..$retries} ; do pkcon install $pkglist && break ; done ; RET=\$?; echo \"\n  pkcon finished\n\"; echo \"pkcon-\${RET}-\" > /dev/$testapi::serialdev",
        0
    );
    my @tags = qw(Policykit Policykit-behind-window pkcon-proceed-prompt pkcon-finished);
    while (1) {
        last unless @tags;
        my $ret = check_screen(\@tags, $args{timeout});
        last unless $ret;
        last if (match_has_tag('pkcon-finished'));
        if (match_has_tag('Policykit')) {
            type_password;
            send_key("ret", 1);
            @tags = grep { $_ ne 'Policykit' } @tags;
            @tags = grep { $_ ne 'Policykit-behind-window' } @tags;
            next;
        }
        if (match_has_tag('Policykit-behind-window')) {
            send_key("alt-tab");
            sleep 3;
            next;
        }
        if (match_has_tag('pkcon-proceed-prompt')) {
            send_key("y");
            send_key("ret");
            @tags = grep { $_ ne 'pkcon-proceed-prompt' } @tags;
            next;
        }
    }
    wait_serial('pkcon-0-', 27) || die "pkcon install did not succeed";
    send_key("alt-f4");    # close xterm
}

sub script_sudo($$) {
    my ($self, $prog, $wait) = @_;

    my $str = time;
    if ($wait > 0) {
        $prog = "$prog; echo $str-\$?- > /dev/$testapi::serialdev";
    }
    type_string "clear\n";    # poo#13710
    type_string "su -c \'$prog\'\n";
    handle_password_prompt;
    if ($wait > 0) {
        return wait_serial("$str-\\d+-");
    }
    return;
}

sub set_standard_prompt {
    my ($self, $user) = @_;
    $user ||= $testapi::username;
    if ($user eq 'root') {
        # set standard root prompt
        type_string "PS1='# '\n";
    }
    else {
        type_string "PS1='\$ '\n";
    }
}

sub become_root {
    my ($self) = @_;

    $self->script_sudo('bash', 0);
    type_string "whoami > /dev/$testapi::serialdev\n";
    wait_serial("root", 10) || die "Root prompt not there";
    type_string "cd /tmp\n";
    $self->set_standard_prompt('root');
    type_string "clear\n";
}

# initialize the consoles needed during our tests
sub init_consoles {
    my ($self) = @_;

    # avoid complex boolean logic by setting interim variables
    if (check_var('BACKEND', 'svirt')) {
        if (check_var('ARCH', 's390x')) {
            set_var('S390_ZKVM', 1);
        }
    }

    if (check_var('BACKEND', 'qemu')) {
        $self->add_console('root-virtio-terminal', 'virtio-terminal', {});
    }

    if (check_var('BACKEND', 'qemu') || check_var('BACKEND', 'ipmi') || check_var('BACKEND', 'generalhw')) {
        $self->add_console('install-shell', 'tty-console', {tty => 2});
        $self->add_console('installation',  'tty-console', {tty => check_var('VIDEOMODE', 'text') ? 1 : 7});
        $self->add_console('root-console',  'tty-console', {tty => 2});
        $self->add_console('user-console',  'tty-console', {tty => 4});
        $self->add_console('log-console',   'tty-console', {tty => 5});
        $self->add_console('x11',           'tty-console', {tty => 7});
    }

    # svirt backend, except s390x ARCH
    if (!get_var('S390_ZKVM') and check_var('BACKEND', 'svirt')) {
        my $hostname = get_var('VIRSH_GUEST');
        my $port = get_var('VIRSH_INSTANCE', 1) + 5900;

        $self->add_console(
            'sut',
            'vnc-base',
            {
                hostname => $hostname,
                port     => $port,
                password => $testapi::password
            });
        $self->add_console('install-shell', 'tty-console', {tty => 2});
        $self->add_console('installation',  'tty-console', {tty => check_var('VIDEOMODE', 'text') ? 1 : 7});
        $self->add_console('root-console',  'tty-console', {tty => 2});
        $self->add_console('user-console',  'tty-console', {tty => 4});
        $self->add_console('log-console',   'tty-console', {tty => 5});
        $self->add_console('x11',           'tty-console', {tty => 7});
    }

    if (check_var('BACKEND', 's390x') || get_var('S390_ZKVM')) {
        my $hostname = get_var('VIRSH_GUEST');

        if (check_var('BACKEND', 's390x')) {

            # expand the S390 params
            my $s390_params = get_var("S390_NETWORK_PARAMS");
            my $s390_host = get_var('S390_HOST') or die;
            $s390_params =~ s,\@S390_HOST\@,$s390_host,g;
            set_var("S390_NETWORK_PARAMS", $s390_params);

            ($hostname) = $s390_params =~ /Hostname=(\S+)/;
        }

        if (check_var("VIDEOMODE", "text")) {    # adds console for text-based installation on s390x
            $self->add_console(
                'installation',
                'ssh-xterm',
                {
                    hostname => $hostname,
                    password => $testapi::password,
                    user     => 'root'
                });
        }
        elsif (check_var("VIDEOMODE", "ssh-x")) {
            $self->add_console(
                'installation',
                'ssh-xterm',
                {
                    hostname => $hostname,
                    password => $testapi::password,
                    user     => 'root',
                    gui      => 1
                });
        }
        else {
            $self->add_console(
                'installation',
                'vnc-base',
                {
                    hostname => $hostname,
                    port     => 5901,
                    password => $testapi::password
                });
        }
        $self->add_console(
            'x11',
            'vnc-base',
            {
                hostname => $hostname,
                port     => 5901,
                password => $testapi::password
            });
        $self->add_console(
            'iucvconn',
            'ssh-iucvconn',
            {
                hostname => $hostname,
                password => $testapi::password
            });

        $self->add_console(
            'install-shell',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
        $self->add_console(
            'root-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
        $self->add_console(
            'user-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => $testapi::username
            });
        $self->add_console(
            'log-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
    }

    return;
}

# callback whenever a console is selected for the first time
sub activate_console {
    my ($self, $console) = @_;

    if ($console eq 'install-shell' && get_var('BACKEND', 'qemu')) {
        if (get_var("LIVECD")) {
            # LIVE CDa do not run inst-consoles as started by inst-linux (it's regular live run, auto-starting yast live installer)
            assert_screen "text-login", 10;
            # login as root, who does not have a password on Live-CDs
            type_string "root\n";
            sleep 1;
        }
        else {
            assert_screen "inst-console";
        }
    }

    $console =~ m/^(\w+)-(console|virtio-terminal)/;
    my ($name, $user, $type) = ($1, $1, $2);
    if ($name eq 'user') {
        $user = $testapi::username;
    }
    elsif ($name eq 'log') {
        $user = 'root';
    }

    if ($type eq 'console') {
        # different handling for ssh consoles
        if (check_var('BACKEND', 's390x') || get_var('S390_ZKVM')) {
            # different console-behaviour for s390x
            type_string("su - $user\n") unless ($user eq 'root');
        }
        else {
            my $nr = 4;
            $nr = 2 if ($name eq 'root');
            $nr = 5 if ($name eq 'log');
            # we need to wait more than five seconds here to pass the idle timeout in
            # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
            assert_screen(["tty$nr-selected", "text-logged-in-$user", "text-login"], 60);
            if (match_has_tag("tty$nr-selected") or match_has_tag("text-login")) {
                type_string "$user\n";
                handle_password_prompt;
            }
        }
        assert_screen "text-logged-in-$user";
        $self->set_standard_prompt($user);

        # On s390x 'setterm' binary is not present as there's no linux console
        if (!check_var('ARCH', 's390x')) {
            # Disable console screensaver
            $self->script_run("setterm -blank 0");
        }
    }
    elsif ($type eq 'virtio-terminal') {
        serial_terminal::login($user);
    }
    elsif ($console eq 'svirt') {
        $self->set_standard_prompt('root');
    }
}

1;
# vim: set sw=4 et:
