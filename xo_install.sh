#!/bin/bash

# Check if we were effectively run as root
[ $EUID = 0 ] || { echo "This script needs to be run as root!"; exit 1; }

# Check for 1GB Memory
totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
if [ "$totalk" -lt "1000000" ]; then echo "XOCE Requires at least 1GB Memory!"; exit 1; fi 

distro=$(/usr/bin/lsb_release -is)
if [ "$distro" = "Ubuntu" ]; then /usr/bin/add-apt-repository multiverse; fi

xo_branch="master"
xo_server="https://github.com/vatesfr/xen-orchestra"
n_repo="https://raw.githubusercontent.com/visionmedia/n/master/bin/n"
yarn_repo="deb https://dl.yarnpkg.com/debian/ stable main"
yarn_gpg="https://dl.yarnpkg.com/debian/pubkey.gpg"
n_location="/usr/local/bin/n"
xo_server_dir="/opt/xen-orchestra"
systemd_service_dir="/lib/systemd/system"
xo_service="xo-server.service"

# Ensure that git and curl are installed
/usr/bin/apt-get update
/usr/bin/apt-get --yes install git curl

#Install yarn
cd /opt

                                       
/usr/bin/curl -sS $yarn_gpg | apt-key add -
echo "$yarn_repo" | tee /etc/apt/sources.list.d/yarn.list
/usr/bin/apt-get update
/usr/bin/apt-get install --yes yarn

# Install n
/usr/bin/curl -o $n_location $n_repo
/bin/chmod +x $n_location

# Install node via n
n 8.16

# Symlink node directories
ln -s /usr/bin/node /usr/local/bin/node

# Install XO dependencies
/usr/bin/apt-get install --yes build-essential redis-server libpng-dev git python-minimal libvhdi-utils nfs-common lvm2 cifs-utils apt-transport-https

/usr/bin/git clone -b $xo_branch $xo_server

# Disabling the "Built from Source Banner - No Support" Bar across the top of screen 
sed -i 's/process.env.XOA_PLAN === 5/process.env.XOA_PLAN === 6/g' /opt/xen-orchestra/packages/xo-web/src/xo-app/index.js

# Patch to allow config restore
sed -i 's/< 5/> 0/g' /opt/xen-orchestra/packages/xo-web/src/xo-app/settings/config/index.js

cd $xo_server_dir
/usr/bin/yarn
/usr/bin/yarn build

cd packages/xo-server
cp sample.config.toml .xo-server.toml
sed -i "s|#'/' = '/path/to/xo-web/dist/'|'/' = '/opt/xen-orchestra/packages/xo-web/dist'|" .xo-server.toml

#Create node_modules directory if doesn't exist
mkdir -p /usr/local/lib/node_modules/

# Symlink all plugins
for source in $(ls -d /opt/xen-orchestra/packages/xo-server-*); do
    ln -s "$source" /usr/local/lib/node_modules/
done

if [[ ! -e $systemd_service_dir/$xo_service ]] ; then

/bin/cat << EOF >> $systemd_service_dir/$xo_service
# Systemd service for XO-Server.

[Unit]
Description= XO Server
After=network-online.target

[Service]
WorkingDirectory=/opt/xen-orchestra/packages/xo-server/
ExecStart=/usr/local/bin/node ./bin/xo-server
Restart=always
SyslogIdentifier=xo-server

[Install]
WantedBy=multi-user.target
EOF
fi

/bin/systemctl daemon-reload
/bin/systemctl enable $xo_service
/bin/systemctl start $xo_service

echo ""
echo ""
echo "Installation complete, open a browser to:" && hostname -I && echo "" && echo "Default Login:"admin@admin.net" Password:"admin"" && echo "" && echo "Don't forget to change your password!"

