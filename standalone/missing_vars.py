#!/usr/bin/python3

import yaml
import sys
import socket

if len(sys.argv) != 1:
    my_ip = sys.argv[1]
else:
    my_ip = "192.168.24.100"

with open('99-standalone-vars', 'r') as standalone_vars_file:
    inv = yaml.safe_load(standalone_vars_file)
    vars = inv['Compute']['vars']


controller_hostname = "standalone.localdomain"
controller_ip = "192.168.24.2"
vnc_url = vars['tripleo_nova_compute_vnc_novncproxy_base_url'] + '/vnc_auto.html'

vars['tripleo_ovn_encap_ip'] = my_ip
vars['tenant_ip'] = my_ip
vars['tripleo_nova_compute_DEFAULT_my_ip'] = my_ip
vars['tripleo_nova_compute_vncserver_proxyclient_address'] = controller_ip
vars['tripleo_nova_compute_vnc_server_listen'] = controller_ip
vars['tripleo_nova_compute_vnc_server_proxyclient_address'] = controller_ip
vars['tripleo_nova_compute_libvirt_live_migration_inbound_addr'] = controller_hostname
vars['tripleo_nova_compute_vncproxy_host'] = vnc_url
vars['tripleo_nova_compute_DEFAULT_reserved_host_memory_mb'] = '1024'
vars['tripleo_nova_compute_reserved_host_memory'] = '1024'
vars['tripleo_nova_libvirt_need_libvirt_secret'] = False

# Configure hostname
vars['tripleo_nova_compute_DEFAULT_host'] = socket.gethostname()

# add missing var to service_user
vars['tripleo_nova_compute_config_overrides']['service_user']['username'] = 'nova'

# Add randomize allocation vm
vars['tripleo_nova_compute_config_overrides']['placement']['randomize_allocation_candidates'] = 'True'
vars['tripleo_nova_compute_config_overrides']['filter_scheduler'] = {}
vars['tripleo_nova_compute_config_overrides']['filter_scheduler']['host_subset_size'] = '2'
vars['tripleo_nova_compute_config_overrides']['filter_scheduler']['shuffle_best_same_weighed_hosts'] = 'True'

# add missing vars to neutron
missing_vars = {
    'auth_type': 'v3password',
    'project_name': 'service',
    'user_domain_name': 'Default',
    'project_domain_name': 'Default',
    'region_name': 'regionOne',
    'username': 'neutron',
}
for k,v in missing_vars.items():
    vars['tripleo_nova_compute_config_overrides']['neutron'][k] = v

config_dict = {
    'Compute': {
        'vars': vars
    }
}

with open('99-standalone-vars-new', 'w') as f:
    f.write(yaml.safe_dump(config_dict, default_flow_style=False, width=10000))
