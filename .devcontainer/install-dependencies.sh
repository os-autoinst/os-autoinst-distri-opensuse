# Generic update
zypper dup -y

# dependency suggested in the CONTRIBUTING.md
zypper in -y os-autoinst-distri-opensuse-deps perl-JSON-Validator gnu_parallel

# other dependency that are needed
zypper in -y awk tar make git vim gcc-c++ libxml2-devel libssh2-devel libexpat-devel dbus-1-devel python311 python311-devel python311-yamllint python311-PyYAML perl-App-cpanminus perl-Code-TidyAll podman
