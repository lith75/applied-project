#!/bin/bash

source services_audit.sh
# source services_configuration.sh

#audit functions
sync
telnet_client
FTP_server
DNS_server
mail_transfer
avahi_server
SNMP
HTTP_proxy_server
HTTP_server
rsync_service_installed
rsync_service_inactive
resync_service_masked
NFS
nonessential_services
NIS
NIS_client
dhcp_server
LDAP_server
IMAP_and_POP3
samba
RPC
rsh_client
LDAP_client
cups
talk_client
x_window_system


#configuration functions
