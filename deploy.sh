#! /bin/bash

columnize() { 
    collen=$(($(tput cols)-5)); 
    value=$1; 
    while [ -n "$value" ]
    do 
        printf "\e[1m%-5s" "  " "${value:0:$collen}" 
        value=${value:$collen}
    done
    printf "\e[0m%*s\n\n"
}

COLUMNS=$(tput cols) 
atitle1="Initializing $(pwd)/${0##*/}"
atitle2="Let us begin"
configign="APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-30.20191014.1-live-initramfs.x86_64.img console=tty0 console=ttyS0 coreos.inst.install_dev=$disk coreos.inst.stream=stable coreos.inst.ignition_url=http://$ipaddr:8000/config.ign"

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
printf "\e[1m%*s\n" $(((${#atitle1}+$COLUMNS)/2)) "$atitle1"
printf "%*s\e[0m\n" $(((${#atitle2}+$COLUMNS)/2)) "$atitle2"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =

read -p '>>> Setup Podman or Docker? (p|d) [p]: ' engine
if [ -z "$engine" ]
then
    engine=p
fi
if [[ ! $engine =~ ^[PpDd]$ ]]
then
    exit 1
fi
if [[ $engine =~ ^[Pp]$ ]]
then
    engine=podman
else
    engine=docker
fi
read -p '>>> Setup DHCP? Make sure no external DHCP exist (y|n) [y]: ' dhcp
if [ -z "$dhcp" ]
then
    dhcp=y
fi
if [[ ! $dhcp =~ ^[YyNn]$ ]]
then
    exit 1
fi
read -p '>>> Indicate disk drive to install into (eg. /dev/sda) [/dev/sda]: ' disk
if [ -z "$dhcp" ]
then
    disk=/dev/sda
fi
read -p '>>> Indicate full path to your private key (eg. /root/id_rsa) []: ' pkey
while [ -z "$pkey" ]; do
    read -p 'Please enter a value []: ' pkey
done

hostip="$(hostname -I | awk '{print $1}')"
echo '>>> What is the IP of this server?'
read -p '>>> Target host must be able to reach this server IP (eg. '"$hostip"') []: ' ipaddr 
while [ -z "$ipaddr" ]; do
    read -p 'Please enter a value []: ' ipaddr 
done

while true; do
    echo ">>> Check the following ignition config values are correct"
    columnize "$configign"
    read -p ">>> Do you wish to proceed with installation (y|n)?" installyn
    case $installyn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
    esac
done

#################################
### Prepare
################################

btitle1="Preparing Environment"

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' +
printf "\e[1m%*s\e[0m\n" $(((${#btitle1}+$COLUMNS)/2)) "$btitle1"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' +

printf "\e[1m--- Clean up directory if it exists\e[0m\n"
if [ ! -d ./autodeploy.tmp ]; then
  mkdir -p ./autodeploy.tmp
else [ -d ./autodeploy.tmp ];
  rm -rf ./autodeploy.tmp
  mkdir -p ./autodeploy.tmp
fi

printf "\e[1m--- Downloading files\e[0m\n"
kernel=fedora-coreos-31.20200505.3.0-live-kernel-x86_64
img=fedora-coreos-31.20200505.3.0-live-initramfs.x86_64.img
#wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200505.3.0/x86_64/$kernel -P ./autodeploy.tmp 
#wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200505.3.0/x86_64/$img -P ./autodeploy.tmp 

printf "\e[1m--- Ignoring checksum check\e[0m\n"

printf "\e[1m--- Checking if python3 installed\e[0m\n"
if [ -z "$(rpm -qa | grep python3)" ]; then
  echo "... Installing python3"
  yum install python3 -y
else
  echo "... Package python3 installed, skipping"
fi

fccsetup() {
  podman pull quay.io/coreos/fcct:release
  podman run -i --rm quay.io/coreos/fcct:release --pretty --strict < config.fcc > transpiled_config.ign
}

printf "\e[1m--- Checking if $engine installed\e[0m\n"
if [ -z "$(rpm -qa | grep $engine)" ]; then
  echo "... Installing $engine"
  yum install $engine -y
else
  echo "... Package $engine installed, skipping"
fi

dhcpsetup() {
  systemctl start dhcp
  podman run -i --rm quay.io/coreos/fcct:release --pretty --strict < config.fcc > transpiled_config.ign
}

printf "\e[1m--- Checking dhcp\e[0m\n"
if [[ $dhcp == y ]]; then
  echo "... Using server's dhcp"
  printf "\e[1m--- Checking if dhcp installed\e[0m\n"  
  if [ -z "$(rpm -qa | grep dhcp)" ]; then
    echo "--- Installing dhcp"
    yum install dhcp -y
  else
    echo "... Package dhcp installed, skipping"
  fi
else
  echo "... Using external dhcp"
fi


