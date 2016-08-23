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
LAST_WORKER_INDEX=$(($WORKER_COUNT - 1))

# Shares
MNT_POINT="$3"
SHARE_HOME=$MNT_POINT/home
SHARE_DATA=$MNT_POINT/data

# Munged
MUNGE_VERSION=$( echo "$4" |cut -d\: -f1 )
MUNGE_USER=$( echo "$4" |cut -d\: -f2 )
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
cd /etc && sed -i.bak -e '28d' yum.conf
cd /etc && sed -i '28i#exclude=kernel*' yum.conf
}

disable_kernel_update()
{
cd /etc && sed -i.bak -e '28d' yum.conf
cd /etc && sed -i '28iexclude=kernel*' yum.conf
}

# Partitions all data disks attached to the VM and creates
# a RAID-0 volume with them.
#
setup_data_disks()
{
    mountPoint="$1"
    createdPartitions=""

    # Loop through and partition disks until not found
    for disk in sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr; do
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
    yum --exclude WALinuxAgent,intel-*,kernel*,*microsoft-*,msft-* -y update 

    set_time
}

install_docker()
{

    wget -qO- "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e" 
    rpm --import "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
    yum install -y yum-utils
    yum-config-manager --add-repo https://packages.docker.com/$dockerVer/yum/repo/main/centos/7
    yum install -y docker-engine 
    systemctl stop firewalld
    systemctl disable firewalld
    #service docker start
    gpasswd -a $userName docker
    systemctl start docker
    systemctl enable docker
    curl -L https://github.com/docker/compose/releases/download/$dockerComposeVer/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    curl -L https://github.com/docker/machine/releases/download/v0.7.0/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine && \
    chmod +x /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-compose
    export PATH=$PATH:/usr/local/bin/
    systemctl restart docker
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
    if is_master; then
    docker run -it -d --restart=always -p 8080:8080 rancher/server
    fi
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
	elif [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] ; then

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
	setup_dynamicdata_disks $SHARE_DATA
        echo "$SHARE_HOME    *(rw,async)" >> /etc/exports
        echo "$SHARE_DATA    *(rw,async)" >> /etc/exports

        systemctl enable rpcbind || echo "Already enabled"
        systemctl enable nfs-server || echo "Already enabled"
        systemctl start rpcbind || echo "Already enabled"
        systemctl start nfs-server || echo "Already enabled"
    else
        echo "$MASTER_HOSTNAME:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
        echo "$MASTER_HOSTNAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
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

	if [ "$skuName" == "16.04.0-LTS" ] ; then
		/etc/init.d/apparmor stop 
		/etc/init.d/apparmor teardown 
		update-rc.d -f apparmor remove
		apt-get -y remove apparmor

	elif [ "$skuName" == "6.5" ] || [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] ; then
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
wget http://www.adaptivecomputing.com/index.php?wpfb_dl=3032 -O torque.tar.gz >> /tmp/azure_pbsdeploy.log.$$ 2>&1
tar xzvf torque.tar.gz >> /tmp/azure_pbsdeploy.log.$$ 2>&1
cd torque-6.0.1* >> /tmp/azure_pbsdeploy.log.$$ 2>&1

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
        sudo -u $HPC_USER ssh -tt $workerhost| sudo -kS /tmp/torque-6.0.1*/torque-package-mom-linux-x86_64.sh --install
        service pbs_mom stop
        sudo -u $HPC_USER ssh -tt $workerhost| sudo -kS /usr/local/sbin/pbs_mom
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
	if [ "$skuName" == "16.04.0-LTS" ] ; then
		setup_shares
		setup_hpc_user

	elif [ "$skuName" == "6.5" ] || [ "$skuName" == "6.6" ] || [ "$skuName" == "7.2" ] || [ "$skuName" == "7.1" ] ; then
		install_pkgs_all
		setup_shares
		setup_hpc_user
		setup_env
		install_cuda75
		#install_modules
		install_munge
		install_slurm
		#install_vnc_head
		#install_torque
		#install_easybuild
		#install_go
		#reboot

	fi
