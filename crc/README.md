# OpenStack Operators on CRC

- [crc.sh](crc.sh): clone [install_yamls](https://github.com/openstack-k8s-operators/install_yamls) and install CRC
- [rabbit.sh](rabbit.sh): Deploy RabbitMQ
- [maria.sh](maria.sh): Deploy MariaDB
- [keystone.sh](keystone.sh): Deploy Keystone
- [test_keystone.sh](test_keystone.sh): Test Keystone
- [nfs.sh](nfs.sh): Set up NFS server for Cinder/Glance to use (for now)
- [cinder.sh](cinder.sh): Deploy Cinder
- [test_cinder.sh](test_cinder.sh): Test Cinder
- [clean.sh](clean.sh): Remove keystone, maria, cinder, crc

## todo

- deploy glance
- deploy neutron and ovn