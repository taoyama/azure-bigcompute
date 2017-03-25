#!/bin/bash
#should work for all skus
set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# != 9 ]; then
    echo "Usage: $0 <clusterdet> <HPCUserName> <mountFolder> <mungedet> <slurmdet> <numDataDisks> <dockerdet> <imagedet> <artifactsLocation>"
    exit 1
fi


# Set user args
MASTER_HOSTNAME=$( echo "$1" |cut -d\: -f1 )
WORKER_HOSTNAME_PREFIX=$( echo "$1" |cut -d\: -f2 )
WORKER_COUNT=$( echo "$1" |cut -d\: -f3 )
omsworkspaceid=$( echo "$1" |cut -d\: -f4 )
omsworkspacekey=$( echo "$1" |cut -d\: -f5 )
omslnxagentver=$( echo "$1" |cut -d\: -f6 )
HEADNODE_SIZE=$( echo "$1" |cut -d\: -f7 )
WORKERNODE_SIZE=$( echo "$1" |cut -d\: -f8 )
LAST_WORKER_INDEX=$(($WORKER_COUNT - 1))

# Shares
MNT_POINT="$3"
SHARE_HOME=$MNT_POINT/home
SHARE_DATA=$MNT_POINT/data

# Munged
MUNGE_VERSION=$( echo "$4" |cut -d\: -f1 )
MUNGE_USER=$( echo "$4" |cut -d\: -f2 )
TORQUEORPBS=$( echo "$4" |cut -d\: -f3 )
SALTSTACKBOOLEAN=$( echo "$4" |cut -d\: -f4 )
MUNGE_GROUP=$MUNGE_USER


# SLURM
SLURM_USER=$( echo "$5" |cut -d\: -f2 )
SLURM_UID=6006
SLURM_GROUP=$SLURM_USER
SLURM_GID=6006
SLURM_VERSION=$( echo "$5" |cut -d\: -f1 )
SLURM_CONF_DIR=$SHARE_DATA/conf

# Hpc User
HPC_USER="$2"
HPC_UID=7007
HPC_GROUP=$HPC_USER
HPC_GID=7007

numberofDisks=$6
dockerVer=$( echo "$7" |cut -d\: -f1 )
dockerComposeVer=$( echo "$7" |cut -d\: -f2 )
dockMVer=$( echo "$7" |cut -d\: -f3 )
userName=$( echo "$8" |cut -d\: -f2 )
skuName=$( echo "$8" |cut -d\: -f1 )
TEMPLATE_BASE_URL=$9


# Returns 0 if this node is the master node.
#
is_master()
{
    hostname | grep "$MASTER_HOSTNAME"
    return $?
}


enable_kernel_update()
{
	if [ "$skuName" == "6.5" ] || [ "$skuName" == "7.1" ]; then
		cd /etc && sed -i.bak -e '28d' yum.conf
		cd /etc && sed -i '28i#exclude=kernel*' yum.conf

	elif [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.3" ]  ; then
                echo "kernel update is enabled";

	fi

}

disable_kernel_update()
{
	if [ "$skuName" == "6.5" ] || [ "$skuName" == "7.1" ]; then
		cd /etc && sed -i.bak -e '28d' yum.conf
		cd /etc && sed -i '28iexclude=kernel*' yum.conf

	elif [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.3" ]  ; then
                echo "No kernel to update";

	fi

}

# Partitions all data disks attached to the VM and creates
# a RAID-0 volume with them.
#
setup_data_disks()
{
    mountPoint="$1"
    createdPartitions=""

    # Loop through and partition disks until not found
    for disk in sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax sday sdaz sdaaa sdaab ; do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
    done

    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/md10 --level 0 --raid-devices $devices $createdPartitions
        
        mkfs -t ext4 /dev/md10
        if [ "$skuName" == "16.04-LTS" ] ; then
        echo "/dev/md127 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        else
        echo "/dev/md10 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        fi
        mount /dev/md10
    fi
}
setup_dynamicdata_disks()
{
    mountPoint="$1"
    createdPartitions=""

    # Loop through and partition disks until not found

if [ "$numberofDisks" == "1" ]
then
   disking=( sdc )
elif [ "$numberofDisks" == "2" ]; then
   disking=( sdc sdd )
elif [ "$numberofDisks" == "3" ]; then
   disking=( sdc sdd sde )
elif [ "$numberofDisks" == "4" ]; then
   disking=( sdc sdd sde sdf )
elif [ "$numberofDisks" == "5" ]; then
   disking=( sdc sdd sde sdf sdg )
elif [ "$numberofDisks" == "6" ]; then
   disking=( sdc sdd sde sdf sdg sdh )
elif [ "$numberofDisks" == "7" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi )
elif [ "$numberofDisks" == "8" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj )
elif [ "$numberofDisks" == "9" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk )
elif [ "$numberofDisks" == "10" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl )
elif [ "$numberofDisks" == "11" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm )
elif [ "$numberofDisks" == "12" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn )
elif [ "$numberofDisks" == "13" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo )
elif [ "$numberofDisks" == "14" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp )
elif [ "$numberofDisks" == "15" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq )
elif [ "$numberofDisks" == "16" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr )
elif [ "$numberofDisks" == "17" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds )
elif [ "$numberofDisks" == "18" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt )
elif [ "$numberofDisks" == "19" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu )
elif [ "$numberofDisks" == "20" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv )
elif [ "$numberofDisks" == "21" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw )
elif [ "$numberofDisks" == "22" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx )
elif [ "$numberofDisks" == "23" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy )
elif [ "$numberofDisks" == "24" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz )
elif [ "$numberofDisks" == "25" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa )
elif [ "$numberofDisks" == "26" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab )
elif [ "$numberofDisks" == "27" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac )
elif [ "$numberofDisks" == "28" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad )
elif [ "$numberofDisks" == "29" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae )
elif [ "$numberofDisks" == "30" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf )
elif [ "$numberofDisks" == "31" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag )
elif [ "$numberofDisks" == "32" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah )
elif [ "$numberofDisks" == "33" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai )
elif [ "$numberofDisks" == "34" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj )
elif [ "$numberofDisks" == "35" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak )
elif [ "$numberofDisks" == "36" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal )
elif [ "$numberofDisks" == "37" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam )
elif [ "$numberofDisks" == "38" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan )
elif [ "$numberofDisks" == "39" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao )
elif [ "$numberofDisks" == "40" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap )
elif [ "$numberofDisks" == "41" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq )
elif [ "$numberofDisks" == "42" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar )
elif [ "$numberofDisks" == "43" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas )
elif [ "$numberofDisks" == "44" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat )
elif [ "$numberofDisks" == "45" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau )
elif [ "$numberofDisks" == "46" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav )
elif [ "$numberofDisks" == "47" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw )
elif [ "$numberofDisks" == "48" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax )
elif [ "$numberofDisks" == "49" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax sday )
elif [ "$numberofDisks" == "50" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax sday sdaz )
elif [ "$numberofDisks" == "51" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax sday sdaz sdaaa )
elif [ "$numberofDisks" == "52" ]; then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag sdah sdai sdaj sdak sdal sdam sdan sdao sdap sdaq sdar sdas sdat sdau sdav sdaw sdax sday sdaz sdaaa sdaab )
   
fi

printf "%s\n" "${disking[@]}"

for disk in "${disking[@]}"
do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
done

    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/md10 --level 0 --raid-devices $devices $createdPartitions
        mkfs -t ext4 /dev/md10
        echo "/dev/md10 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /dev/md10
    fi
}


set_time()
{
    mv /etc/localtime /etc/localtime.bak
    #ln -s /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
    /usr/share/zoneinfo/US/Central /etc/localtime
}


# System Update.
#
system_update()
{
    rpm --rebuilddb
    updatedb
    yum clean all
    yum -y install epel-release
    #yum  -y update --exclude=WALinuxAgent
    #yum  -y update
    #yum -x 'intel-*' -x 'kernel*' -x '*microsoft-*' -x 'msft-*'  -y update --exclude=WALinuxAgent
    yum --exclude WALinuxAgent,intel-*,kernel*,kernel-headers*,*microsoft-*,msft-* -y update 

    set_time
}

install_docker()
{
if false
then
    wget -qO- "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e" 
    rpm --import "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
    yum install -y yum-utils
    yum-config-manager --add-repo https://packages.docker.com/$dockerVer/yum/repo/main/centos/7
    yum install -y docker-engine
 fi
  yum install -y yum-utils
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/$dockerVer.repo
  yum makecache fast
  yum -y install docker-ce
    systemctl stop firewalld
    systemctl disable firewalld
    #service docker start
    gpasswd -a $userName docker
    systemctl start docker
    systemctl enable docker
    #curl -L https://github.com/docker/compose/releases/download/$dockerComposeVer/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
     curl -L "https://github.com/docker/compose/releases/download/$dockerComposeVer/docker-compose-$(uname -s)-$(uname -m)" > /usr/local/bin/docker-compose
    curl -L https://github.com/docker/machine/releases/download/v$dockMVer/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-compose
    export PATH=$PATH:/usr/local/bin/
    systemctl restart docker
 
}
install_docker_ubuntu()
{
	
        # System Update and docker version update
	DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
        DEBIAN_FRONTEND=noninteractive apt-get -y update
         apt-get install -y apt-transport-https ca-certificates curl
        #curl -s 'https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e' | apt-key add --import
       # echo "deb https://packages.docker.com/$dockerVer/apt/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list
         #apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	 #apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
	 #echo "deb https://packages.docker.com/${dockerVer}/apt/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
         #echo 'deb https://packages.docker.com/$dockerVer/apt/repo ubuntu-xenial main' > /etc/apt/sources.list.d/docker.list
	 DEBIAN_FRONTEND=noninteractive apt-get -y update
         DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
	 apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual

         curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
       add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"
       DEBIAN_FRONTEND=noninteractive apt-get -y update
         #apt-cache policy docker-engine
	 groupadd docker
	 usermod -aG docker $userName
	 usermod -aG docker $HPC_USER
	 
         #apt-get install -y docker-engine
	 apt-get -y install $dockerVer
	 #apt-get install -y --allow-unauthenticated docker-engine
	 /etc/init.d/apparmor stop 
	 /etc/init.d/apparmor teardown 
	 update-rc.d -f apparmor remove
	 apt-get -y remove apparmor
         #DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated docker-engine
    curl -L https://github.com/docker/compose/releases/download/$dockerComposeVer/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    curl -L https://github.com/docker/machine/releases/download/v$dockMVer/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-compose
    export PATH=$PATH:/usr/local/bin/
    systemctl restart docker
}
install_nvdia_ubuntu()
{
	#DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-361
service lightdm stop 
#wget https://azuregpu.blob.core.windows.net/nv-drivers/NVIDIA-Linux-x86_64-361.45.09-grid.run
#wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/NVIDIA-Linux-x86_64-367.64-grid.run
#wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/NVIDIA-Linux-x86_64-375.39.run
wget  http://us.download.nvidia.com/XFree86/Linux-x86_64/375.39/NVIDIA-Linux-x86_64-375.39.run&lang=us&type=Tesla
#chmod +x NVIDIA-Linux-x86_64-361.45.09-grid.run
chmod +x NVIDIA-Linux-x86_64-367.64-grid.run
DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential gcc g++ make binutils linux-headers-`uname -r`
#DEBIAN_FRONTEND=noninteractive ./NVIDIA-Linux-x86_64-361.45.09-grid.run  --silent
DEBIAN_FRONTEND=noninteractive ./NVIDIA-Linux-x86_64-367.64-grid.run  --silent
DEBIAN_FRONTEND=noninteractive update-initramfs -u
}
install_azure_cli()
{
    yum install -y nodejs
    yum install -y npm
    npm install -g azure-cli
}

install_docker_apps()
{

    # Setting tomcat
    #docker run -it -dp 80:8080 -p 8009:8009  rossbachp/apache-tomcat8
    
    docker run -dti --restart=always --name=azure-cli microsoft/azure-cli
    docker run -dti --restart=always --name=azure-cli-python azuresdk/azure-cli-python
    #if is_master; then
    #docker run -it -d --restart=always -p 8080:8080 rancher/server
    #fi
    # Ansible automation for Rancher to be put in
}

install_ib()
{
    yum groupinstall -y "Infiniband Support"
    yum install -y infiniband-diags perftest qperf opensm
    chkconfig opensm on
    chkconfig rdma on
    #reboot
}
# Installs individual packages of interest.
#
install_packages()
{
    yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs  nfs-utils rpcbind git libicu libicu-devel make zip unzip mdadm wget gsl bc rpm-build  readline-devel pam-devel libXtst.i686 libXtst.x86_64 make.x86_64 sysstat.x86_64 python-pip automake autoconf\
    binutils.x86_64 compat-libcap1.x86_64 glibc.i686 glibc.x86_64 \
    ksh compat-libstdc++-33 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 \
    libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libXi.i686 libXi.x86_64
    #yum -y install icu patch ruby ruby-devel rubygems  gcc gcc-c++ gcc.x86_64 gcc-c++.x86_64 glibc-devel.i686 glibc-devel.x86_64
}

install_packages_ubuntu()
{
DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
DEBIAN_FRONTEND=noninteractive apt-get install -y zlib1g zlib1g-dev  bzip2 libbz2-dev libssl1.0.0  libssl-doc libssl1.0.0-dbg libsslcommon2 libsslcommon2-dev libssl-dev  nfs-common rpcbind git zip libicu55 libicu-dev icu-devtools unzip mdadm wget gsl-bin libgsl2  bc ruby-dev gcc make autoconf bison build-essential libyaml-dev libreadline6-dev libncurses5 libncurses5-dev libffi-dev libgdbm3 libgdbm-dev libpam0g-dev libxtst6 libxtst6-* libxtst-* libxext6 libxext6-* libxext-* git-core libelf-dev asciidoc binutils-dev fakeroot crash kexec-tools makedumpfile kernel-wedge portmap
DEBIAN_FRONTEND=noninteractive apt-get -y build-dep linux
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

DEBIAN_FRONTEND=noninteractive update-initramfs -u
}
# Installs all required packages.
#
install_packages_kernel_headers()
{
	enable_kernel_update
	
	yum -y install icu patch ruby ruby-devel rubygems  gcc gcc-c++ gcc.x86_64 gcc-c++.x86_64 glibc-devel.i686 glibc-devel.x86_64  libtool  libxml2-devel boost-devel openldap-clients nss-pam-ldapd
	
	disable_kernel_update
}
install_pkgs_all()
{
    system_update
     
    yum install -y expect

    install_packages
    
    install_packages_kernel_headers

	if [ "$skuName" == "6.5" ] || [ "$skuName" == "6.6" ] ; then
    		install_azure_cli
	elif [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] || [ "$skuName" == "7.3" ] ; then

    		install_docker

    		install_docker_apps
	fi

    install_ib
}


# Creates and exports two shares on the master nodes:
#
# /share/home (for HPC user)
# /share/data
#
# These shares are mounted on all worker nodes.
#
setup_shares()
{
    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_DATA

    if is_master; then
        #setup_data_disks $SHARE_DATA
        echo "$SHARE_HOME    *(rw,async)" >> /etc/exports
        echo "$SHARE_DATA    *(rw,async)" >> /etc/exports
	if [ "$skuName" == "16.04-LTS" ] ; then
	         DEBIAN_FRONTEND=noninteractive apt-get -y \
		  -o DPkg::Options::=--force-confdef \
		 -o DPkg::Options::=--force-confold \
    		install nfs-kernel-server
		/etc/init.d/apparmor stop 
		/etc/init.d/apparmor teardown 
		update-rc.d -f apparmor remove
		apt-get -y remove apparmor
                systemctl start rpcbind || echo "Already enabled"
                systemctl start nfs-server || echo "Already enabled"
                systemctl start nfs-kernel-server.service
                systemctl enable rpcbind || echo "Already enabled"
                systemctl enable nfs-server || echo "Already enabled"
                systemctl enable nfs-kernel-server.service
        else
	        
                systemctl start rpcbind || echo "Already enabled"
                systemctl start nfs-server || echo "Already enabled"
                systemctl enable rpcbind || echo "Already enabled"
                systemctl enable nfs-server || echo "Already enabled"
         fi
        setup_dynamicdata_disks $SHARE_DATA
    else

	        echo "$MASTER_HOSTNAME:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
	        echo "$MASTER_HOSTNAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
		#echo "$MASTER_HOSTNAME:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,user,async,noatime,rsize=65536,wsize=65536, _netdev 0 0" >> /etc/fstab
		#echo "$MASTER_HOSTNAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,user,async,noatime,rsize=65536,wsize=65536, _netdev 0 0" >> /etc/fstab
	        #echo "master:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
	        #echo "master:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
	        mount -a
	        #mount | grep "^master:$SHARE_HOME"
	        #mount | grep "^master:$SHARE_DATA"
	        mount | grep "^$MASTER_HOSTNAME:$SHARE_HOME"
	        mount | grep "^$MASTER_HOSTNAME:$SHARE_DATA"

    fi
}


# Adds a common HPC user to the node and configures public key SSh auth.
# The HPC user has a shared home directory (NFS share on master) and access
# to the data share.
#
setup_hpc_user()
{

	if [ "$skuName" == "16.04-LTS" ] ; then
		/etc/init.d/apparmor stop 
		/etc/init.d/apparmor teardown 
		update-rc.d -f apparmor remove
		apt-get -y remove apparmor

	elif [ "$skuName" == "6.5" ] || [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] || [ "$skuName" == "7.3" ] ; then
		    # disable selinux
		    sed -i 's/enforcing/disabled/g' /etc/selinux/config
		    setenforce permissive

	fi

    
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

    if is_master; then
    
        useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

        mkdir -p $SHARE_HOME/$HPC_USER/.ssh
        
        # Configure public key auth for the HPC user
        ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
        cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub > $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

        echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    PasswordAuthentication no" >> $SHARE_HOME/$HPC_USER/.ssh/config

        # Fix .ssh folder ownership
        chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER

        # Fix permissions
        chmod 700 $SHARE_HOME/$HPC_USER/.ssh
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
        chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub
        
        # Give hpc user access to data share
        chown -R $HPC_USER:$HPC_GROUP $SHARE_DATA
        
        #set_env_docker_cc
        
    else
        useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
    fi
}

# Sets all common environment variables and system parameters.
#
setup_env()
{
    # Set unlimited mem lock
    echo "$HPC_USER hard memlock unlimited" >> /etc/security/limits.conf
    echo "$HPC_USER soft memlock unlimited" >> /etc/security/limits.conf

    # Intel MPI config for IB
    echo "# IB Config for MPI" > /etc/profile.d/mpi.sh
    echo "export I_MPI_FABRICS=shm:dapl" >> /etc/profile.d/mpi.sh
    echo "export I_MPI_DAPL_PROVIDER=ofa-v2-ib0" >> /etc/profile.d/mpi.sh
    echo "export I_MPI_DYNAMIC_CONNECTION=0" >> /etc/profile.d/mpi.sh
    source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh
}

set_env_docker_cc()
{
cd /data/data
wget  http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.3.tar.gz
tar xvzf osu-micro-benchmarks-5.3.tar.gz
cd osu-micro-benchmarks-5.3
source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh
mkdir -p /data/data/osubuild	
}

install_pypacks()
{
    yum -y install Lmod python-devel python-pip gcc gcc-c++ patch unzip tcl tcl-devel libibverbs libibverbs-devel
    pip install vsc-base
}

# Downloads/builds/installs munged on the node.
# The munge key is generated on the master node and placed
# in the data share.
# Worker nodes copy the existing key from the data share.
#
install_munge()
{
    groupadd $MUNGE_GROUP

    useradd -M -c "Munge service account" -g $MUNGE_GROUP -s /usr/sbin/nologin $MUNGE_USER
    
    cd $SHARE_DATA/
## compile options on non-fixed and fixed kernels
 #   wget https://github.com/dun/munge/archive/munge-${MUNGE_VERSION}.tar.gz

 #   tar xvfz munge-$MUNGE_VERSION.tar.gz

 #   cd munge-munge-$MUNGE_VERSION

    mkdir -m 700 /etc/munge
    mkdir -m 711 /var/lib/munge
    mkdir -m 700 /var/log/munge
    mkdir -m 755 /var/run/munge
 #   mkdir -m 755 $SHARE_DATA/mungebuild

  ./configure -libdir=/usr/lib64 --prefix=/usr --sysconfdir=/etc --localstatedir=/var && make && make install
  #interactive tty 
 #docker run --rm -it -v $SHARE_DATA/munge-munge-$MUNGE_VERSION:/usr/src/munge:rw -v $SHARE_DATA/mungebuild:/usr/src/mungebuild:rw -v /usr/lib64:/usr/src/lib64:rw -v     /usr/lib64:/usr/src/lib64:rw -v /etc:/etc:rw -v /var:/var:rw -v /usr:/opt:rw  gcc:5.1 bash -c "cd /usr/src/munge && ./configure -libdir=/opt/lib64 --prefix=/opt --sysconfdir=/etc --localstatedir=/var && make && make install"
#interactive non-tty 
#docker run --rm -i -v $SHARE_DATA/munge-munge-$MUNGE_VERSION:/usr/src/munge:rw -v $SHARE_DATA/mungebuild:/usr/src/mungebuild:rw -v /usr/lib64:/usr/src/lib64:rw -v     /usr/lib64:/usr/src/lib64:rw -v /etc:/etc:rw -v /var:/var:rw -v /usr:/opt:rw  gcc:5.1 bash -c "cd /usr/src/munge && ./configure -libdir=/opt/lib64 --prefix=/opt --sysconfdir=/etc --localstatedir=/var && make && make install"
#yum install -y munge-devel munge
    chown -R $MUNGE_USER:$MUNGE_GROUP /etc/munge /var/lib/munge /var/log/munge /var/run/munge

    if is_master; then
        dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
    mkdir -p $SLURM_CONF_DIR
    
        cp /etc/munge/munge.key $SLURM_CONF_DIR
       chown -R $HPC_USER:$HPC_GROUP $SHARE_DATA
    else
        cp $SLURM_CONF_DIR/munge.key /etc/munge/munge.key
        chown -R $HPC_USER:$HPC_GROUP $SHARE_DATA
        chown -R $MUNGE_USER:$MUNGE_GROUP /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    fi

    chown $MUNGE_USER:$MUNGE_GROUP /etc/munge/munge.key
    chown -R $MUNGE_USER:$MUNGE_GROUP /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    chmod 0400 /etc/munge/munge.key

    systemctl enable munge.service
    systemctl start munge.service

    cd ..
}


# Installs and configures slurm.conf on the node.
# This is generated on the master node and placed in the data
# share.  All nodes create a sym link to the SLURM conf
# as all SLURM nodes must share a common config file.
#
install_slurm_config()
{
    if is_master; then

        mkdir -p $SLURM_CONF_DIR
       

        if [ -e "$TEMPLATE_BASE_URL/slurm.template.conf" ]; then
            cp "$TEMPLATE_BASE_URL/slurm.template.conf" .
        else
            wget "$TEMPLATE_BASE_URL/slurm.template.conf"
        fi

        cat slurm.template.conf |
        sed s/master/"$MASTER_HOSTNAME"/g |
                sed s/__WORKER_HOSTNAME_PREFIX__/"$WORKER_HOSTNAME_PREFIX"/g |
                sed s/__LAST_WORKER_INDEX__/"$LAST_WORKER_INDEX"/g > $SLURM_CONF_DIR/slurm.conf
                chown -R $HPC_USER:$HPC_GROUP $SHARE_DATA
    fi
    chown -R $HPC_USER:$HPC_GROUP $SHARE_DATA
    ln -s $SLURM_CONF_DIR/slurm.conf /etc/slurm/slurm.conf
    chown -R $SLURM_GROUP:$SLURM_USER /var/spool/slurmd /var/run/slurmd /var/run/slurmctld /var/log/slurmd /var/log/slurmctld
}

# Downloads, builds and installs SLURM on the node.
# Starts the SLURM control daemon on the master node and
# the agent on worker nodes.
#
install_slurm()
{
    groupadd -g $SLURM_GID $SLURM_GROUP

    useradd -M -u $SLURM_UID -c "SLURM service account" -g $SLURM_GROUP -s /usr/sbin/nologin $SLURM_USER

    mkdir -p /etc/slurm /var/spool/slurmd /var/run/slurmd /var/run/slurmctld /var/log/slurmd /var/log/slurmctld

    chown -R $SLURM_GROUP:$SLURM_USER /var/spool/slurmd /var/run/slurmd /var/run/slurmctld /var/log/slurmd /var/log/slurmctld

    wget https://github.com/SchedMD/slurm/archive/slurm-$SLURM_VERSION.tar.gz

    tar xvfz slurm-$SLURM_VERSION.tar.gz

    cd slurm-slurm-$SLURM_VERSION

    ./configure -libdir=/usr/lib64 --prefix=/usr --sysconfdir=/etc/slurm && make && make install

    install_slurm_config

    if is_master; then
        wget $TEMPLATE_BASE_URL/slurmctld.service
        mv slurmctld.service /usr/lib/systemd/system
        systemctl daemon-reload
        systemctl enable slurmctld
        systemctl start slurmctld
    else
        wget $TEMPLATE_BASE_URL/slurmd.service
        mv slurmd.service /usr/lib/systemd/system
        systemctl daemon-reload
        systemctl enable slurmd
        systemctl start slurmd
    fi

    cd ..
}
install_easybuild()
{
    install_pypacks

    EASYBUILD_HOME=$SHARE_HOME/$HPC_USER/EasyBuild

    if is_master; then
        su - $HPC_USER -c "pip install --install-option --prefix=$EASYBUILD_HOME https://github.com/hpcugent/easybuild-framework/archive/easybuild-framework-v2.5.0.tar.gz"

        # Add Lmod to the HPC users path
        echo 'export PATH=/usr/share/lmod/6.0.15/libexec:$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc

        # Setup Easybuild configuration and paths
        echo 'export PATH=$HOME/EasyBuild/bin:$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc
        echo 'export PYTHONPATH=$HOME/EasyBuild/lib/python2.7/site-packages:$PYTHONPATH' >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export MODULEPATH=$EASYBUILD_HOME/modules/all" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_MODULES_TOOL=Lmod" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_INSTALLPATH=$EASYBUILD_HOME" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_DEBUG=1" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "source /usr/share/lmod/6.0.15/init/bash" >> $SHARE_HOME/$HPC_USER/.bashrc
    fi
}

install_go()
{
    wget https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.6.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
}

install_torque()
{
if is_master; then
# Prep packages
# Download the source package
cd /tmp >> /tmp/azure_pbsdeploy.log.$$ 2>&1
wget http://www.adaptivecomputing.com/index.php?wpfb_dl=3170 -O torque.tar.gz >> /tmp/azure_pbsdeploy.log.$$ 2>&1
tar xzvf torque.tar.gz >> /tmp/azure_pbsdeploy.log.$$ 2>&1
cd torque-6.1.0* >> /tmp/azure_pbsdeploy.log.$$ 2>&1

# Build
./configure >> /tmp/azure_pbsdeploy.log.$$ 2>&1
make >> /tmp/azure_pbsdeploy.log.$$ 2>&1
make packages >> /tmp/azure_pbsdeploy.log.$$ 2>&1
make install >> /tmp/azure_pbsdeploy.log.$$ 2>&1

export PATH=/usr/local/bin/:/usr/local/sbin/:$PATH

# Create and start trqauthd
cp contrib/init.d/trqauthd /etc/init.d/ >> /tmp/azure_pbsdeploy.log.$$ 2>&1
chkconfig --add trqauthd >> /tmp/azure_pbsdeploy.log.$$ 2>&1
sh -c "echo /usr/local/lib > /etc/ld.so.conf.d/torque.conf" >> /tmp/azure_pbsdeploy.log.$$ 2>&1
ldconfig >> /tmp/azure_pbsdeploy.log.$$ 2>&1
service trqauthd start >> /tmp/azure_pbsdeploy.log.$$ 2>&1

# Update config
sh -c "echo $MASTER_HOSTNAME > /var/spool/torque/server_name" >> /tmp/azure_pbsdeploy.log.$$ 2>&1

env "PATH=$PATH" sh -c "echo 'y' | ./torque.setup root" >> /tmp/azure_pbsdeploy.log.$$ 2>&1

sh -c "echo $MASTER_HOSTNAME > /var/spool/torque/server_priv/nodes" >> /tmp/azure_pbsdeploy.log.$$ 2>&1

# Start pbs_server
cp contrib/init.d/pbs_server /etc/init.d >> /tmp/azure_pbsdeploy.log.$$ 2>&1
chkconfig --add pbs_server >> /tmp/azure_pbsdeploy.log.$$ 2>&1
service pbs_server restart >> /tmp/azure_pbsdeploy.log.$$ 2>&1

# Start pbs_mom
cp contrib/init.d/pbs_mom /etc/init.d >> /tmp/azure_pbsdeploy.log.$$ 2>&1
chkconfig --add pbs_mom >> /tmp/azure_pbsdeploy.log.$$ 2>&1
service pbs_mom start >> /tmp/azure_pbsdeploy.log.$$ 2>&1

# Start pbs_sched
env "PATH=$PATH" pbs_sched >> /tmp/azure_pbsdeploy.log.$$ 2>&1
# Push packages to compute nodes
c=0
rm -rf /tmp/hosts
echo "$MASTER_HOSTNAME" > /tmp/host
while [ $c -lt $WORKER_COUNT ]
do
        printf "\n$WORKER_HOSTNAME_PREFIX$c">> /tmp/host
        workerhost=$WORKER_HOSTNAME_PREFIX$c
        #su -c  "scp /tmp/torque-6.0.1*/torque-package-mom-linux-x86_64.sh $HPC_USER@$workerhost:/tmp" $HPC_USER
        #sudo -u $HPC_USER ssh -tt $workerhost| sudo -kS /tmp/torque-6.0.1*/torque-package-mom-linux-x86_64.sh --install
        #su -c "ssh compnode0 'sudo /tmp/torque-package-mom-linux-x86_64.sh --install'" hpcuser
        #sudo -u $HPC_USER ssh -tt $workerhost| sudo -kS /usr/local/sbin/pbs_mom
        #su -c "ssh compnode0 'sudo /usr/local/sbin/pbs_mom'" hpcuser      
        service pbs_mom stop
        ####Keeping the following three lines for computenode remote ssh script execution but this won't work as compnodes are not created yet####
        #su -c  "scp /tmp/torque-6.0.1*/torque-package-mom-linux-x86_64.sh $HPC_USER@$workerhost:/tmp" $HPC_USER	
	#su -c "ssh $workerhost 'sudo /tmp/torque-package-mom-linux-x86_64.sh --install'" $HPC_USER	
        #su -c "ssh $workerhost 'sudo /usr/local/sbin/pbs_mom'" $HPC_USER
        service pbs_mom start
        echo $workerhost >> /var/spool/torque/server_priv/nodes
         echo $workerhost
        (( c++ ))
done
sed '2d' /tmp/host > /tmp/hosts
rm -rf /tmp/host


# Push packages to compute nodes
## i=0
## while [ $i -lt $NUM_OF_VM ]
## do
##  worker=$WORKER_NAME$i
##  sudo -u $ADMIN_USERNAME scp /tmp/hosts.$$ $ADMIN_USERNAME@$worker:/tmp/hosts >> /tmp/azuredeploy.log.$$ 2>&1
##  sudo -u $ADMIN_USERNAME scp torque-package-mom-linux-x86_64.sh $ADMIN_USERNAME@$worker:/tmp/. >> /tmp/azuredeploy.log.$$ 2>&1
##  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS sh -c 'cat /tmp/hosts>>/etc/hosts'"
##  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS /tmp/torque-package-mom-linux-x86_64.sh --install"
##  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS /usr/local/sbin/pbs_mom"
##  echo $worker >> /var/spool/torque/server_priv/nodes
##  i=`expr $i + 1`
##done

# Restart pbs_server
service pbs_server restart >> /tmp/azure_pbsdeploy.log.$$ 2>&1

cp /var/spool/torque/server_priv/nodes  $SHARE_HOME/$HPC_USER/machines.LINUX
#pbsnodes -a|sed -n -e '/=Linux/ s/.*\=Linux *//p'|cut -d ' ' -f1> $SHARE_HOME/$HPC_USER/machines.LINUX
#cp /var/spool/torque/server_priv/nodes $SHARE_HOME/$HPC_USER/machines.LINUX
chown $HPC_USER:$HPC_USER $SHARE_HOME/$HPC_USER/machines.LINUX
service pbs_mom start
else

        su -c "scp $HPC_USER@$MASTER_HOSTNAME:/tmp/torque-6.1.0*/torque-package-mom-linux-x86_64.sh /tmp" $HPC_USER	
	su -c "sudo /tmp/torque-package-mom-linux-x86_64.sh --install" $HPC_USER	
        su -c "sudo /usr/local/sbin/pbs_mom" $HPC_USER
        su -c "ssh $MASTER_HOSTNAME 'sudo service pbs_server restart'" $HPC_USER
fi
}
install_pbspro()
{
yum install -y gcc make rpm-build libtool hwloc-devel \
      libX11-devel libXt-devel libedit-devel libical-devel \
      ncurses-devel perl postgresql-devel python-devel tcl-devel \
      tk-devel swig expat-devel openssl-devel libXext libXft \
      autoconf automake \
      expat libedit postgresql-server python \
      sendmail sudo tcl tk libical --setopt=protected_multilib=false

if is_master; then
# Prep packages
# Download the source package
cd /tmp >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
wget -qO- -O tmp.zip https://github.com/PBSPro/pbspro/archive/master.zip >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
unzip tmp.zip >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
rm -rf tmp.zip >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

# Build
cd pbspro-master >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
./autogen.sh >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
./configure --prefix=/opt/pbs >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
make  >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
make install >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

/opt/pbs/libexec/pbs_postinstall >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

 . /etc/profile.d/pbs.sh >> /tmp/azure_pbsprodeploy.log.$$ 2>&1
 
 /etc/init.d/pbs start >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

# Push packages to compute nodes
c=0
rm -rf /tmp/hosts
echo "$MASTER_HOSTNAME" > /tmp/host
while [ $c -lt $WORKER_COUNT ]
do
        printf "\n$WORKER_HOSTNAME_PREFIX$c">> /tmp/host
        workerhost=$WORKER_HOSTNAME_PREFIX$c     
        echo "$workerhost np=1" >> /var/spool/pbs/server_priv/nodes
        echo $workerhost
        qmgr -c "create node $workerhost"
        qmgr -c "s s job_history_enable = true"
        qmgr -c "s s job_history_duration = 336:0:0"
        qmgr -c "s s managers = $HPC_USER@*"
        (( c++ ))
done
# MASTER also has pbs_mom started
echo "$MASTER_HOSTNAME np=1" >> /var/spool/torque/server_priv/nodes
qmgr -c "create node $MASTER_HOSTNAME"
su -c "cd /etc && sudo sed -i.bak -e '5d' pbs.conf" $HPC_USER
su -c "cd /etc && sudo sed -i '5iPBS_START_MOM=1' pbs.conf" $HPC_USER

sed '2d' /tmp/host > /tmp/hosts
rm -rf /tmp/host


# restart pbs_server
/etc/init.d/pbs restart >> /tmp/azure_pbsprodeploy.log.$$ 2>&1

cp /var/spool/pbs/server_priv/nodes  $SHARE_HOME/$HPC_USER/machines.LINUX

chown $HPC_USER:$HPC_USER $SHARE_HOME/$HPC_USER/machines.LINUX
/etc/init.d/pbs start
else
        su -c "scp -r $HPC_USER@$MASTER_HOSTNAME:/tmp/pbspro-master/ /tmp" $HPC_USER	
	su -c "cd /tmp/pbspro-master/ && sudo ./autogen.sh" $HPC_USER	
        su -c "cd /tmp/pbspro-master/ && sudo ./configure --prefix=/opt/pbs" $HPC_USER
        su -c "cd /tmp/pbspro-master/ && sudo make" $HPC_USER
        su -c "cd /tmp/pbspro-master/ && sudo make install" $HPC_USER
        su -c "sudo /opt/pbs/libexec/pbs_postinstall" $HPC_USER
        su -c "sudo chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp" $HPC_USER
        su -c "sudo /etc/init.d/pbs start" $HPC_USER	
	#su -c "rm -rf /etc/pbs.conf" hpc
	#su -c "scp -r $HPC_USER@$MASTER_HOSTNAME:/etc/pbs.conf /etc" $HPC_USER
        su -c "cd /etc && sudo sed -i.bak -e '5d' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i '5iPBS_START_MOM=1' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i.bak -e '2d' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i '2iPBS_START_SERVER=0' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i.bak -e '3d' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i '3iPBS_START_SCHED=0' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i.bak -e '4d' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i '4iPBS_START_COMM=0' pbs.conf" $HPC_USER
	su -c "cd /etc && sudo sed -i.bak -e '1d' pbs.conf" $HPC_USER
        su -c "cd /etc && sudo sed -i "1iPBS_SERVER=$MASTER_HOSTNAME" pbs.conf" $HPC_USER
	su -c "sudo /etc/init.d/pbs restart" $HPC_USER
        su -c "ssh $MASTER_HOSTNAME 'sudo /etc/init.d/pbs restart'" $HPC_USER
fi
}
install_cuda75()
{
enable_kernel_update
yum-config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64
NVIDIA_GPGKEY_SUM=bd841d59a27a406e513db7d405550894188a4c1cd96bf8aa4f82f1b39e0b5c1c
curl -fsSL http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY \
 | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA
echo "$NVIDIA_GPGKEY_SUM /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -
yum clean all
rpm --import http://developer.download.nvidia.com/compute/cuda/repos/GPGKEY
yum install -y cuda nvcc
export CUDA_HOME=/usr/local/cuda-7.5
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
export PATH=${CUDA_HOME}/bin:${PATH}
disable_kernel_update
}
install_vnc_head()
{
    if is_master; then
yum -y groupinstall 'Server with GUI' 'GNOME Desktop' && systemctl enable graphical.target && yum install -y vnc-server
    fi
}
 
install_modules()
{
yum install -y tcl tcl-devel
# /usr/local/Modules/3.2.10/init/.modulespath needs to change
wget http://sourceforge.net/projects/modules/files/latest/download?source=files -O modules-3.2.10.tar.gz
tar -zxvf modules-3.2.10.tar.gz
cd modules-3.2.10 
./configure --with-module-path=/usr/local/Modules/contents && make && make install

cat >> /etc/sysctl.conf <<EOF
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 65536
net.ipv4.ip_local_port_range = 1024 65000
net.core.rmem_default=4194304
net.core.wmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_max=262144
EOF
/sbin/sysctl -p

cat >> /etc/profile.d/modules.sh <<EOF
# system-wide profile.modules                                          #
# Initialize modules for all sh-derivative shells                      #
#----------------------------------------------------------------------#
trap "" 1 2 3

case "$0" in
-bash|bash|*/bash) . /usr/local/Modules/3.2.10/init/bash ;;
-ksh|ksh|*/ksh) . /usr/local/Modules/3.2.10/init/ksh ;;
-zsh|zsh|*/zsh) . /usr/local/Modules/3.2.10/init/zsh ;;
*) . /usr/local/Modules/3.2.10/init/sh ;; # sh and default for scripts esac
esac
trap - 1 2 3
EOF
}
install_cuda8_ubuntu1604()
{
DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
# workaround: CUDA 8.0 RC doesn't support gcc 5.4 without the following patch at the end
export CUDA_DOWNLOAD_SUM=24278d78afed380b4328c1e2f917b31d70c3f4c8f297b642200e003311944c22 && export CUDA_PKG_VERSION=8-0 && curl -o cuda-repo.deb -fsSL http://developer.download.nvidia.com/compute/cuda/8.0/direct/cuda-repo-ubuntu1604-8-0-rc_8.0.27-1_amd64.deb && \
    echo "$CUDA_DOWNLOAD_SUM  cuda-repo.deb" | sha256sum -c --strict - && \
    dpkg -i cuda-repo.deb && \
    rm cuda-repo.deb && \
    apt-get update && apt-get install -y --no-install-recommends \
        cuda-core-$CUDA_PKG_VERSION \
        cuda-misc-headers-$CUDA_PKG_VERSION \
        cuda-command-line-tools-$CUDA_PKG_VERSION \
        cuda-nvrtc-dev-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION \
        cuda-nvgraph-dev-$CUDA_PKG_VERSION \
        cuda-cusolver-dev-$CUDA_PKG_VERSION \
        cuda-cublas-dev-$CUDA_PKG_VERSION \
        cuda-cufft-dev-$CUDA_PKG_VERSION \
        cuda-curand-dev-$CUDA_PKG_VERSION \
        cuda-cusparse-dev-$CUDA_PKG_VERSION \
        cuda-npp-dev-$CUDA_PKG_VERSION \
        cuda-cudart-dev-$CUDA_PKG_VERSION \
        cuda-driver-dev-$CUDA_PKG_VERSION && \
    apt-get remove --purge -y cuda-repo-ubuntu1604-8-0-rc && \
    rm -rf /var/lib/apt/lists/* && export PATCH_DOWNLOAD_SUM=05c465d509f92b41b8a0022abdbcbaeaa8f6a9d98dc03db1e0d8d2506e056efd && curl -o patch.deb -fsSL http://developer.download.nvidia.com/compute/cuda/8.0/direct/cuda-misc-headers-8-0_8.0.27.1-1_amd64.deb && \
    echo "$PATCH_DOWNLOAD_SUM  patch.deb" | sha256sum -c --strict - && \
    dpkg -i patch.deb && \
    rm patch.deb && export LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LIBRARY_PATH}	
}
install_cuda8044_ubuntu1604()
{
DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
export CUDA_DOWNLOAD_SUM=1f4dffe1f79061827c807e0266568731 && export CUDA_PKG_VERSION=8-0 && curl -o cuda-repo.deb -fsSL http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.61-1_amd64.deb && \
    echo "$CUDA_DOWNLOAD_SUM  cuda-repo.deb" | md5sum -c --strict - && \
    dpkg -i cuda-repo.deb && \
    rm cuda-repo.deb && \
    apt-get update -y && apt-get install -y cuda && \
    apt-get install -y nvidia-cuda-toolkit && \
export LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:${LIBRARY_PATH}  && export LIBRARY_PATH=/usr/local/cuda-8.0/lib64/stubs:${LIBRARY_PATH} && \
export PATH=/usr/local/cuda-8.0/bin:${PATH}
 if is_master; then
#/usr/local/cuda-8.0/bin/./cuda-install-samples-8.0.sh $SHARE_DATA
su -c "/usr/local/cuda-8.0/bin/./cuda-install-samples-8.0.sh $SHARE_DATA" $HPC_USER
else
echo "already installed on share"
fi
}
install_cudann5_ubuntu1604()
{
    export CUDNN_DOWNLOAD_SUM=a87cb2df2e5e7cc0a05e266734e679ee1a2fadad6f06af82a76ed81a23b102c8 && curl -fsSL http://developer.download.nvidia.com/compute/redist/cudnn/v5.1/cudnn-8.0-linux-x64-v5.1.tgz -O && \
    echo "$CUDNN_DOWNLOAD_SUM  cudnn-8.0-linux-x64-v5.1.tgz" | sha256sum -c --strict - && \
    tar -xzf cudnn-8.0-linux-x64-v5.1.tgz -C /usr/local && \
    rm cudnn-8.0-linux-x64-v5.1.tgz && \
    ldconfig
}
installomsagent()
{
#wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_Ignite2016_v$omslnxagentver/omsagent-${omslnxagentver}.universal.x64.sh
#wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent-201610-v1.2.0-148/omsagent-1.2.0-148.universal.x64.sh
wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent-201610-v$omslnxagentver/omsagent-${omslnxagentver}.universal.x64.sh
#wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent-201702-v$omslnxagentver/omsagent-${omslnxagentver}.universal.x64.sh
chmod +x ./omsagent-${omslnxagentver}.universal.x64.sh
md5sum ./omsagent-${omslnxagentver}.universal.x64.sh
sudo sh ./omsagent-${omslnxagentver}.universal.x64.sh --upgrade -w $omsworkspaceid -s $omsworkspacekey
}

instrumentfluentd_docker_centos72()
{
cd /usr/lib/systemd/system/ && sed -i.bak -e '11d' docker.service
cd /usr/lib/systemd/system/ && sed -i '11iEnvironment="DOCKER_OPTS=--log-driver=fluentd --log-opt fluentd-address=localhost:25225"' docker.service
cd /usr/lib/systemd/system/ && sed -i '12iExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS' docker.service
service docker restart
systemctl daemon-reload
service docker restart
}
install_cuda8centos()
{
enable_kernel_update
#wget http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-8.0.44-1.x86_64.rpm
#rpm -i cuda-repo-rhel7-8.0.44-1.x86_64.rpm
wget http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-8.0.61-1.x86_64.rpm
rpm -i cuda-repo-rhel7-8.0.61-1.x86_64.rpm
yum clean all
yum install -y cuda
disable_kernel_update
}

postinstall_centos73kde()
{
#Keep VNC Off for now
#yum install -y vnc*
#systemctl enable vncserver@:1.service
#cp /usr/lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@.service
#systemctl daemon-reload

# Switch off service
#echo "[Service]">/etc/systemd/system/vncserver@:1.service
#echo "Type=forking">>/etc/systemd/system/vncserver@:1.service
#echo "ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'">>/etc/systemd/system/vncserver@:1.service
#echo "ExecStart=/sbin/runuser -l root -c "/usr/bin/vncserver %i"">>/etc/systemd/system/vncserver@:1.service
#echo "PIDFile=/root/.vnc/%H%i.pid">>/etc/systemd/system/vncserver@:1.service
#echo "ExecStop=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'">>/etc/systemd/system/vncserver@:1.service

# Quit playing with xstartup
#echo "#!/bin/sh">~/.vnc/xstartup
#echo "unset SESSION_MANAGER">>~/.vnc/xstartup
#echo "unset DBUS_SESSION_BUS_ADDRESS">>~/.vnc/xstartup
#echo "startkde &">>~/.vnc/xstartup

#Install KDE and make graphical default target
yum groupinstall -y 'KDE' 'X Window System' 'Fonts'
#yum install -y xinetd vnc-ltsp-config kde-workspace gdm
yum install -y vnc-ltsp-config kde-workspace gdm
ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target
systemctl isolate graphical.target
}

postinstall_centos73nc24rgpu()
{ 
yum clean all
#yum update -y kernel\* selinux-policy\* dkms
yum update -y  dkms
yum install -y gcc make binutils gcc-c++ kernel-devel kernel-headers
grub2-mkconfig -o /boot/grub2/grub.cfg
cd /etc/default && sed -i.bak -e '6d' grub
cd /etc/default && sed -i '6iGRUB_CMDLINE_LINUX="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0 rdblacklist=nouveau nouveau.modeset=0"' grub
echo "blacklist nouveau" | tee /etc/modprobe.d/blacklist.conf
yum install -y  xorg-x11-drv*
yum erase -y xorg-x11-drv-nouveau
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
echo "    options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
dracut --force
#wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/lis-rpms-4.1.3.tar.gz
#tar -zxvf lis-rpms-4.1.3.tar.gz
wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/NVIDIA-Linux-x86_64-367.64-grid.run
chmod +x NVIDIA-Linux-x86_64-367.64-grid.run
./NVIDIA-Linux-x86_64-367.64-grid.run --silent --dkms --install-libglvnd
dracut --force
git clone https://github.com/LIS/lis-next.git && cd lis-next/hv-rhel7.x/hv/
./rhel7-hv-driver-install
systemctl stop waagent
systemctl disable waagent
chmod +x /etc/rc.d/rc.local
echo "sleep 240" >> /etc/rc.d/rc.local && echo "systemctl enable waagent" >> /etc/rc.d/rc.local && echo "systemctl start waagent" >> /etc/rc.d/rc.local
 # mv /usr/lib64/xorg/modules/extensions/libglx.so /usr/lib64/xorg/modules/extensions/libglx.so.xorg
 #ln -s /usr/lib64/xorg/modules/extensions/libglx.so.367.64 /usr/lib64/xorg/modules/extensions/libglx.so
 # ln -s /usr/lib64/xorg/modules/extensions/libglx.so.367.64 /usr/lib64/xorg/modules/extensions/libglx.so.xorg
 #reboot
}


ubuntunvidiadesktop()
{
apt-get update -y
apt-get install -y --no-install-recommends  ubuntu-desktop gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal
DEBIAN_FRONTEND=noninteractive update-initramfs -u
grub-mkconfig -o /boot/grub/grub.cfg
cd /etc/default && sed -i.bak -e '11d' grub
cd /etc/default && sed -i '11iGRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 earlyprintk=ttyS0 rootdelay=300 rdblacklist=nouveau nouveau.modeset=0"' grub
update-grub
echo 'blacklist nouveau' | tee -a /etc/modprobe.d/blacklist.conf
echo 'options nouveau modeset=0' | tee -a  /etc/modprobe.d/blacklist-nouveau.conf
echo 'alias nouveau off' | tee -a  /etc/modprobe.d/blacklist-nouveau.conf
service lightdm stop 
#service lightdm disable placeholder
echo options nouveau modeset=0 | tee -a /etc/modprobe.d/nouveau-kms.conf
rmmod nouveau
DEBIAN_FRONTEND=noninteractive update-initramfs -u
#wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/NVIDIA-Linux-x86_64-367.64-grid.run
#wget http://us.download.nvidia.com/XFree86/Linux-x86_64/375.39/NVIDIA-Linux-x86_64-375.39.run&lang=us&type=Tesla
#wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/NVIDIA-Linux-x86_64-367.92-grid.run
wget https://tdcm16sg112leo8193ls102.blob.core.windows.net/tdcm16sg112leo8193ls102/azurenvidia42/NVIDIA-Linux-x86_64-367.92-grid.run
chmod +x NVIDIA-Linux-x86_64-367.92-grid.run
DEBIAN_FRONTEND=noninteractive apt-mark hold walinuxagent
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential gcc gcc-multilib dkms g++ make binutils linux-headers-`uname -r`
DEBIAN_FRONTEND=noninteractive ./NVIDIA-Linux-x86_64-367.92-grid.run  --silent --dkms
DEBIAN_FRONTEND=noninteractive update-initramfs -u
##Options for PCOIP- commented now##
#echo 'IgnoreSP=TRUE' | tee -a /etc/nvidia/gridd.conf
#echo 'FeatureType=2' | tee -a /etc/nvidia/gridd.conf
systemctl enable nvidia-gridd
systemctl restart nvidia-gridd

apt-key adv --keyserver pool.sks-keyservers.net --recv-key 67D7ADA8
wget -O /etc/apt/sources.list.d/pcoip.list https://downloads.teradici.com/ubuntu/pcoip-beta.repo
apt-get update -y
apt-get install -y pcoip-agent-graphics
#manual registration
#pcoip-register-host --registration-code=xx
#systemctl enable pcoip
}


#########################
### Place holder for common GPU/HPC Sku operations on both master and computes ###

cat <<EOT >> /etc/profile
if [ "\$USER" = "$HPC_USER" ]; then
    if [ $SHELL = "/bin/ksh" ]; then
        ulimit -p 16384
        ulimit -n 65536
    else
        ulimit -s unlimited
    fi
fi
EOT


echo "$HPC_USER               hard    memlock         unlimited" >> /etc/security/limits.conf
echo "$HPC_USER               soft    memlock         unlimited" >> /etc/security/limits.conf

install_saltsaltstack_centos()
{

if is_master; then
# Install full stack
enable_kernel_update
yum --enablerepo=epel-testing install -y salt-master && yum --enablerepo=epel-testing install -y salt-minion && yum --enablerepo=epel-testing install -y salt-ssh && yum --enablerepo=epel-testing install -y salt-syndic && yum --enablerepo=epel-testing install -y salt-cloud
disable_kernel_update
systemctl enable salt-master.service
systemctl start salt-master.service

# Now for the minions
else
        enable_kernel_update
        su -c "sudo yum --enablerepo=epel-testing install -y salt-minion && yum --enablerepo=epel-testing install -y salt-ssh" $HPC_USER
        disable_kernel_update
	sed -i "s/#master: salt/master: $MASTER_HOSTNAME/" /etc/salt/minion
	su -c "sudo systemctl enable salt-minion.service" $HPC_USER
	su -c "sudo systemctl start salt-minion.service" $HPC_USER
        su -c "sudo systemctl restart salt-minion.service" $HPC_USER
	workerhostintip="$(hostname --fqdn)"
	su -c "ssh $MASTER_HOSTNAME "sudo salt-key -a $workerhostintip -y"" $HPC_USER
	su -c "sudo systemctl restart salt-minion.service" $HPC_USER
fi
}

install_saltsaltstack_ubuntu()
{

if is_master; then
# Install full stack
wget -O - https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
echo "deb http://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest xenial main" | sudo tee /etc/apt/sources.list.d/saltstack.list
DEBIAN_FRONTEND=noninteractive apt-get update -y
apt-get install -y salt-master
apt-get install -y  salt-minion
apt-get install -y salt-ssh
apt-get install -y salt-syndic
apt-get install -y  salt-cloud
apt-get install -y salt-api
systemctl enable salt-master.service
systemctl start salt-master.service

# Now for the minions
else

        su -c "sudo apt-get install -y salt-minion && apt-get install -y salt-ssh" $HPC_USER
	sed -i "s/#master: salt/master: $MASTER_HOSTNAME/" /etc/salt/minion
	su -c "sudo systemctl enable salt-minion.service" $HPC_USER
	su -c "sudo systemctl start salt-minion.service" $HPC_USER	
	workerhostintip="$(hostname --fqdn)"
	su -c "ssh $MASTER_HOSTNAME 'sudo salt-key -a $workerhostintip -y'" $HPC_USER
	su -c "sudo systemctl restart salt-minion.service" $HPC_USER
fi
}

#########################
	if [ "$skuName" == "16.04-LTS" ] ; then
		install_packages_ubuntu
		DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-common
		setup_shares
		setup_hpc_user
                install_docker_ubuntu
                install_docker_apps
		 if [ "$SALTSTACKBOOLEAN" == "Yes" ] ; then
		    install_saltsaltstack_ubuntu
		 fi
		if [[ "${HEADNODE_SIZE}" =~ "NC" ]] && [[ "${WORKERNODE_SIZE}" =~ "NC" ]] && [[ "${HEADNODE_SIZE}" =~ "R" ]] && [[ "${WORKERNODE_SIZE}" =~ "R" ]];then
		    echo "this is a NC with RDMA"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
                install_nvdia_ubuntu
                install_cudann5_ubuntu1604
                #install_cuda8_ubuntu1604
		install_cuda8044_ubuntu1604
		elif [[ "${HEADNODE_SIZE}" =~ "H" ]] && [[ "${WORKERNODE_SIZE}" =~ "H" ]] && [[ "${HEADNODE_SIZE}" =~ "R" ]] && [[ "${WORKERNODE_SIZE}" =~ "R" ]];then
		    echo "this is a H with RDMA"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi		    
		elif [[ "${HEADNODE_SIZE}" =~ "H" ]] && [[ "${WORKERNODE_SIZE}" =~ "H" ]];then
		        echo "this is a H"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi		        
		elif [[ "${HEADNODE_SIZE}" =~ "NV" ]] && [[ "${WORKERNODE_SIZE}" =~ "NV" ]];then
		        echo "this is a NV"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
		 ubuntunvidiadesktop
		 ( sleep 15 ; reboot ) &
		elif [[ "${HEADNODE_SIZE}" =~ "NC" ]] && [[ "${WORKERNODE_SIZE}" =~ "NC" ]];then
		        echo "this is a NC"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi	
                install_nvdia_ubuntu
                install_cudann5_ubuntu1604
                #install_cuda8_ubuntu1604
		install_cuda8044_ubuntu1604	        
		fi
                
	elif [ "$skuName" == "6.5" ] || [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] || [ "$skuName" == "7.3" ] ; then
		install_pkgs_all
		setup_shares
		setup_hpc_user
		setup_env
		#install_cuda75
		#install_modules
		#install_munge
		#install_slurm
		#install_vnc_head
		#install_easybuild
		#install_go
		#reboot
		    if [ "$SALTSTACKBOOLEAN" == "Yes" ] ; then
		    install_saltsaltstack_centos
		    fi
		if [[ "${HEADNODE_SIZE}" =~ "NC" ]] && [[ "${WORKERNODE_SIZE}" =~ "NC" ]] && [[ "${HEADNODE_SIZE}" =~ "R" ]] && [[ "${WORKERNODE_SIZE}" =~ "R" ]];then
		    echo "this is a NC with RDMA"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
		    enable_kernel_update
		    install_cuda8centos
		    install_cudann5_ubuntu1604
		    postinstall_centos73nc24rgpu
		    disable_kernel_update
		    ( sleep 15 ; reboot ) &
		elif [[ "${HEADNODE_SIZE}" =~ "H" ]] && [[ "${WORKERNODE_SIZE}" =~ "H" ]] && [[ "${HEADNODE_SIZE}" =~ "R" ]] && [[ "${WORKERNODE_SIZE}" =~ "R" ]];then
		    echo "this is a H with RDMA"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
		    
	            if [ "$TORQUEORPBS" == "Torque" ] ; then
		    install_torque
		    else
		    enable_kernel_update
		    install_pbspro
		    disable_kernel_update
		    fi
		    
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/etc/profile
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/root/.bash_profile

		elif [[ "${HEADNODE_SIZE}" =~ "H" ]] && [[ "${WORKERNODE_SIZE}" =~ "H" ]];then
		        echo "this is a H"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
		    
	            if [ "$TORQUEORPBS" == "Torque" ] ; then
		    install_torque
		    else
		    enable_kernel_update
		    install_pbspro
		    disable_kernel_update
		    fi
		    
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/etc/profile
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/root/.bash_profile
		elif [[ "${HEADNODE_SIZE}" =~ "A" ]] && [[ "${WORKERNODE_SIZE}" =~ "A" ]] && [[ "${HEADNODE_SIZE}" =~ "9" ]] && [[ "${WORKERNODE_SIZE}" =~ "9" ]];then
		    echo "this is a A9 with RDMA"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
		    
	            if [ "$TORQUEORPBS" == "Torque" ] ; then
		    install_torque
		    else
		    enable_kernel_update
		    install_pbspro
		    disable_kernel_update
		    fi
		    
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/etc/profile
		    echo 'export PATH=/opt/intel/compilers_and_libraries_2016/linux/mpi/bin64:/usr/local/bin:/usr/local/sbin:$PATH' >>/root/.bash_profile    
		elif [[ "${HEADNODE_SIZE}" =~ "NV" ]] && [[ "${WORKERNODE_SIZE}" =~ "NV" ]];then
		        echo "this is a NV"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi
                    postinstall_centos73nc24rgpu;
                    postinstall_centos73kde;
		    ( sleep 15 ; reboot ) &
		elif [[ "${HEADNODE_SIZE}" =~ "NC" ]] && [[ "${WORKERNODE_SIZE}" =~ "NC" ]];then
		        echo "this is a NC"
		    if [ ! -z "$omsworkspaceid" ]; then
		    sleep 30;
		    installomsagent;
		    fi	
		    install_cuda8centos;
                    install_cudann5_ubuntu1604;
		    postinstall_centos73nc24rgpu;
		    ( sleep 15 ; reboot ) &
		fi
                		
                #if [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] ; then
		#sleep 45;
		#instrumentfluentd_docker_centos72;
		#else
		#echo "Fluentd injection omitted";
		#fi
	fi
