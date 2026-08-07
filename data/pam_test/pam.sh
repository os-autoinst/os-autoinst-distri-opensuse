#!/usr/bin/env bats
# pam-test tool from the url https://github.com/pbrezina/pam-test

USER_NOR='pamtest'
USER_NOR_PW='pamtest'
USER_PAM_DES='tstpamunix_des'
USER_PAM_DES_PW='0aXKZztA.d1KY'
USER_PAM_BIG='tstpamunix_big'
USER_PAM_BIG_PW='0aXKZztA.d1KYIuFXArmd2jU'
USER_ERR='pamtestx'
USER_ERR_PW='pamtestxx'
ROOT='root'
ROOT_PW='ROOT_PASSWORD'

## Check if the first version is equal or greater than the required version
# comes from graphicsmagick/test.sh duplicated code to be handled by poo#205362
# e.g version_or_higher "1.3.33" "1.3.28" returns true
function version_or_higher() {
  local version="${1:-0}"
  local required="${2:-0}"

  zypper vcmp "$version" "$required" >/dev/null 2>&1
  local rc=$?

  [ "$rc" -eq 0 ] || [ "$rc" -eq 11 ]
}

PAM_VERSION=$(rpm -q pam --qf '%{VERSION}')
SHADOW_VERSION=$(rpm -q shadow --qf '%{VERSION}')

setup() {
    # the dir /etc/pam.d/pam_test is static in the tool pam-test
    cp ./pam_test /etc/pam.d/pam_test
    mkdir -p /etc/security
    for file in access.conf time.conf group.conf limits.conf; do
      if [ ! -f /etc/security/$file ]; then
         cp /usr/etc/security/$file /etc/security/$file
      else
         cp /etc/security/$file /etc/security/$file.bak
      fi
    done
}

teardown() {
    rm -f /etc/pam.d/pam_test
    for file in access.conf time.conf group.conf limits.conf; do
      if [ -f /etc/security/$file.bak ]; then
        mv /etc/security/$file.bak /etc/security/$file
      else
        rm /etc/security/$file
      fi
    done
}

@test "prepare for next cases" {
    useradd -m -d /home/$USER_NOR -g users $USER_NOR
    echo $USER_NOR:$USER_NOR_PW | chpasswd
    # 'pamunix0' was encypted to '0aXKZztA.d1KY', '0a' is salt.
    useradd -p "$USER_PAM_DES_PW" "$USER_PAM_DES"
    # 'pamunix01' was encypted to '0aXKZztA.d1KYIuFXArmd2jU', '0a' is salt.
    useradd -p "$USER_PAM_BIG_PW" "$USER_PAM_BIG"
}

# This part about "login"
@test "general authentication -- with correct passwd" {
    echo "$USER_NOR_PW" | pam_test auth $USER_NOR
}

@test "general authentication -- with incorrect passwd" {
    run bash -c "echo -en '$USER_ERR_PW' | pam_test auth $USER_NOR"
    [ "$status" -ne 0 ]
}

@test "general authentication -- with incorrect user" {
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_ERR"
    [ "$status" -ne 0 ]
}

@test "deny access if too many attempts fail" {
    if version_or_higher "$PAM_VERSION" "1.5.0"; then
        skip
    fi
    sed -i '/^auth/i\auth required pam_tally2.so onerr=fail deny=1 unlock_time=10' /etc/pam.d/pam_test
    sleep 1    # poo#157009

    run bash -c "echo -en '$USER_ERR_PW' | pam_test auth $USER_NOR" # error password triggers this case
    [ "$status" -ne 0 ]
    sleep 2 # this time is less than 10s
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    [ "$status" -ne 0 ]
    sleep 30
    echo -en "$USER_NOR_PW" | pam_test auth $USER_NOR
}

@test "check for valid login shell" {
    sed -i '/^account/i\account required pam_shells.so' /etc/pam.d/pam_test

    bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    mv /etc/shells /etc/shells.bak && touch /etc/shells
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    mv /etc/shells.bak /etc/shells
    [ "$status" -ne 0 ]
}

# This part about "password"
@test "set a short invalid password" {
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\nsuse\nsuse' | passwd"
    [ "$status" -ne 0 ]
}

@test "set a simplistic/systematic invalid password" {
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\nabcd1234\nabcd1234' | passwd"
    [ "$status" -ne 0 ]
}

@test "set a specific password" {
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n!!\n!!' | passwd"
    [ "$status" -ne 0 ]
}

@test "encrypt a password with DES" {
    echo -en 'pamunix0' | pam_test auth $USER_PAM_DES
    run bash -c "echo -en 'pamunix' | pam_test auth $USER_PAM_DES"
    [ "$status" -ne 0 ]
    echo -en 'pamunix0_xxxx' | pam_test auth $USER_PAM_DES
}

@test "encrypt a password with bigcrypt" {
    echo -en 'pamunix01' | pam_test auth $USER_PAM_BIG
    run bash -c "echo -en 'pamunix0' | pam_test auth $USER_PAM_BIG"
    [ "$status" -ne 0 ]
    run bash -c "echo -en 'pamunix01_xxxx' | pam_test auth $USER_PAM_BIG"
    [ "$status" -ne 0 ]
}

@test "check password change minimum days handling" {
    if version_or_higher "$SHADOW_VERSION" "4.20" ; then
        run chage -m 10000 $USER_NOR
        [ "$status" -eq 2 ]
        echo "chage doesn't accept -m flag anymore"
        skip "Not supported on shadow >= 4.20"
    fi
    chage -m 10000 $USER_NOR
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\nSu135@se\nSu135@se' | passwd"
    chage -m 0 $USER_NOR
    [[ "$output" =~ "You must wait longer to change your password" ]]
}

@test "set a complex password" {
    if version_or_higher "$PAM_VERSION" "1.5.0"; then
        skip
    fi
    pam-config -a --cracklib --cracklib-retry=1 --cracklib-minlen=8 --cracklib-dcredit=-1 --cracklib-ucredit=-1 --cracklib-lcredit=-1 --cracklib-ocredit=-1
    
    # the length of password is less than 8
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nGe13r@n\nGe13r@n' | passwd"
    output01="$output"

    # the password is lack of uppercase
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nge135r@n\nge135r@n' | passwd"
    output02="$output"

    # the password is lack of lowercase 
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nGE135R@N\nGE135R@N' | passwd"
    output03="$output"

    # the password is lack of digits
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nGeaaar@n\nGeaaar@n' | passwd"
    output04="$output"

    # the password is lack of special characters
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nGe135r7n\nGe135r7n' | passwd"
    output05="$output"

    # the password is conform to rules
    run su - $USER_NOR -c "echo -en '$USER_NOR_PW\nGe135r@n\nGe135r@n' | passwd"
    output06="$output"

    pam-config -a --cracklib --cracklib-retry --cracklib-minlen --cracklib-dcredit --cracklib-ucredit --cracklib-lcredit --cracklib-ocredit
    echo $USER_NOR:$USER_NOR_PW | chpasswd
    [[ "$output01" =~ "BAD PASSWORD" ]] && [[ "$output02" =~ "BAD PASSWORD" ]]
    [[ "$output03" =~ "BAD PASSWORD" ]] && [[ "$output04" =~ "BAD PASSWORD" ]]
    [[ "$output05" =~ "BAD PASSWORD" ]] && [[ "$output06" =~ "password updated successfully" ]]
}

# This part "invalid access"
@test "deny services based on an arbitrary file" {
    sed -i '/^auth/i\auth requisite pam_listfile.so item=user sense=deny file=/etc/deny' /etc/pam.d/pam_test
    touch /etc/deny
    echo "$USER_NOR" >> /etc/deny

    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    rm -f /etc/deny
    [ "$status" -ne 0 ]
}

@test "prevent non-root users from login" {
    sed -i '/^auth/i\auth requisite pam_nologin.so' /etc/pam.d/pam_test
    touch /etc/nologin

    bash -c "echo -en '$ROOT_PW' | pam_test auth $ROOT"
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    rm -f /etc/nologin
    [ "$status" -ne 0 ]
}

@test "logdaemon style login access control" {
    echo "-:ALL EXCEPT $USER_NOR :LOCAL" >> /etc/security/access.conf
    pam-config -a --access --access-nodefgroup

    echo -en "$USER_NOR_PW" | pam_test auth $USER_NOR
    run bash -c "echo -en '$ROOT_PW' | pam_test auth $ROOT"
    pam-config -d --access
    [ "$status" -ne 0 ]
}

@test "test account characteristics -- deny users in users group" {
    sed -i '/^auth/i\auth required pam_succeed_if.so user notingroup users' /etc/pam.d/pam_test
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    [ "$status" -ne 0 ]
}

@test "test account characteristics -- deny users with uid > 10000" {
    sed -i '/^auth/i\auth required pam_succeed_if.so uid > 10000' /etc/pam.d/pam_test
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    [ "$status" -ne 0 ]
}

@test "time controled access" {
    sed -i '/^account/i\account required pam_time.so' /etc/pam.d/pam_test
    echo "*;*;$USER_NOR;!Al0000-2400" >> /etc/security/time.conf
    run bash -c "echo -en '$USER_NOR_PW' | pam_test auth $USER_NOR"
    [ "$status" -ne 0 ]
}

# The extra tests
@test "modify group access" {
    echo "*;*;$USER_NOR;Al0000-2400;wheel" >> /etc/security/group.conf
    pam-config -a --group
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'id -Gn'"
    pam-config -d --group
    [[ "$output" =~ "wheel" ]]
}

@test "limit resources -- maximum number of processes" {
    echo "$USER_NOR hard nproc 0" >> /etc/security/limits.conf
    run su - $USER_NOR
    [[ "$output" =~ "Resource temporarily unavailable" ]]
}

@test "limit resources -- limits the core file size" {
    echo '* soft core 1' >> /etc/security/limits.conf
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'prlimit -c'"
    [[ "$output" =~ "1024" ]]
}

@test "limit resources -- maximum number of open files" {
    echo '* hard nofile 512' >> /etc/security/limits.conf
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'prlimit -n'"
    [[ "$output" =~ files[[:space:]]*512[[:space:]]*512 ]]
}

@test "limit resources -- maximum number of processes in users group" {
    echo '@users soft nproc 20' >> /etc/security/limits.conf
    echo '@users hard nproc 50' >> /etc/security/limits.conf
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'prlimit -u'"
    [[ "$output" =~ processes[[:space:]]*20[[:space:]]*50 ]]
}

@test "limit resources -- maximum number of logins" {
    echo '@users - maxlogins 0' >> /etc/security/limits.conf
    run bash -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'prlimit' 2>&1"
    [[ "$output" =~ "cannot open session: Permission denied" ]]
}

@test "limit resources -- maximum nice priority" {
    echo '* soft nice 19' >> /etc/security/limits.conf
    echo '* hard nice -20' >> /etc/security/limits.conf
    run su - $USER_NOR -c "echo -ne '$USER_NOR_PW\n' | su - $USER_NOR -c 'prlimit -e'"
    [[ "$output" =~ raise[[:space:]]*1[[:space:]]*40 ]]
}

@test "clean up" {
    userdel -r $USER_NOR
    userdel -r $USER_PAM_DES
    userdel -r $USER_PAM_BIG
}
