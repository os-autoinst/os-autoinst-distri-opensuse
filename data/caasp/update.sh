#!/usr/bin/env bash
set -exuo pipefail

# Fake update repositories for QA tests
# 3.0 -> 3.0 http://download.suse.de/ibs/Devel:/CASP:/3.0:/ControllerNode:/TestUpdate/standard/Devel:CASP:3.0:ControllerNode:TestUpdate.repo

# On success returns 0 or 100 if reboot is required
usage() {
    echo "Usage: $0
        [-s $REPO] Setup all nodes with update REPO
        [-u] Update all nodes
        [-c] Check that update was applied
        [-n] Install new package
        [-i] Install package
        [-t] Test if update is needed
        [-r] Just reboot cluster test" 1>&2
    exit 1
}

while getopts "s:curnti" opt; do
case $opt in
    s)
        SETUP=$OPTARG
        ;;
    u)
        UPDATE=true
        ;;
    c)
        CHECK=true
        ;;
    r)
        REBOOT=true
        ;;
    n)
        NEWPKG=true
        ;;
    i)
        INSTALL=true
        ;;
    t)
        TEST=true
        ;;
    \?)
        usage
        ;;
    :)
        echo "Option -$opt requires an argument." >&2
        usage
        ;;
esac
done

# Make sure that Salt master container is running
until docker ps | grep salt-master
do
    echo "salt master hasn't started yet. Trying again..."
    sleep 5
done

# Set up some shortcuts
DEFAULT_TARGET='roles:(admin|kube-(master|minion))'
SALT_MASTER=$(docker ps | grep salt-master | awk '{print $1}')

# Run salt command (needs target): $srun '*' test.ping
srun="docker exec -i $SALT_MASTER salt --batch 11"
# Run bash command (on all nodes): $runner 'zypper lr'
runner="$srun -P $DEFAULT_TARGET cmd.run"

# Manually Refresh the Grains (or wait up to 10 minutes)
function refresh_grains {
    $srun '*' saltutil.refresh_grains
}

if [ ! -z "${SETUP:-}" ]; then
    $runner 'zypper mr -d -l'
    $runner 'echo -e "[main]\nvendors = suse,opensuse,obs://build.suse.de,obs://build.opensuse.org" > /etc/zypp/vendors.d/vendors.conf'
    $runner "zypper ar --refresh --no-gpgcheck $SETUP UPDATE"
    $runner "zypper lr -U"

elif [ ! -z "${TEST:-}" ]; then
    # Skip updating if the whole maintenance incident was just a single new package
    if [ -f new_package.txt ]; then
        # Helpful for debugging maintenance packaging problems
        echo "new_package.txt"
        cat new_package.txt
        echo
        echo "qam_packages.txt"
        cat qam_packages.txt
        if cmp --silent new_package.txt qam_packages.txt; then
            # Corner case:
            echo "The whole qam incident is just one single new package"
            exit 110
        fi
    fi

elif [ ! -z "${UPDATE:-}" ]; then

    # Manually Trigger Transactional Update (or wait up to 24 hours for it run by itself)
    $runner 'systemctl disable --now transactional-update.timer'
    $runner '/usr/sbin/transactional-update cleanup dup reboot'

    refresh_grains
    exit 100

elif [ ! -z "${CHECK:-}" ]; then
    # caasp-container-manifests
    # check installed version
    zypper if --provides caasp-container-manifests | grep 100.0.0
    # check there is a "foo:bar" in the public manifests
    grep "foo: bar" /usr/share/caasp-container-manifests/manifests/public.yaml
    # check the change has been "activated"
    grep "foo: bar" /etc/kubernetes/manifests/public.yaml
    
    # container-feeder
    # check installed version
    zypper if --provides container-feeder | grep 100.0.0
    # check changes in README - zypper config changed to exclude doc
    # grep "This image has been updated fine" /usr/share/doc/packages/container-feeder/README.md
    
    # kubernetes-salt
    # check version
    zypper if --provides kubernetes-salt | grep 100.0
    # check etc/motd in a minion node
    COMMAND="grep 'This has been updated fine' /etc/motd"
    $srun -P "roles:kube-minion" cmd.run "$COMMAND" | grep 'This has been updated fine'
    
    # velum image
    # check version
    rpm -q sles12-velum-image | grep sles12-velum-image-100.0.0.*
    # check image has been loaded
    image_id=$(docker images | grep sles12/velum | grep 100.0 | head -1 | awk '{print $3}')
    container_id=$(docker ps | grep $image_id | grep dashboard | awk '{print $1}')
    # check change is in the image
    docker exec -i $container_id ls /IMAGE_UPDATED

elif [ ! -z "${REBOOT:-}" ]; then
    docker exec -d $SALT_MASTER salt -P "roles:kube-(master|minion)" system.reboot

elif [ ! -z "${NEWPKG:-}" ]; then
    # Fetch all the packages included for this QAM incident
    zypper -q --plus-content UPDATE pa -R UPDATE | awk -F'|' 'NR>2 {print $3}' | cut -c 2- > qam_packages.txt

    # Check if there are any packages included into the QAM incident that are not pre-installed
    reboot_required=0
    while read pkg; do
        if ! rpm -q $pkg; then
            echo "$pkg " >> not_installed.txt
            reboot_required=1
        fi
    done < qam_packages.txt

    if [ ${reboot_required} -eq 1 ]; then
        # Disable the update repo, so to check if this package is old or new
        $runner "zypper mr -d UPDATE"
        while read pkg; do
            if ! zypper se $pkg; then
                echo "$pkg " >> new_package.txt
            fi
        done < not_installed.txt

        if [ -f new_package.txt ]; then

            # Enable the update repo to install the new package
            $runner "zypper mr -e UPDATE"
            $runner "zypper lr UPDATE | grep Enabled | grep Yes"
            echo "The following new packages are going to be installed: $(cat new_package.txt)"

            # Install the packages
            $runner "/usr/sbin/transactional-update salt pkg install -y $(cat new_package.txt)"
            refresh_grains

            # Orchestrate the reboot via Velum to complete the installation
            rm not_installed.txt
            exit 100
        fi
    fi

elif [ ! -z "${INSTALL:-}" ]; then
    # In case there was a new package, it must be installed by now. Clear the state.
    if [ -f not_installed.txt ]; then
         rm not_installed.txt
    fi
    # Check if there are any packages included into the QAM incident that are not pre-installed
    reboot_required=0
    while read pkg; do
        if ! rpm -q $pkg; then
            echo "$pkg " >> not_installed.txt
            reboot_required=1
        fi
    done < qam_packages.txt

    if [ ${reboot_required} -eq 1 ]; then
        echo "The following packages are going to be installed: $(cat not_installed.txt)"

        # Disable the update repo, so it will install the released version of those
        $runner "zypper mr -d UPDATE"
        $runner "zypper lr UPDATE | grep Enabled | grep No"

        # Install the packages
        $runner "/usr/sbin/transactional-update salt pkg install -y $(cat not_installed.txt)"
        refresh_grains

        # Enable the update repo
        $runner "zypper mr -e UPDATE"
        $runner "zypper lr UPDATE | grep Enabled | grep Yes"

        # Orchestrate the reboot via Velum to complete the installation
        exit 100
    fi
fi

# Run with script_run0 or script_assert0
# Otherwise script_run "update.sh | tee $serialdev", checks exit status is from tee
exit 0
