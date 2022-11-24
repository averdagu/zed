#!/bin/bash

NET=1
HOSTNAME=1
DNS=1
HOSTS=1
CEPH=0
REPO=1
LP1982744=1
LP1996482=1
METADATA=1
MANUAL_CONFIG=1
TMATE=0
INSTALL=1
FILES=1
EXPORT=1

CONTROLLER_IP=192.168.24.2
if [ $# -eq 1 ]; then
  COMPUTE_IP=$1
  echo "Using as compute_ip: $COMPUTE_IP"
else
  COMPUTE_IP=192.168.24.100
fi

SSH_OPT="-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null"
HOST=$(hostname -a)

if [[ $NET -eq 1 ]]; then
    # Try to modify hostname since a lot of containers will use it
    # and since we can have multiple hostnames we need to change it
    #HOSTNAME=`hostname`
    #sudo echo "$HOSTNAME" > /etc/hostname
    sudo ip addr add $COMPUTE_IP/24 dev eth0
    ip a s eth0
    ping -c 1 $CONTROLLER_IP
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $CONTROLLER_IP -l stack "uname -a"
    if [[ ! $? -eq 0 ]]; then
        echo "Cannot ssh into $CONTROLLER_IP"
        exit 1
    fi
fi

if [[ $HOSTNAME -eq 1 ]]; then
    sudo setenforce 0
    sudo hostnamectl set-hostname $HOST.localdomain
    sudo hostnamectl set-hostname $HOST.localdomain --transient
    sudo setenforce 1
    IP=$(ip a s eth1 | grep inet | grep 192 | awk {'print $2'} | sed s/\\/24//)
    sudo sed -i "/$IP/d" /etc/hosts
    sudo sh -c "echo $IP $HOST.localdomain $HOST>> /etc/hosts"
fi

if [[ $DNS -eq 1 ]]; then
    GW=192.168.122.1
    sudo sysctl -w net.ipv4.ping_group_range="0 1000"
    ping -c 1 $GW > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Cannot ping $GW. Aborting."
        exit 1
    fi
    if [[ $(grep $GW /etc/resolv.conf | wc -l) -eq 0 ]]; then
        sudo sh -c "echo nameserver $GW > /etc/resolv.conf"
    fi
fi

if [[ $HOSTS -eq 1 ]]; then
    ENTRY1="$CONTROLLER_IP standalone.localdomain standalone"
    ENTRY2="$CONTROLLER_IP standalone.ctlplane.localdomain standalone.ctlplane"
    sudo sh -c "echo $ENTRY1 >> /etc/hosts"
    sudo sh -c "echo $ENTRY2 >> /etc/hosts"
fi

if [[ $CEPH -eq 1 ]]; then
    EXT_CEPH="192.168.122.253"
    ssh $OPT $EXT_CEPH -l stack "ls zed/standalone/ceph_client.yaml"
    if [[ ! $? -eq 0 ]]; then
        echo "Cannot ssh into $EXT_CEPH"
        exit 1
    fi
    scp $OPT stack@$EXT_CEPH:/home/stack/zed/standalone/ceph_client.yaml ~/ceph_client.yaml
    ls -l ~/ceph_client.yaml
fi

if [[ $REPO -eq 1 ]]; then
    if [[ ! -d ~/rpms ]]; then mkdir ~/rpms; fi
    url=https://trunk.rdoproject.org/centos9/component/tripleo/current/
    rpm_name=$(curl $url | grep python3-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
    rpm=$rpm_name.rpm
    curl -f $url/$rpm -o ~/rpms/$rpm
    if [[ -f ~/rpms/$rpm ]]; then
	sudo yum install -y ~/rpms/$rpm
	sudo -E tripleo-repos current-tripleo-dev ceph --stream
	sudo yum repolist
	sudo yum update -y
    else
	echo "$rpm is missing. Aborting."
	exit 1
    fi
fi

if [[ $LP1982744 -eq 1 ]]; then
    # workaround https://bugs.launchpad.net/tripleo/+bug/1982744
    sudo rpm -qa | grep selinux | sort
    sudo dnf install -y container-selinux
    sudo dnf install -y openstack-selinux
    sudo dnf install -y setools-console
    sudo seinfo --type | grep container
    sudo rpm -V openstack-selinux
    if [[ ! $? -eq 0 ]]; then
        echo "LP1982744 will block the deployment"
        exit 1
    fi
fi

if [[ $METADATA -eq 1 ]]; then
    # workaround https://bugs.launchpad.net/tripleo/+bug/1996482
    PATCHSET=4
    if [ ! -d ~/ext/tripleo-ansible ]; then
        echo "tripleo-ansible not found on ~/ext"
        exit 1
    fi
    pushd ~/ext/tripleo-ansible
    git config --global user.email "averdagu@redhat.com"
    git config --global user.name "Arnau Verdaguer"
    git fetch https://review.opendev.org/openstack/tripleo-ansible refs/changes/14/864814/$PATCHSET && git cherry-pick FETCH_HEAD
    if [[ ! $? -eq 0 ]]; then
        echo "My patch was not applied, metadata will fail"
        echo "Currently using patchet $PATCHSET"
        exit 1
    fi
    popd
fi

if [[ $LP1996482 -eq 1 ]]; then
    # workaround https://bugs.launchpad.net/tripleo/+bug/1996482
    if [ ! -d ~/ext/tripleo-ansible ]; then
        echo "tripleo-ansible not found on ~/ext"
        exit 1
    fi
    pushd ~/ext/tripleo-ansible
    git config --global user.email "averdagu@redhat.com"
    git config --global user.name "Arnau Verdaguer"
    git fetch https://review.opendev.org/openstack/tripleo-ansible refs/changes/92/864392/5 && git cherry-pick FETCH_HEAD
    if [[ ! $? -eq 0 ]]; then
        echo "LP1996482 patch was not applied, deployment will fail"
        exit 1
    fi
    popd
fi

if [[ $MANUAL_CONFIG -eq 1 ]]; then
    # workaround while I don't create/pass the neutron and metadata configuration
    if [ ! -d ~/config/etc/neutron/plugins/networking-ovn ]; then
        echo "Creating directory"
        mkdir -p ~/config/etc/neutron/plugins/networking-ovn
    fi
    pushd ~/config/etc/neutron
    ssh $SSH_OPT root@${CONTROLLER_IP} "podman exec -uroot -ti ovn_metadata_agent cat /etc/neutron/neutron.conf > /tmp/neutron.conf"
    ssh $SSH_OPT root@${CONTROLLER_IP} "podman exec -uroot -ti ovn_metadata_agent cat /etc/neutron/rootwrap.conf > /tmp/rootwrap.conf"
    ssh $SSH_OPT root@${CONTROLLER_IP} "podman exec -uroot -ti ovn_metadata_agent cat /etc/neutron/plugins/networking-ovn/networking-ovn-metadata-agent.ini > /tmp/networking-ovn-metadata-agent.ini"
    scp $SSH_OPT root@${CONTROLLER_IP}:/tmp/neutron.conf .
    scp $SSH_OPT root@${CONTROLLER_IP}:/tmp/rootwrap.conf .
    scp $SSH_OPT root@${CONTROLLER_IP}:/tmp/networking-ovn-metadata-agent.ini plugins/networking-ovn/networking-ovn-metadata-agent.ini
    popd
fi

if [[ $TMATE -eq 1 ]]; then
    TMATE_RELEASE=2.4.0
    curl -OL https://github.com/tmate-io/tmate/releases/download/$TMATE_RELEASE/tmate-$TMATE_RELEASE-static-linux-amd64.tar.xz
    sudo mv tmate-$TMATE_RELEASE-static-linux-amd64.tar.xz /usr/src/
    pushd /usr/src/
    sudo tar xf tmate-$TMATE_RELEASE-static-linux-amd64.tar.xz
    sudo mv /usr/src/tmate-$TMATE_RELEASE-static-linux-amd64/tmate /usr/local/bin/tmate
    sudo chmod 755 /usr/local/bin/tmate
    popd
fi

if [[ $INSTALL -eq 1 ]]; then
    sudo dnf install -y ansible-collection-containers-podman python3-tenacity ansible-collection-community-general ansible-collection-ansible-posix
fi

if [[ $FILES -eq 1 ]]; then
    # workaround https://paste.opendev.org/show/boSZ8vBqsblPYKKN8ASe/
    # workaround https://paste.opendev.org/show/bY8SzmXGy0BWV4rWvZRY/
    pushd /home/stack/ext/tripleo-ansible/tripleo_ansible/playbooks
    ln -s ../../roles/tripleo_nova_libvirt/files/
    popd
fi

if [[ $EXPORT -eq 1 ]]; then
    DIR=$(dirname `find . -name export.sh`)
    pushd $DIR
    bash export.sh $COMPUTE_IP
    popd

fi

