# yast-modules branch of distri opensuse

This branch exists only to host an alternative `main.pm` file. The goal of that
file is to make fast and easy to run single jobs to test a specific feature
(probably still under development) developed for YaST.

Contrary to the master, sle11 and sle12 branches that are focused on testing the
whole distribution with several combinations of variables (using job templates),
this branch is meant to be used to run single jobs (thus, no templates are
provided).

Other difference is that the jobs on this branch will never run the whole
installation process. They are intended to be started on top of an already
installed system, thus the variable `HDD_1` is expected in addition to `ISO`.

By default, `main.pm` will run all the YaST related test modules. This behavior
can be influenced with some env variables.

 * `YAST_HEAD` When set to true, the distro will be updated with the packages
  available in the YaST:Head repository before running the tests.
 * `YAST_SKIP_CONSOLE` Skips the console modules.
 * `YAST_SKIP_X11` Skips the X11 modules.
 * `YAST_RUN_ONLY` Accepts a list of test modules separated by `;`. Only those
   test modules will be run.

For example

```
$ client jobs post DISTRI=yast-modules TEST=whatever \
    BACKEND=qemu ARCH=x86_64 \
    BUILD=20150524 VERSION=Tumbleweed \
    HDD_1=tumbleweed_kde.qcow2 ISO=openSUSE-TW-DVD-x86_64-20150524.iso \
    YAST_HEAD=1 YAST_RUN_ONLY="console/yast2_i;x11/yast2_users"
```
