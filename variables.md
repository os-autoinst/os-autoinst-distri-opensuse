
## Supported list of variables which control test suites

Below you can find the list of variables which control tests behavior, including schedule.
Please, find [os-autoinst backend variables](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc) which complement the list of variables below.

NOTE: This list is not complete and may contain outdated info. If you face such a case, please, create pull request with required changes.

For a better overview some domain-specific values have been moved to their own section:

* [Publiccloud](#publiccloud-specific-variables)
* [Wicked](#wicked-testsuite-specifc-variables)
* [xfstests](#xfstests-specific-variables)

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
`APACHE2_PKG` | string | `apache` | Apache2 package under test (e.g. `apache2` or `apache2-tls13`)
AARCH64_MTE_SUPPORTED | boolean | false     | Set to 1 if your machine supports Memory Tagging Extension (MTE)
ADDONS          | string    |               | Comma separated list of addons to be added using DVD. Also used to indicate addons in the SUT.
ADDONURL        | string    |               | Comma separated list of addons. Includes addon names to get url defined in ADDONURL_*. For example: ADDONURL=sdk,we ADDONURL_SDK=https://url ADDONURL_WE=ftp://url
ADDONURL_*      | string    |               | Define url for the addons list defined in ADDONURL
ASSERT_BSC1122804 | boolean | false | In some scenarios it is necessary to check if the mistyped full name still happens.
ASSERT_Y2LOGS   | boolean   | false         | If set to true, we will parse YaST logs after installation and fail test suite in case unknown errors were detected.
AUTOCONF        | boolean   | false         | Toggle automatic configuration
AUTOYAST        | string    |               | Full url to the AY profile or relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data). If value starts with `aytests/`, these profiles are provided by support server, source code is available in [aytests repo](https://github.com/yast/aytests-tests). If value is a folder ending in `/` rules and classes will be used.
AUTOYAST_PREPARE_PROFILE | boolean | false | Enable variable expansion in the autoyast profile.
AUTOYAST_VERIFY_TIMEOUT  | boolean | false | Enable validation of pop-up windows timeout.
AY_EXPAND_VARS | string | | Commas separated list of variable names to be expanded in the provided autoyast profile. For example: REPO_SLE_MODULE_BASESYSTEM,DESKTOP,... Provided variables will replace `{{VAR}}` in the profile with the value of given variable. See also `AUTOYAST_PREPARE_PROFILE`.
BASE_VERSION | string | | |
BETA | boolean | false | Enables checks and processing of beta warnings. Defines current stage of the product under test.
BCI_DEVEL_REPO | string | | This parameter is given to the bci-tests to inject a different SLE_BCI repository url to the container image instead of the default one. Used by `bci_test.pm`.
BCI_TEST_ENVS | string | | The list of environments to be tested, e.g. `base,init,dotnet,python,node,go,multistage`. Used by `bci_test.pm`. Use `-` to not schedule any BCI test runs.
BCI_TESTS_REPO | string | https://github.com/SUSE/BCI-tests.git | If set, use this instead of the standart BCI-Test repo (see default). Uses the same syntax as CASE_DIR, so to use branch `branch123` on that repo use e.g. https://github.com/SUSE/BCI-tests#branch123
BCI_TIMEOUT | string | | Timeout given to the command to test each environment. Used by `bci_test.pm`.
BCI_TARGET | string | ibs-cr | Container project to be tested. `ibs-cr` is the CR project, `ibs` is the released images project
BCI_SKIP | boolean | false | Switch to disable BCI test runs. Necessary for fine-granular test disablement
BCI_PREPARE | boolean | false | Launch the bci_prepare step again. Useful to re-initialize the BCI-Test repo when using a different BCI_TESTS_REPO
BCI_VIRTUALENV | boolean | false | Use a virtualenv for pip dependencies in BCI tests
BCI_OS_VERSION | string | | Set the environment variable OS_VERSION to this value, if present
BOOTLOADER | string | grub2 | Which bootloader is used by the image or will be selected during installation, e.g. `grub2`, `grub2-bls`, `systemd-boot`
BTRFS | boolean | false | Indicates btrfs filesystem. Deprecated, use FILESYSTEM instead.
BUILD | string  |       | Indicates build number of the product under test.
BUILDAH_STORAGE_DRIVER | string | | Storage driver used for buildah: vfs or overlay.
CASEDIR | string | | Path to the directory which contains tests.
CHECK_RELEASENOTES | boolean | false | Loads `installation/releasenotes` test module.
CHECKSUM_* | string | | SHA256 checksum of the * medium. E.g. CHECKSUM_ISO_1 for ISO_1.
CHECKSUM_FAILED | string | | Variable is set if checksum of installation medium fails to visualize error in the test module and not just put this information in the autoinst log file.
CONTAINER_RUNTIMES | string | | Container runtime to be used, e.g.  `docker`, `podman`, or both `podman,docker`. In addition, it is also used for other container tests, like  `kubectl`, `helm`, etc.
CONTAINERS_CGROUP_VERSION | string | | If defined, cgroups version to switch to
CONTAINERS_K3S_VERSION | string |  | If defined, install the provided version of k3s
CONTAINERS_NO_SUSE_OS | boolean | false | Used by main_containers to see if the host is different than SLE or openSUSE.
CONTAINERS_UNTESTED_IMAGES | boolean | false | Whether to use `untested_images` or `released_images` from `lib/containers/urls.pm`.
CONTAINERS_CRICTL_VERSION | string | v1.23.0 | The version of CriCtl tool.
CONTAINERS_NERDCTL_VERSION | string | 0.16.1 | The version of NerdCTL tool.
CONTAINERS_DOCKER_FLAVOUR | string | | Flavour of docker to install. Valid options are `stable` or undefined (for standard docker package)
HELM_CHART | string | | Helm chart under test. See `main_containers.pm` for supported chart types |
HELM_CONFIG | string | | Additional configuration file for helm |
CPU_BUGS | boolean | | Into Mitigations testing
DESKTOP | string | | Indicates expected DM, e.g. `gnome`, `kde`, `textmode`, `xfce`, `lxde`. Does NOT prescribe installation mode. Installation is controlled by `VIDEOMODE` setting
DEPENDENCY_RESOLVER_FLAG| boolean | false      | Control whether the resolve_dependecy_issues will be scheduled or not before certain modules which need it.
DEV_IMAGE | boolean | false | This setting is used to set variables properly when SDK or Development-Tools are required.
DISABLE_ONLINE_REPOS | boolean | false | Enables `installation/disable_online_repos` test module, relevant for openSUSE only. Test module explicitly disables online repos not to be used during installation.
DISABLE_SECUREBOOT | boolean | false | Disable secureboot in firmware of the SUT or in hypervisor's guest VM settings
DISABLE_SLE_UPDATES | boolean | false | Disables online updates for the installation.
DISTRI | string | | Defines distribution. Possible values: `sle`, `opensuse`, `microos`.
DOCRUN | boolean | false |
DUALBOOT | boolean | false | Enables dual boot configuration during the installation.
DUD | string | | Defines url or relative path to the DUD file if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data)
DUD_ADDONS | string | | Comma separated list of addons added using DUD.
DVD |||
ENCRYPT | boolean | false | Enables or indicates encryption of the disks. Can be combined with `FULL_LVM_ENCRYPT`, `ENCRYPT_CANCEL_EXISTING`, `ENCRYPT_ACTIVATE_EXISTING` and `UNENCRYPTED_BOOT`.
ENCRYPT_CANCEL_EXISTING | boolean | false | Used to cancel activation of the encrypted partitions |
SOFTLOCKUP_PANIC_DISABLED | boolean | false | Disables panicking on softlockup, provides a stack trace once a softlockup has been detected (see POO#50345)
ETC_PASSWD | string | | Sets content for /etc/passwd, can be used to mimic existing users. Is used to test import of existing users on backends which have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_SHADOW`.
ETC_SHADOW | string | | Sets content for /etc/shadow, can be used to mimic existing users. Is used to test import of existing users on backends which have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_PASSWD`.
EVERGREEN |||
EXIT_AFTER_START_INSTALL | boolean | false | Indicates that test suite will be finished after `installation/start_install` test module. So that all the test modules after this one will not be scheduled and executed.
EXPECTED_INSTALL_HOSTNAME | string | | Contains expected hostname YaST installer got from the environment (DHCP, 'hostname=', as a kernel cmd line argument)
EXTRABOOTPARAMS | string | | Concatenates content of the string as boot options applied to the installation bootloader.
EXTRABOOTPARAMS_BOOT_LOCAL | string | | Boot options applied during the boot process of a local installation.
EXTRABOOTPARAMS_LINE_OFFSET | integer | | Line offset for `linux` line in grub when `EXTRABOOTPARAMS_BOOT_LOCAL` is used.
EXTRABOOTPARAMS_DELETE_CHARACTERS | string | | Characters to delete from boot prompt.
EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET | string | | If specified, go back with the cursor until this needle is matched to delete characters from there. Needs EXTRABOOTPARAMS_BOOT_LOCAL and should be combined with EXTRABOOTPARAMS_DELETE_CHARACTERS.
EXTRATEST | boolean | false | Enables execution of extra tests, see `load_extra_tests`
FIRST_BOOT_CONFIG | string | combustion+ignition | The method used for initial configuration of MicroOS images. Possible values are: `combustion`, `ignition`, `combustion+ignition` and `wizard`. For ignition/combustion, the job needs to have a matching HDD attached.
FLAVOR | string | | Defines flavor of the product under test, e.g. `staging-.-DVD`, `Krypton`, `Argon`, `Gnome-Live`, `DVD`, `Rescue-CD`, etc.
FULLURL | string | | Full url to the factory repo. Is relevant for openSUSE only.
FULL_LVM_ENCRYPT | boolean | false | Enables/indicates encryption using lvm. boot partition may or not be encrypted, depending on the product default behavior.
FUNCTION | string | | Specifies SUT's role for MM test suites. E.g. Used to determine which SUT acts as target/server and initiator/client for iscsi test suite
GNU_COMPILERS_HPC_VERSION | string | | Define the gnu-N-compilers-hpc version to be tested.
GRUB_PARAM | string | | A semicolon-separated list of extra boot options. Adds 2 grub meny entries per each item in main grub (2nd entry is the "Advanced options ..." submenu). See `add_custom_grub_entries()`.
GRUB_BOOT_NONDEFAULT | boolean | false | Boot grub menu entry added by `add_custom_grub_entries` (having setup `GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU`, `GRUB_BOOT_NONDEFAULT=1` selects 3rd entry, which contains `debug_pagealloc=on`, `GRUB_BOOT_NONDEFAULT=2` selects 5th entry, which contains `ima_policy=tcb`). NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_FIRST_MENU | integer | | Select grub menu entry in main grub menu, used together with GRUB_SELECT_SECOND_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_SECOND_MENU | integer | | Select grub menu entry in secondary grub menu (the "Advanced options ..." submenu), used together with GRUB_SELECT_FIRST_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
HASLICENSE | boolean | true if SLE, false otherwise | Enables processing and validation of the license agreements.
HDDVERSION | string | | Indicates version of the system installed on the HDD.
HTTPPROXY  |||
HPC_WAREWULF_CONTAINER | string | | Set the container meant for warewulf test suite.
HPC_WAREWULF_CONTAINER_NAME | string | The OS name which is expected to run from HPC_WAREWULF_CONTAINER.
HPC_WAREWULF_CONTAINER_USERNAME | string | Defining username enables authentication for containers, needs valid HPC subscription on SCC for containers from registry.suse.com. If you want use default HPC subscription, just set same value as in SCC_EMAIL
_SECRET_HPC_WAREWULF_CONTAINER_PASSWORD | string | Password for container, needs valid HPC subscription on SCC for containers from registry.suse.com. If not specified it will use code from SCC_REGCODE_HPC 
INSTALL_KEYBOARD_LAYOUT | string | | Specify one of the supported keyboard layout to switch to during installation or to be used in autoyast scenarios e.g.: cz, fr
INSTALL_SOURCE | string | | Specify network protocol to be used as installation source e.g. MIRROR_HTTP
INSTALLATION_VALIDATION | string | | Comma separated list of modules to be used for installed system validation, should be used in combination with INSTALLONLY, to schedule only relevant test modules.
INSTALLONLY | boolean | false | Indicates that test suite conducts only installation. Is recommended to be used for all jobs which create and publish images
INSTLANG | string | en_US | Installation locale settings.
IPERF_REPO | string | | Link to repository with iperf tool for network performance testing. Currently used in Public Cloud Azure test
IPXE | boolean | false | Indicates ipxe boot.
IPXE_BOOT_FIXED | boolean | false | Indicates to ipxe boot fixed distribution independent on DISTRI and VERSION variables.
IPXE_BOOT_FIXED_DISTRI | string | sle | Sets distribution name for fixed ipxe boot.
IPXE_BOOT_FIXED_VERSION | string | 15-SP6 | Sets distribution version for fixed ipxe boot.
IPXE_SET_HDD_BOOTSCRIPT | boolean | false | Upload second IPXE boot script for booting from HDD after the installation boot script gets executed. This is a workaround for cases where the installer fails to switch default boot order to HDD boot. See also PXE_BOOT_TIME.
ISO_MAXSIZE | integer | | Max size of the iso, used in `installation/isosize.pm`.
IS_MM_SERVER | boolean | | If set, run server-specific part of the multimachine job
IS_MM_CLIENT | boolean | | If set, run client-specific part of the multimachine job
K3S_SYMLINK | string | | Can be 'skip' or 'force'. Skips the installation of k3s symlinks to tools like kubectl or forces the creation of symlinks
K3S_BIN_DIR | string | | If defined, install k3s to this provided directory instead of `/usr/local/bin/`
K3S_CHANNEL | string | | Set the release channel to pick the k3s version from. Options include "stable", "latest" and "testing"
KERNEL_FLAVOR | string | kernel-default | Set specific kernel flavor for test scenarios
KUBECTL_CLUSTER | string | | Defines the cluster used to test `kubectl`. Currently only `k3s` is supported.
KUBECTL_VERSION | string | v1.22.12 | Defines the kubectl version.
KEEP_DISKS | boolean | false | Prevents disks wiping for remote backends without snapshots support, e.g. ipmi, powerVM, zVM
KEEP_ONLINE_REPOS | boolean | false | openSUSE specific variable, not to replace original repos in the installed system with snapshot mirrors which are not yet published.
KEEP_PERSISTENT_NET_RULES | boolean | false | Keep udev rules 70-persistent-net.rules, which are deleted on backends with image support (qemu, svirt) by default.
LAPTOP |||
LIBC_LIVEPATCH | boolean | false | If set, run userspace livepatching tests
PATCH_BEFORE_MIGRATION | boolean | false | If set, patch the system before migration/upgrade
LINUX_BOOT_IPV6_DISABLE | boolean | false | If set, boots linux kernel with option named "ipv6.disable=1" which disables IPv6 from startup.
LINUXRC_KEXEC | integer | | linuxrc has the capability to download and run a new kernel and initrd pair from the repository.<br> There are four settings for the kexec option:<br> 0: feature disabled;<br> 1: always restart with kernel/initrd from repository (without bothering to check if it's necessary);<br>2: restart only if needed - that is, if linuxrc detects that the booted initrd is outdated (this is the default);<br>3: like kexec=2 but without user interaction.<br> *More details [here](https://en.opensuse.org/SDB:Linuxrc)*.
LIVECD | boolean | false | Indicates live image being used.
LIVE_INSTALLATION | boolean | false | If set, boots the live media and starts the builtin NET installer.
LIVE_UPGRADE | boolean | false | If set, boots the live media and starts the builtin NET installer in upgrade mode.
LIVETEST | boolean | false | Indicates test of live system.
LTP_COMMAND_FILE | string | | The LTP test command file (e.g. syscalls, cve)
LTP_COMMAND_EXCLUDE | string | | This regex is used to exclude tests from LTP command file.
LTP_KNOWN_ISSUES | string | | Used to specify a url for a json file with well known LTP issues. If an error occur which is listed, then the result is overwritten with softfailure.
LTP_REPO | string | | The repo which will be added and is used to install LTP package.
LTP_RUN_NG_BRANCH | string | master | Define the branch of the LTP_RUN_NG_REPO.
LTP_RUN_NG_REPO | string | https://github.com/metan-ucw/runltp-ng.git | Define the runltp-ng repo to be used. Default in publiccloud/run_ltp.pm is the upstream master branch from https://github.com/metan-ucw/runltp-ng.git.
LTP_PC_RUNLTP_ENV | string | empty | Contains eventual internal environment new parameters for `runltp-ng`, defined with the `--env` option, initialized in a column-separated string format: "PAR1=xxx:PAR2=yyy:...". By default it is empty, undefined.
LTP_TAINT_EXPECTED | integer | 0x80019801 | Bitmask of expected kernel taint flags.
LVM | boolean | false | Use lvm for partitioning.
LVM_THIN_LV | boolean | false | Use thin provisioning logical volumes for partitioning,
MACHINE | string | | Define machine name which defines worker specific configuration, including WORKER_CLASS.
MEDIACHECK | boolean | false | Enables `installation/mediacheck` test module.
MEMTEST | boolean | false | Enables `installation/memtest` test module.
MICRO_INSTALL_IMAGE_TARGET_DEVICE | string | /dev/sda | Target disk device for bare metal SL Micro installation.
MIRROR_{protocol} | string | | Specify source address
MM_MTU | integer | 1380 | Specifies the MTU to set in SUTs of MM tests usually started with `NICTYPE=tap`.
MOK_VERBOSITY | boolean | false | Enable verbosity feature of shim. Requires preinstalled `mokutil`.
MOZILLATEST |||
MOZILLA_NSS_DEVEL_REPO | string | | URL of the repository where to install the mozilla-nss packages from.
MU_REPOS_NO_GPG_CHECK | boolean | false | Use -G option in zypper when adding the repositores from OS_TEST_REPOS variable
NAME | string | | Name of the test run including distribution, build, machine name and job id.
NAMESERVER | string | | Can be used to specify a name server's IP or FQDN.
NET | boolean | false | Indicates net installation.
NETBOOT | boolean | false | Indicates net boot.
NETDEV | string | | Network device to be used when adding interface on zKVM.
NFSCLIENT | boolean | false | Indicates/enables nfs client in `console/yast2_nfs_client` for multi-machine test.
NFSSERVER | boolean | false | Indicates/enables nfs server in `console/yast2_nfs_server`.
NICEVIDEO |||
NICTYPE_USER_OPTIONS | string | | `hostname=myguest` causes a fake DHCP hostname 'myguest' provided to SUT. It is used as expected hostname if `EXPECTED_INSTALL_HOSTNAME` is not set.
NO_ADD_MAINT_TEST_REPOS | boolean | true |  Do not add again (and duplicate) repositories that were already added during install
NOAUTOLOGIN | boolean | false | Indicates disabled auto login.
NOIMAGES |||
NOLOGS | boolean | false | Do not collect logs if set to true. Handy during development.
NVIDIA_REPO | string | '' | Define the external repo for nvidia driver. Used by `nvidia.pm` module.
OCI_RUNTIME | string | '' | Define the OCI runtime to use in container tests, if set.
OPENSHIFT_CONFIG_REPO | string | '' | Git repo of the OpenShift configuration and packages needed by tests/containers/openshift_setup.pm. 
OPT_KERNEL_PARAMS | string | Specify optional kernel command line parameters on bootloader settings page of the installer.
PHUB_READY | boolean | true | Indicates PackageHub is available, it may be not ready in early development phase[Before Beta].
PERF_KERNEL | boolean | false | Enables kernel performance testing.
PERF_INSTALL | boolean | false | Enables kernel performance testing installation part.
PERF_SETUP | boolean | false | Enables kernel performance testing deployment part.
PERF_RUNCASE | boolean | false | Enables kernel performance testing run case part.
RMT_SERVER | string | Local server to be used in RMT registration.
SALT_FORMULAS_PATH | string | | Used to point to a tarball with relative path to [/data/yast2](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data/yast2) which contains all the needed files (top.sls, form.yml, ...) to support provisioning with Salt masterless mode.
PKGMGR_ACTION_AT_EXIT | string | "" | Set the default behavior of the package manager when package installation has finished. Possible actions are: close, restart, summary. If PKGMGR_ACTION_AT_EXIT is not set in openQA, test module will read the default value from /etc/sysconfig/yast2.
PXE_PRODUCT_NAME | string | false | Defines image name for PXE booting
PXE_BOOT_TIME | integer | 120 | Approximate time that IPMI worker needs to load and execute PXE boot payload. Should be set in the IPMI worker configuration.
QA_TESTSUITE | string | | Comma or semicolon separated a list of the automation cases' name, and these cases will be installed and triggered if you call "start_testrun" function from qa_run.pm
QAM_MINIMAL | string | "full" or "small" | Full is adding patterns x11, gnome-basic, base, apparmor in minimal/install_patterns test. Small is just base.
RAIDLEVEL | integer | | Define raid level to be configured. Possible values: 0,1,5,6,10.
REBOOT_TIMEOUT | integer | 0 | Set and handle reboot timeout available in YaST installer. 0 disables the timeout and needs explicit reboot confirmation.
REGISTRY | string | docker.io | Registry to pull third-party container images from
CONTAINER_IMAGE_VERSIONS | string | | List of comma-separated versions from `get_suse_container_urls()`
CONTAINER_IMAGE_TO_TEST | string | | Single URL string of a specific container image to test.
REGRESSION | string | | Define scope of regression testing, including ibus, gnome, documentation and other.
REMOTE_REPOINST | boolean | | Use linuxrc features to install OS from specified repository (install) while booting installer from DVD (instsys)
REPO_* | string | | Url pointing to the mirrored repo. REPO_0 contains installation iso.
RESCUECD | boolean | false | Indicates rescue image to be used.
RESCUESYSTEM | boolean | false | Indicates rescue system under test.
ROOTONLY | boolean | false | Request installation to create only the root account, no user account.
RESET_HOSTNAME| boolean | false | If set to true content of /etc/hostname file will be erased
SCC_DEBUG_SUSECONNECT | boolean | false | Set to pass debug flag to SUSEConnect
SCC_ADDONS | string | | Comma separated list of modules to be enabled using SCC/RMT.
SCC_DOCKER_IMAGE | string | | The content of /etc/zypp/credentials.d/SCCcredentials used by container-suseconnect-zypp zypper service in SLE base container images
SECURITY_MAC | string | "apparmor", "selinux" | MAC LSM to use with container tests.
SELECT_FIRST_DISK | boolean | false | Enables test module to select first disk for the installation. Is used for baremetal machine tests with multiple disks available, including cases when server still has previous installation.
ENABLE_SELINUX | boolean | false | Explicitly enable SELinux in transactional server environments.
SEPARATE_HOME | three-state | undef | Used for scheduling the test module where separate `/home` partition should be explicitly enabled (if `1` is set) or disabled (if `0` is set). If not specified, the test module is skipped.
SES5_CEPH_QA_HEALTH_OK | string | | URL for repo containing ceph-qa-health-ok package.
SKIP_CERT_VALIDATION | boolean | false | Enables linuxrc parameter to skip certificate validation of the remote source, e.g. when using self-signed https url.
SET_CUSTOM_PROMPT | boolean | false | Set a custom, shorter prompt in shells. Saves screen space but can take time to set repeatedly in all shell sessions.
SLE_PRODUCT | string | | Defines SLE product. Possible values: `sles`, `sled`, `sles4sap`. Is mainly used for SLE 15 installation flow.
SLURM_VERSION | string | | Defines slurm version (ex: 23_02) for installation. If not set, installation uses the base Slurm version.
SOFTFAIL_BSC1063638 | boolean | false | Enable bsc#1063638 detection.
STAGING | boolean | false | Indicates staging environment.
SPECIFIC_DISK | boolean | false | Enables installation/partitioning_olddisk test module.
SPLITUSR | boolean | false | Enables `installation/partitioning_splitusr` test module.
SUSEMIRROR | string | | Mirror url of the installation medium.
SYSAUTHTEST | boolean | false | Enable system authentication test (`sysauth/sssd`)
SYSCTL_IPV6_DISABLED | boolean | undef | Set automatically in samba_adcli tests when ipv6 is disabled
SYSTEMD_NSPAWN | boolean | 1 | Run systemd upstream tests in nspawn container rather than qemu
SYSTEMD_TESTSUITE | boolean | undef | Enable schedule of systemd upstream tests
SYSTEMD_UNIFIED_CGROUP | string | "yes", "no", "hybrid", "default" | systemd currently supports 3 (unified,legacy,hybrid) cgroups configurations
SCC_REGCODE_LTSS_SEC | string | | Defines SLES-LTSS-Extended-Security registration code.
TEST | string | | Name of the test suite.
TEST_CONTEXT | string | | Defines the class name to be used as the context instance of the test. This is used in the scheduler to pass the `run_args` into the loadtest function. If it is not given it will be undef.
TEST_TIME | integer | | Set time parameter for `iperf -t N` option. Used in Azure Public Cloud testing of Accelerated NICs
TOGGLEHOME | boolean | false | Changes the state of partitioning to have or not to have separate home partition in the proposal.
TUNNELED | boolean | false | Enables the use of normal consoles like "root-consoles" on a remote SUT while configuring the tunnel in a local "tunnel-console"
TYPE_BOOT_PARAMS_FAST | boolean | false | When set, forces `bootloader_setup::type_boot_parameters` to use the default typing interval.
UEFI | boolean | false | Indicates UEFI in the testing environment.
ULP_THREAD_COUNT | integer | 1000 | Number of threads to create in `ulp_threads` test module.
ULP_THREAD_SLEEP | integer | 100 | Sleep length after each thread loop iteration in `ulp_threads` module. High thread-to-CPU ratio needs longer sleep length.
UPGRADE | boolean | false | Indicates upgrade scenario.
USBBOOT | boolean | false | Indicates booting to the usb device.
USEIMAGES |||
VALIDATE_ETC_HOSTS | boolean | false | Validate changes in /etc/hosts when using YaST network module. Is used in yast2_lan and yast2_lan_restart test modules which test module in ncurses and x11 respectively.
VALIDATE_INST_SRC | boolean | false | Validate installation source in /etc/install.inf
VALIDATE_CHECKSUM | boolean | false | Validate checksum of the mediums. Also see CHECKSUM_*.
VERSION | string | | Contains major version of the product. E.g. 15-SP1 or 15.1
VIDEOMODE | string | | Indicates/defines video mode used for the installation. Empty value uses default, other possible values `text`, `ssh-x` for installation ncurses and x11 over ssh respectivelyю
VIRSH_OPENQA_BASEDIR | string | /var/lib | The OPENQA_BASEDIR configured on the svirt host (only relevant for the svirt backend).
UNENCRYPTED_BOOT | boolean | false | Indicates/defines existence of unencrypted boot partition in the SUT.
WAYLAND | boolean | false | Enables wayland tests in the system.
WIZARD_SKIP_USER | boolean | false | Skip non-root user creation in jeos-firstboot. This feature was added from sle-micro 6.1
XDMUSED | boolean | false | Indicates availability of xdm.
XFS_MKFS_OPTIONS | string | | Define additional mkfs parameters. Used only in publiccloud test runs.
XFS_TEST_DEVICE | string | | Define the device used for xfs tests. Used only in publiccloud test runs.
XFS_TESTS_REFLINK | boolean | false | If set to true, the mkfsoption for using reflink will be added. Used only in publiccloud test runs.
XFSTESTS_OVERLAY_BASE_FS | string | xfs | Define the base filesystem type of overlayfs
YAML_SCHEDULE_DEFAULT | string | | Defines default yaml file to be overridden by test suite schedule.
YAML_SCHEDULE_FLOWS | string | | Defines a comma-separated values representing additional flows which overrides steps on the schedule specified in YAML_SCHEDULE_DEFAULT.
YAML_SCHEDULE | string | | Defines yaml file containing test suite schedule.
YAML_TEST_DATA | string | | Defines yaml file containing test data.
YUI_LOG_LEVEL | string | debug | Allows changing log level for YuiRestClient::Logger. Available options are: debug, info, warning, error, fatal.
YUI_PORT | integer | | Port being used for libyui REST API. See also YUI_SERVER and YUI_START_PORT.
YUI_SERVER | string | | libyui REST API server name or ip address.
YUI_START_PORT | integer | 39000 | Sets starting port for the libyui REST API, on qemu VNC port is then added to this port not to have conflicts.
YUI_REST_API | boolean | false | Is used to setup environment for libyui REST API, as some parameters have to be set before the VM is started.
YUI_PARAMS | string | | libyui REST API params required to open YaST modules
YUPDATE_GIT | string | | Github link used by yast help script yupdate, format is repo#branch such as yast/agama#main.
TDUP | boolean | false | Prescribes zypper dup scenario (for transaction-update).
ZDUP | boolean | false | Prescribes zypper dup scenario.
ZDUP_IN_X | boolean | false | Prescribes zypper dup scenario, run in a graphical session.
ZDUPREPOS | string | | Comma separated list of repositories to be added/used for zypper dup call, defaults to SUSEMIRROR or attached media, e.g. ISO.
ZFCP_ADAPTERS | string | | Comma separated list of available ZFCP adapters in the machine (usually 0.0.fa00 and/or 0.0.fc00)
LINUXRC_BOOT | boolean | true | To be used only in scenarios where we are booting an installed system from the installer medium (for example, a DVD) with the menu option "Boot Linux System" (not "boot From Hard Disk"). This option uses linuxrc.
ZYPPER_WHITELISTED_ORPHANS | string | empty | Whitelist expected orphaned packages, do not fail if any are found. Upgrade scenarios are expecting orphans by default. Used by console/orphaned_packages_check.pm
PREPARE_TEST_DATA_TIMEOUT | integer | 300 | Download assets in the prepare_test_data module timeout
ZFS_REPOSITORY | string | | Optional repository used to test zfs from
TRENTO_HELM_VERSION | string | 3.8.2 | Helm version of the JumpHost
TRENTO_CYPRESS_VERSION | string | 9.6.1 | used as tag for the docker.io/cypress/included registry.
TRENTO_VM_IMAGE | string | SUSE:sles-sap-15-sp3-byos:gen2:latest | used as --image parameter during the Azure VM creation
TRENTO_VERSION | string | (implicit 1.0.0) | Optional. Used as reference version string for the installed Trento
TRENTO_REGISTRY_CHART | string | registry.suse.com/trento/trento-server | Helm chart registry
TRENTO_REGISTRY_CHART_VERSION | string |  | Optional. Tag for the chart image
TRENTO_REGISTRY_IMAGE_RUNNER | string |  | Optional. Overwrite the trento-runner image in the helm chart
TRENTO_REGISTRY_IMAGE_RUNNER_VERSION | string |  | Optional. Version tag for the trento-runner image
TRENTO_REGISTRY_IMAGE_WANDA | string |  | Optional. Overwrite the trento-wanda image in the helm chart
TRENTO_REGISTRY_IMAGE_WANDA_VERSION | string |  | Optional. Version tag for the trento-wand image
TRENTO_REGISTRY_IMAGE_WEB | string |  | Optional. Overwrite the trento-web image in the helm chart
TRENTO_REGISTRY_IMAGE_WEB_VERSION | string |  | Optional. Version tag for the trento-web image
TRENTO_GITLAB_REPO | string | gitlab.suse.de/qa-css/trento | Repository for the deployment scripts
TRENTO_GITLAB_BRANCH | string | master | Branch to use in the deployment script repository
TRENTO_GITLAB_TOKEN | string | from SECRET_TRENTO_GITLAB_TOKEN | Force the use of a custom token
TRENTO_DEPLOY_VER | string | | Force the Trento deployment script to be used from a release
TRENTO_AGENT_REPO | string | https://dist.suse.de/ibs/Devel:/SAP:/trento:/factory/SLE_15_SP3/x86_64 | Repository where to get the trento-agent installer
TRENTO_AGENT_RPM | string | | Trento-agent rpm file name
TRENTO_EXT_DEPLOY_IP | string | | Public IP of a Trento web instance not deployed by openQA
TRENTO_WEB_PASSWORD | string | | Trento web password for the admin user. If not provided, random generated one.
TRENTO_QESAPDEPLOY_CLUSTER_OS_VER | string | | OS for nodes in SAP cluster.
TRENTO_QESAPDEPLOY_HANA_ACCOUNT | string | | Azure blob server account for the SAP installers for the qe-sap-deployment hana_media.yaml.
TRENTO_QESAPDEPLOY_HANA_CONTAINER | string | | Azure blob server container for the qe-sap-deployment hana_media.yaml.
TRENTO_QESAPDEPLOY_HANA_KEYNAME | string | | Azure blob server key name used to generate the SAS URI token for the qe-sap-deployment hana_media.yaml.
TRENTO_QESAPDEPLOY_SAPCAR | string | | SAPCAR file name for the qe-sap-deployment hana_media.yaml.
TRENTO_QESAPDEPLOY_IMDB_SERVER | string | | IMDB_SERVER file name for the qe-sap-deployment hana_media.yaml.
TRENTO_QESAPDEPLOY_IMDB_CLIENT | string | | IMDB_CLIENT file name for the qe-sap-deployment hana_media.yaml.
QESAP_CONFIG_FILE | string | | filename (of relative path) of the config YAML file for the qesap.py script, within `sles4sap/qe_sap_deployment/` subfolder in `data`.
QESAP_DEPLOYMENT_DIR | string | /root/qe-sap-deployment | JumpHost folder where to install the qe-sap-deployment code
QESAP_ROLES_DIR | string | /root/community.sles-for-sap | JumpHost folder where to install the community.sles-for-sap code
QESAP_INSTALL_VERSION | string | | If configured, test will run with a specific release of qe-sap-deployment code from https://github.com/SUSE/qe-sap-deployment/releases. Otherwise the code is used from a latest version controlled by QESAP_INSTALL_GITHUB_REPO and QESAP_INSTALL_GITHUB_BRANCH
QESAP_INSTALL_GITHUB_REPO | string | github.com/SUSE/qe-sap-deployment | Git repository where to clone from. Ignored if QESAP_INSTALL_VERSION is configured.
QESAP_INSTALL_GITHUB_BRANCH | string | | Git branch. Ignored if QESAP_INSTALL_VERSION is configured.
QESAP_INSTALL_GITHUB_NO_VERIFY | string | | Configure http.sslVerify false. Ignored if QESAP_VER is configured.
QESAP_ROLES_INSTALL_GITHUB_REPO | string | github.com/sap-linuxlab/community.sles-for-sap | Git repository where to clone from. Ignored if QESAP_ROLES_INSTALL_VERSION is configured.
QESAP_ROLES_INSTALL_GITHUB_BRANCH | string | | Git branch. Ignored if QESAP_ROLES_INSTALL_VERSION is configured.
SMELT_URL | string | https://smelt.suse.de | Defines the URL for the SUSE Maintenance Extensible Lightweight Toolset, SMELT for short.

### Publiccloud specific variables

The following variables are relevant for publiccloud related jobs. Keep in mind that variables that start with `_SECRET` are secret variables, accessible only to the job but hidden in the webui. They will be not present in cloned jobs outside the original instance.

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
CLUSTER_TYPES | string | false | Set the type of cluster that have to be analyzed (example: "drbd hana").
PUBLIC_AZURE_CLI_TEST | string | "vmss" | Azure CLI test names. This variable should list the test name which should be tested.
PUBLIC_CLOUD | boolean | false | All Public Cloud tests have this variable set to true. Contact: qa-c@suse.de
PUBLIC_CLOUD_ACCNET | boolean | false | If set, az_accelerated_net test module is added to the job.
PUBLIC_CLOUD_ACCOUNT | string | "" | For GCE will set account via `gcloud config set account ' . $self->account`.
PUBLIC_CLOUD_AHB_LT | string | "SLES_BYOS" | For Azure, it specifies the license type to change to (and test).
PUBLIC_CLOUD_ARCH | string | "x86_64" | The architecture of created VM.
PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION | string | "" | Defines the image definition for uploading Arm64 images to the image gallery.
PUBLIC_CLOUD_AZURE_K8S_RESOURCE_GROUP | string | "" | Name for the resource group which is subscribed the kubernetes cluster.
PUBLIC_CLOUD_AZURE_OFFER | string | "" | Specific to Azure. Allow to query for image based on offer and sku. Should be used together with PUBLIC_CLOUD_AZURE_SKU.
PUBLIC_CLOUD_AZURE_PUBLISHER | string | "SUSE" | Specific to Azure. Allows to define the used publisher, if it should not be "SUSE"
PUBLIC_CLOUD_AZURE_SKU | string | "" | Specific to Azure.
PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID | string | "" | Used to create the service account file together with `PUBLIC_CLOUD_AZURE_TENANT_ID`.
PUBLIC_CLOUD_AZ_API | string | "http://169.254.169.254/metadata/instance/compute" | For Azure, it is the metadata API endpoint.
PUBLIC_CLOUD_AZ_API_VERSION | string | "2021-02-01" | For Azure, it is the API version used whe querying metadata API.
PUBLIC_CLOUD_BUILD | string | "" | The image build number. Used only when we use custom built image.
PUBLIC_CLOUD_BUILD_KIWI | string | "" | The image kiwi build number. Used only when we use custom built image.
PUBLIC_CLOUD_CLOUD_INIT | boolean | false | If this is true custom `cloud-config` will be attached to the instance.
PUBLIC_CLOUD_CONFIDENTIAL_VM | boolean | false | GCE Confidential VM instance
PUBLIC_CLOUD_CONSOLE_TESTS | boolean | false | If set, console tests are added to the job.
PUBLIC_CLOUD_CONTAINERS | boolean | false | If set, containers tests are added to the job.
PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY | string | "" | Name for public cloud registry for the container images used on kubernetes tests.
PUBLIC_CLOUD_CONTAINER_IMAGES_REPO | string | | The Container images repository in CSP
PUBLIC_CLOUD_CREDENTIALS_URL | string | "" | Base URL where to get the credentials from. This will be used to compose the full URL together with `PUBLIC_CLOUD_NAMESPACE`.
PUBLIC_CLOUD_DOWNLOAD_TESTREPO | boolean | false | If set, it schedules `publiccloud/download_repos` job.
PUBLIC_CLOUD_EC2_BOOT_MODE | string | "uefi-preferred" | The `--boot-mode` parameter for `ec2uploadimg` script. Available values: `legacy-bios`, `uefi`, `uefi-preferred` Currently unused variable. Use `git blame` to get context.
PUBLIC_CLOUD_EC2_IPV6_ADDRESS_COUNT | string | 0 | How many IPv6 addresses should the instance have
PUBLIC_CLOUD_EC2_ACCOUNT_ID | string | `aws sts get-caller-identity --query "Account" --output text` | The account ID (AMI OwnerId property) See poo#177387.
PUBLIC_CLOUD_EC2_UPLOAD_AMI | string | "" | Needed to decide which image will be used for helper VM for upload some image. When not specified some predefined value will be used. Overwrite the value for `ec2uploadimg --ec2-ami`.
PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP | string | "" | Allow to instruct ec2uploadimg script to use some existing security group instead of creating new one. If given, the parameter `--security-group-ids` is passed to `ec2uploadimg`.
PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET | string | "" | Allow to instruct ec2uploadimg script to use some existing VPC instead of creating new one.
PUBLIC_CLOUD_EMBARGOED_UPDATES_DETECTED | boolean | true | Internal variable written by the code and readed by the code . Should NOT be set manually
PUBLIC_CLOUD_FIO | boolean | false | If set, storage_perf test module is added to the job.
PUBLIC_CLOUD_FIO_RUNTIME | integer | 300 | Set the execution time for each FIO tests.
PUBLIC_CLOUD_FIO_SSD_SIZE | string | "100G" | Set the additional disk size for the FIO tests.
PUBLIC_CLOUD_FORCE_REGISTRATION | boolean | false | If set, tests/publiccloud/registration.pm will register cloud guest
PUBLIC_CLOUD_GCE_STACK_TYPE | string | IPV4_ONLY | Network stack type, possible values: IPV4_IPV6 or IPV4_ONLY
PUBLIC_CLOUD_GEN_RESOLVER | boolean | 0 | Control use of `--debug-resolver` option during maintenance updates testing . In case option was used also controls uploading of resolver case into the test
PUBLIC_CLOUD_GOOGLE_ACCOUNT | string | "" | GCE only, used to specify the account id.
PUBLIC_CLOUD_GOOGLE_PROJECT_ID | string | "" | GCP only, used to specify the project id.
PUBLIC_CLOUD_HDD2_SIZE | integer | "" | If set, the instance will have an additional disk with the given capacity in GB
PUBLIC_CLOUD_HDD2_TYPE | string | "" | If PUBLIC_CLOUD_ADDITIONAL_DISK_SIZE is set, this defines the additional disk type (optional). The required value depends on the cloud service provider.
PUBLIC_CLOUD_IGNORE_EMPTY_REPO | boolean | false | Ignore empty maintenance update repos
PUBLIC_CLOUD_IMAGE_ID | string | "" | The image ID we start the instance from
PUBLIC_CLOUD_IMAGE_LOCATION | string | "" | The URL where the image gets downloaded from. The name of the image gets extracted from this URL.
PUBLIC_CLOUD_IMAGE_PROJECT | string | "" | Google Compute Engine image project
PUBLIC_CLOUD_IMAGE_URI | string | "" | The URI of the image to be used. Use 'auto' if you want the URI to be calculated.
PUBLIC_CLOUD_IMG_PROOF_EXCLUDE | string | "" | Tests to be excluded by img-proof.
PUBLIC_CLOUD_IMG_PROOF_TESTS | string | "test-sles" | Tests run by img-proof.
PUBLIC_CLOUD_INFRA | boolean | false | Would trigger special flow in [check_registercloudguest.pm](tests/publiccloud/check_registercloudguest.pm) needed for run test against special test infra (DO NOT use the variable if you don't know what is about)
PUBLIC_CLOUD_INFRA_RMT_V4 | string | "" | Defines IPv4 registration server in test infra. Must be used together with PUBLIC_CLOUD_INFRA. (DO NOT use the variable if you don't know what is about)
PUBLIC_CLOUD_INFRA_RMT_V6 | string | "" | Defines IPv6 registration server in test infra. Must be used together with PUBLIC_CLOUD_INFRA. (DO NOT use the variable if you don't know what is about)
PUBLIC_CLOUD_INSTANCE_IP | string | "" | If defined, no instance will be created and this IP will be used to connect to
PUBLIC_CLOUD_INSTANCE_TYPE | string | "" | Specify the instance type. Which instance types exists depends on the CSP. (default-azure: Standard_A2, default-ec2: t3a.large )
PUBLIC_CLOUD_K8S_CLUSTER | string | "" | Name for the kubernetes cluster.
PUBLIC_CLOUD_KEEP_IMG | boolean | false | If set, the uploaded image will be tagged with `pcw_ignore=1`
PUBLIC_CLOUD_LTP | boolean | false | If set, the run_ltp test module is added to the job.
PUBLIC_CLOUD_MAX_INSTANCES | integer | 1 | Allows the test to call "create_instance" subroutine within lib/publiccloud/provider.md a limited amount of times. If set to 0 or undef, it allows an unlimited amount of calls.
PUBLIC_CLOUD_NAMESPACE | string | "" | The Public Cloud Namespace name that will be used to compose the full credentials URL together with `PUBLIC_CLOUD_CREDENTIALS_URL`.
PUBLIC_CLOUD_NEW_INSTANCE_TYPE | string | "t3a.large" | Specify the new instance type to check bsc#1205002 in EC2
PUBLIC_CLOUD_NO_CLEANUP | boolean | false | Do not remove the instance after test finished running.
PUBLIC_CLOUD_NVIDIA | boolean | 0 | If enabled, nvidia module would be scheduled. This variable should be enabled only sle15SP4 and above.
PUBLIC_CLOUD_PERF_COLLECT | boolean | 1 | To enable `boottime` measures collection, at end of `create_instance` routine.
PUBLIC_CLOUD_PERF_DB | string | "perf_2" | defines the bucket in which the performance metrics are stored on PUBLIC_CLOUD_PERF_DB_URI
PUBLIC_CLOUD_PERF_DB_ORG | string | "qec" | defines the organization in which the performance metrics are stored on PUBLIC_CLOUD_PERF_DB_URI
PUBLIC_CLOUD_PERF_DB_URI | string | "http://publiccloud-ng.qe.suse.de:8086" | bootup time measures get pushed to this Influx database url.
PUBLIC_CLOUD_PERF_PUSH_DATA | boolean | 1 | To enable the test to push it's metrics to the InfluxDB, when PUBLIC_CLOUD_PERF_COLLECT true.
PUBLIC_CLOUD_PERF_THRESH_CHECK | boolean | "" | If set to `1` or any not empty value, then the test run will _also_ execute the thresholds check on the collected metrics. By _default_ that check is _Not executed_.
PUBLIC_CLOUD_PREPARE_TOOLS | boolean | false | Activate prepare_tools test module by setting this variable.
PUBLIC_CLOUD_PROVIDER | string | "" | The type of the CSP (e.g. AZURE, EC2, GCE).
PUBLIC_CLOUD_PY_AZURE_REPO | string | "" | PY azure repo URL for azure_more_cli_test.
PUBLIC_CLOUD_PY_BACKPORTS_REPO | string | "" | PY Backport repo URL for azure_more_cli_test.
PUBLIC_CLOUD_QAM | boolean | false |  1 : to identify jobs running to test "Maintenance" updates; 0 : for jobs testing "Latest" (in development). Used to control all behavioral implications which this brings.
PUBLIC_CLOUD_REBOOT_TIMEOUT | integer | 600 | Number of seconds we wait for instance to reboot.
PUBLIC_CLOUD_REDOWNLOAD_MU | boolean | false | Debug variable used to redownload the maintenance repositories (as they might be downloaded by parent test)
PUBLIC_CLOUD_REGION | string | "" | The region to use. (default-azure: westeurope, default-ec2: eu-central-1, default-gcp: europe-west1-b). In `upload-img` for Azure Arm64 images, multiple comma-separated regions are supported (see `lib/publiccloud/azure.pm`)
PUBLIC_CLOUD_REGISTRATION_TESTS | boolean | false | If set, only the registration tests are added to the job.
PUBLIC_CLOUD_RESOURCE_GROUP | string | "qesaposd" | Allows to specify resource group name on SLES4SAP PC tests.
PUBLIC_CLOUD_RESOURCE_NAME | string | "openqa-vm" | The name we use when creating our VM.
PUBLIC_CLOUD_ROOT_DISK_SIZE | int |  | Set size of system disk in GiB for public cloud instance. Default size is 30 for Azure and 20 for GCE and EC2 
PUBLIC_CLOUD_SCC_ENDPOINT | string | "registercloudguest" | Name of binary which will be used to register image . Except default value only possible value is "SUSEConnect" anything else will lead to test failure!
PUBLIC_CLOUD_SKIP_MU | boolean | false | Debug variable used to run test without maintenance updates repository being applied.
PUBLIC_CLOUD_SLES4SAP | boolean | false | If set, sles4sap test module is added to the job.
PUBLIC_CLOUD_STORAGE_ACCOUNT | string | "" | Storage account used e.g. for custom disk and container images
PUBLIC_CLOUD_TERRAFORM_DIR | string | "/root/terraform" | Override default root path to terraform directory
PUBLIC_CLOUD_TERRAFORM_FILE | string | "" | If defined, use this terraform file (from the `data/` directory) instead the CSP default
PUBLIC_CLOUD_TOOLS_CLI | boolean | false | If set, it schedules `publiccloud_tools_cli` job group.
PUBLIC_CLOUD_TOOLS_REPO | string | "" | cloud tools repo URL for azure_more_cli_test.
PUBLIC_CLOUD_TOOLS_REPO | string | false | The URL to the cloud:tools repo (optional). (e.g. http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo).
PUBLIC_CLOUD_TTL_OFFSET | integer | 300 | This number + MAX_JOB_TIME equals the TTL of created VM.
PUBLIC_CLOUD_UPLOAD_IMG | boolean | false | If set, `publiccloud/upload_image` test module is added to the job.
PUBLIC_CLOUD_USER | string | "" | The public cloud instance system user.
PUBLIC_CLOUD_XEN | boolean | false | Indicates if this is a Xen test run.
TERRAFORM_TIMEOUT | integer | 1800 | Set timeout for terraform actions
TERRAFORM_VM_CREATE_TIMEOUT | string | "20m" | Terraform timeout for creating the virtual machine resource.
_SECRET_PUBLIC_CLOUD_INSTANCE_SSH_KEY | string | "" | The `~/.ssh/id_rsa` existing key allowed by `PUBLIC_CLOUD_INSTANCE_IP` instance
_SECRET_PUBLIC_CLOUD_PERF_DB_TOKEN | string | "" | this required variable is the token to access PUBLIC_CLOUD_PERF_DB_URI (defined in `salt workerconf`)


### Wicked testsuite specific variables

The following variables are relevant for the wicked testsuite

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
WICKED_CHECK_LOG_EXCLUDE | string | @see [wickedbase.pm](./lib/wickedbase.pm)::check_logs() | A CSV of log messages, which doesn't result in a test-module failure. The format is `<wicked-binary>=<regex>`.
WICKED_CHECK_LOG_FAIL | bool | false | If enabled, after each test-module. The journal of each wicked services is checked and the test-module fail if an unknown error was found.
WICKED_COMMIT_SHA | string | | Can be used with `WICKED_REPO`. It check the given SHA against the latest changelog entry of wicked. It's used to verify that we run openqa against the version we expect.
WICKED_EXCLUDE | regex  | | This exclude given wicked test modules. E.g.  `WICKED_EXCLUDE='^(?!t01_).*$'` would only run the test-module starting with `t01_*`.
WICKED_REPO | string | | If specified, wicked get installed from this repo before testing. The url should point to the `*.repo` file.
WICKED_SKIP_VERSION_CHECK | bool | false | Some test-modules require a specific wicked version. If you don't want this check take place, set this variable to `true`.
WICKED_TCPDUMP | bool | false | If enabled, on each test-module the network interfaces are set into promiscuous mode and a `*.pcap` file will be captured and uploaded.
WICKED_VALGRIND | string | | Enable valgind for specified wicked binaries. Multiple values should be separated by `,`. If set to `all` or `1`, valgrind is enabled for all binaries(wickedd-auto4, wickedd-dhcp6, wickedd-dhcp4, wickedd-nanny, wickedd and wicked).
WICKED_VALGRIND | string | /usr/bin/valgrind --tool=memcheck --leak-check=yes | The valgrind command used with `WICKED_VALGRIND` for each binary.


### xfstests specific variables

Following variables are relevant for filesystem tests xfstests. Contact: kernel-qa@suse.de

Regular setting: some mandatory setting

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
XFSTESTS_RANGES | string | | sub-tests ranges. This setting is mandatory. Support using "-" to define a range, or use "," to list separate subtests(e.g. xfs/001-999,generic/001). But the final test range will also count subtests defined in XFSTESTS_GROUPLIST, a skill to set subtests only by XFSTESTS_GROUPLIST is to set a minimal XFSTESTS_RANGES with XFSTESTS_GROUPLIST
NO_SHUFFLE | boolean | 0 | the default sequence to run all subtests is a random sequence, it's designed to reduce the influence between each subtest. Set NO_SHUFFLE=1 to run in order
XFSTESTS_BLACKLIST | string | | set the sub-tests will not run. Mostly use in the feature not supported, and exclude some critical issues to make whole tests stable. The final skip test list will also count those defined in XFSTESTS_GROUPLIST. It's also support "-" and "," to set skip range
XFSTESTS_GROUPLIST | string | | it's an efficient way to set XFSTESTS_RANGES. Most likely use in test whole range in a single test, such as test special mount option. The range is supported in xfstests upstream, to know the whole range of group names could take a look at xfstests upstream README file. This parameter in openqa supports not only "include" tests, but also "exclude" tests. To add a "!" before a group name to exclude all subtests in that group. Here is an example: e.g. XFSTESTS_GROUPLIST=quick,!fuzz,!fuzzers,!realtime (Add all subtests in quick group, and exclude all dangerous subtests in fuzz, fuzzers, realtime groups)
XFSTESTS_KNOWN_ISSUES | string | | Used to specify a url for a json file with well known xfstests issues. If an error occur which is listed, then the result is overwritten with softfailure.


Run-time related: timeout control to avoid random fails when low performance

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
XFSTESTS_HEARTBEAT_INTERVAL | integer | 30 | The interval (seconds) of each heartbeat signal
XFSTESTS_HEARTBEAT_TIMEOUT | integer | 200 | The timeout (seconds) of not receiving a heartbeat signal
XFSTESTS_SUBTEST_MAXTIME | integer | 2400 | Define the max test time (seconds) for a single subtest. The test logic will take the time out as a hang, to reset SUT and continue the rest of the tests. Considering xfstests contain some fuzzing tests which take quite a long time to finish, I suggest this max time don't set too small
XFSTESTS_NO_HEARTBEAT | boolean | 0 | set XFSTESTS_NO_HEARTBEAT=1 to enable non-heartbeat mode. The heartbeat mode is default, you could also unset this parameter
XFSTESTS_TIMEOUT | integer | 2000 | set de timeout (seconds) for each subtest. It is only used in non-heartbeat mode. And it's the only time control strategy in that mode
XFSTESTS_HIGHSPEED | boolean | 0 | set XFSTESTS_HIGHSPEED=1 to reduce the typing and waiting time. Suggest to set also VIRTIO_CONSOLE=1 and XFSTESTS_NO_HEARTBEAT=1 to getting highest performance. But beware system may hang in a crash because send_key 'alt-sysrq-b' not working in virtio console.


Installation related: some optional setting to solve testsuite installation dependency issue

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
XFSTESTS_REPO | string | | repo to install xfstests package
DEPENDENCY_REPO | string | | ibs/obs repo to install related test package to solve dependency issues. e.g. fio
XFSTESTS_DEVICE | string | | manually set a test disk for both TEST_DEV and SCRATCH_DEV
XFSTESTS_INSTALL | boolean | false | Install xfstests and dependency package.
XFSTESTS_PACKAGES | string | | Install additional required packages of xfstests. e.g. 'fsverity-utils libcap-progs'


Filesystem specific setting:

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
XFSTEST_MKFS_OPTION | string | | BTRFS only, value=<options-in-mkfs>. Set the options in mkfs.btrfs. And also set it in xfstests runtime option BTRFS_MKFS_OPTIONS.
XFSTESTS_LOGDEV | boolean | 0 | XFS only, value=0/1. enable log device in testing xfs
XFSTESTS_XFS_REPAIR | boolean | 0 | XFS only, value=0/1. enable TEST_XFS_REPAIR_REBUILD=1 in xfstests log file local.config
XFSTESTS_NFS_VERSION | string | 4.1 | NFS only, version of test target NFS
XFSTESTS_NFS_SERVER | boolean | | NFS multimation test only, mandatory. To tag this test job for NFS server in a NFS multimachine test. NFS test in a multimachine test either a client or a server.
NFS_GRACE_TIME | integer | 15 | NFS only, set the nlm_grace_period in /etc/modprobe.d/lockd.conf used in NFS test.
PARALLEL_WITH | string | | NFS multimation test only, value=<set-the-parent-job-name>. To set the NFS server job name in NFS client job in a NFS multimachine test. e.g. xfstests_nfs4.1-server
XFSTESTS_PART_SIZE | string | | Partitions size in MB, separate with commas. Each size is allocated to test_dev, scratch_dev1 and so on in turn. Unconfigured partitions will divide the remaining space equally. E.g, value=5120,10240 then test_dev=5120M, scratch_dev1=10240M, and remain partitions share the rest space.


Debug setting: advance setting to debugging issues, may cause test fail

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
XFSTESTS_DEBUG | string | | set it to enable debug tools under /proc/sys/kernel/. The value of XFSTESTS_DEBUG could be one or more parameters in the following: [hardlockup_panic hung_task_panic panic_on_io_nmi panic_on_oops panic_on_rcu_stall...] Collect more than 1 value at a time could use <space> to split it. e.g. XFSTESTS_DEBUG='hardlockup_panic panic_on_oops'. BTW, the softlockup_all_cpu_backtrace and softlockup_panic are default enabled
BTRFS_DUMP | boolean | 0 | set BTRFS_DUMP=<device name> to collect btrfs dump image. It uses btrfs-image create/restore an image of the filesystem. e.g BTRFS_DUMP=/dev/loop0
RAW_DUMP | boolean | 0 | set RAW_DUMP=1 to collect raw dump. It uses dd to collect start 512k info to dump the superblock of SCRATCH_DEV or SCRATCH_DEV_POOL
INJECT_INFO | string | | Add 1 or several lines of code into xfstests level test script(not in openqa script). To add some debug or log collect info. This code will be used by the test wrapper, it will influence all subtests in this test, so better to only use it in debug and set XFSTESTS_RANGES to the subtest you want to. It contains 2 parameters split by space, the format: '<line-number><space><code>'. Beware the output may not match after injection, and better not to add space in the <code> part to avoid mistakes. e.g. INJECT_INFO='49 free' (to check memory in test code line 49)
INJECT_INFO='<line-number> xtrace | string | | A special inject code is to set xtrace to debug shell script. Set INJECT_INFO='<line-number> xtrace' to openqa configure to enable it and start to record command start after injecting line <line-number>, and redirect debug info to /opt/log/xxx_xtrace.log

SCC REGCODES: registering product modules in SCC
Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
SCC_RECGODE_LTSS | string | | This will hold the registration code for activating the product SLES-LTSS
SCC_RECGODE_LTSS_ES | string | | This will hold the registration code for activating the product SLES-LTSS-Extended-Security

### Agama specific variables

Following variables are relevant for agama installation

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
AGAMA | boolean | 0 | Agama installation support
AGAMA_LIVE_ISO_URL | string | | The url of agama live iso to pass as kernel's command-line parameter. Example of usage "root=live:http://agama.iso"
INST_AUTO | string | | The auto-installation is started by passing `inst.auto=<url>` on the kernel's command line
INST_INSTALL_URL | string | | This will support using 'inst.install_url' boot parameter for overriding the default installation repositories. You can use multiple URLs separated by comma: inst.install_url=https://example.com/1,https://example.com/2
