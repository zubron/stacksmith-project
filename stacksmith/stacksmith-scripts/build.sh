#!/bin/bash

set -euo pipefail

readonly uploads_dir=${UPLOADS_DIR:?Uploads directory not provided. Please set the UPLOADS_DIR environment variable}

installDependencies() {
    yum install -y unzip mariadb
}

installTomcat() {
    yum install -y tomcat tomcat-jsvc
}

patchSELinux() {
    local selinux_module
    selinux_module="/tmp/enable_tomcat_mysql"
    # Fix for SELinux blocking Tomcat talking to MySQL
    cat > ${selinux_module}.te <<EOF
module enable_tomcat_mysql 1.0;
require { type mysqld_port_t; type tomcat_t; class tcp_socket name_connect; }
allow tomcat_t mysqld_port_t:tcp_socket name_connect;
EOF
    checkmodule -M -m -o ${selinux_module}.mod ${selinux_module}.te
    semodule_package -m ${selinux_module}.mod -o ${selinux_module}.pp
    semodule -i ${selinux_module}.pp
    rm -f "${selinux_module}".{mod,te,pp}
}

disableSELinux() {
  # permissive is equivalent to disable + logging
  sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
}

deployWarFile() {
    local warfile
    warfile=${1:?No war file provided}

    local warfile_basename
    warfile_basename=$(basename "${warfile}")

    local app_name
    app_name=${warfile_basename%.*}

    mkdir /var/lib/tomcat/webapps/"${app_name}"
    unzip -q "${warfile}" -d /var/lib/tomcat/webapps/"${app_name}"
    chown -R root:root /var/lib/tomcat/webapps/"${app_name}"
    chmod 0755 /var/lib/tomcat/webapps/"${app_name}"
    install -m 644 -o root -g root "${warfile}" /var/lib/tomcat/webapps/
}

deployWarFiles() {
    find "${uploads_dir}" -maxdepth 1 -type f \( -name '*.war' -o -name '*.WAR' \) -print0 | while read -r -d $'\0' f
    do
        deployWarFile "${f}"
    done
}

# If there is a single app installed into tomcat then
# redirect to it
addRedirect() {
    local webapps_dir
    webapps_dir=/var/lib/tomcat/webapps
    if [ ! -d "${webapps_dir}/ROOT" ]; then
        if [ "$(find "${webapps_dir}" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq "1" ]; then
            local target
            target=$(basename "$(find "${webapps_dir}" -mindepth 1 -maxdepth 1 -type d)")

            mkdir "${webapps_dir}/ROOT"
            echo "<% response.sendRedirect(\"/${target}/\"); %>" > "${webapps_dir}/ROOT/index.jsp"
        fi
    fi
}

main() {
    installDependencies
    installTomcat
    deployWarFiles
    addRedirect

    if command -v sestatus ; then patchSELinux && disableSELinux ; fi

    # Only for VMs
    # systemctl enable tomcat
}

main "$@"
