#!/bin/bash

source services_audit.sh

sync_config () {

    if echo $output | grep -q "chrony" ; then

        sudo apt install chrony

        sudo systemctl stop systemd-timesyncd.service
        sudo systemctl --now mask systemd-timesyncd.service

        sudo apt purge ntp

        edit_chrony_config() {
            local config_file="/etc/chrony/chrony.conf"
            local sources_file="/etc/chrony/sources.d/"
            local server_or_pool="$1"
            local remote="$2"

            if [[ "$config_file" == *.sources ]]; then
                config_file="$sources_file$config_file"
            fi

            echo "$server_or_pool $remote" >> "$config_file"
        }

        reload_chrony_config() {
            if systemctl is-active --quiet chronyd; then
                systemctl restart chronyd
            else
                chronyc reload sources
            fi
        }

        add_sourcedir_directive() {
            local config_file="/etc/chrony/chrony.conf"
            local sources_file="/etc/chrony/sources.d/"

            if ! grep -q "sourcedir $sources_file" "$config_file"; then
                echo "sourcedir $sources_file" >> "$config_file"
            fi
        }

        edit_chrony_config "pool" "time.nist.gov iburst maxsources 4"
        edit_chrony_config "server" "time-a-g.nist.gov iburst"
        edit_chrony_config "server" "132.163.97.3 iburst"
        edit_chrony_config "server" "time-d-b.nist.gov iburst"

        add_sourcedir_directive

        reload_chrony_config

        echo "\nChrony configuration completed.\n"

        chrony_conf="/etc/chrony/chrony.conf"
    
        conf_d="/etc/chrony/conf.d/"
        
        user="user_chrony"
        
        if [ -f "$chrony_conf" ]; then
            
            if grep -q "^user" "$chrony_conf"; then
                
                sed -i "s/^user.*/$user/" "$chrony_conf"
            else
                
                echo "$user" >> "$chrony_conf"
            fi
        
        else

            conf_files=$(find "$conf_d" -type f -name "*.conf")
        
            for conf_file in $conf_files; do
                
                if grep -q "^user" "$conf_file"; then
                    
                    sed -i "s/^user.*/$user/" "$conf_file"
                else
                    
                    echo "$user" >> "$conf_file"
                fi
            
            done

        echo "\nChrony user has been configured.\n"

        sudo systemctl unmask chrony.service

        sudo systemctl --now enable chrony.service

        echo "\nChrony has been unmasked and started.\n"

    elif echo $output | grep -q "systemd-timesyncd" ; then

        NTP="time.nist.gov"
        Fallback_NTP="time-a-g.nist.gov time-b-g.nist.gov time-c-g.nist.gov"

        config_file_1="/etc/systemd/timesyncd.conf.d"
        config_file_2="/etc/systemd/timesyncd.conf.d/ntp.conf"

        if [ ! -f "$config_file_1" ]; then
            
            sudo touch "$config_file_2"

            echo "[Time]" | sudo tee "$config_file_2" > /dev/null
            echo "NTP=$NTP_SERVER" | sudo tee -a "$config_file_2" > /dev/null
            echo "FallbackNTP=$FALLBACK_NTP_SERVERS" | sudo tee -a "$config_file_2" > /dev/null
        
        else

            echo "[Time]" | sudo tee "$config_file_1" > /dev/null
            echo "NTP=$NTP_SERVER" | sudo tee -a "$config_file_1" > /dev/null
            echo "FallbackNTP=$FALLBACK_NTP_SERVERS" | sudo tee -a "$config_file_1" > /dev/null

        fi

        sudo systemctl try-reload-or-restart systemd-timesyncd

        echo "\nLines "$NTP" and "$FALLBACK_NTP" added to the systemd-timesyncd configuration file.\n"

        sudo systemctl unmask systemd-timesyncd.service
        sudo systemctl --now enable systemd-timesyncd.service

        echo "\nsystemctl is unmasked and enabled\n"

    elif echo $output | grep -q "ntp" ; then

        sudo apt install ntp

        sudo systemctl stop systemd-timesyncd.service
        sudo systemctl --now mask systemd-timesyncd.service

        sudo apt purge chrony

        ntp_conf="/etc/ntp.conf"

        if grep -q "^restrict -4" "$ntp_conf"; then
            sed -i '/^restrict -4/c\restrict -4 default kod nomodify notrap nopeer noquery' "$ntp_conf"
        
        else
            echo "restrict -4 default kod nomodify notrap nopeer noquery" >> "$ntp_conf"

        fi

        if grep -q "^restrict -6" "$ntp_conf"; then
            sed -i '/^restrict -6/c\restrict -6 default kod nomodify notrap nopeer noquery' "$ntp_conf"
        
        else
            echo "restrict -6 default kod nomodify notrap nopeer noquery" >> "$ntp_conf"
        
        fi

        echo "\nntp configuration file was updated with the restrict lines\n"

        edit_ntp_config() {
            local config_file="/etc/ntp.conf"
            local server_or_pool="$1"
            local remote="$2"

            echo "$server_or_pool $remote" >> "$config_file"
        }

        edit_ntp_config pool time.nist.gov iburst
        edit_ntp_config server time-a-g.nist.gov iburst
        edit_ntp_config server 132.163.97.3 iburst
        edit_ntp_config server time-d-b.nist.gov iburst

        sudo systemctl restart ntp

        echo "\nntp configuration file updated with server and pool lines\n"

        ntp_conf_file="/etc/init.d/ntp"
        ntp_user="RUNASUSER=ntp"
        
        if grep -q "^user" "$ntp_conf_file"; then
                
            sed -i "s/^user.*/$ntp_user/" "$ntp_conf_file"

        else    
            echo "$ntp_user" >> "$ntp_conf_file"
        
        fi

        sudo systemctl restart ntp.service

        echo "\nntp user was updated in the ntp configuration file\n"

        sudo systemctl unmask ntp.service

        sudo systemctl --now enable ntp.service

        echo "\nntp services was unmasked and enabled\n"

    else
        
        echo "\nNo time synchronization service was found on the system\n"
        
}


X_windows_system_config () {

    if [[ -z $windows_output ]] ; then
        echo -e "\nNo X Window System packages to remove as it is not installed\n"
    
    else
        apt purge xserver-xorg*

        echo "X Windows System packages were successfully removed"
    fi

}

avahi_server_config () {

    if echo $avahi_output | grep -q "not"; then
        echo -e "\nNothing was removed, avahi-daemon not installed\n"

    else
        sudo systemctl stop avahi-daaemon.service
        sudo systemctl stop avahi-daemon.socket
        sudo apt purge avahi-daemon

        echo "\navahi-daemon was successfully removed\n"

    fi

}

cups_config () {

    if echo $cups_output | grep -q "not"; then
        echo "\nNothing was removed, cups not installed\n"

    else
        apt purge cups

        echo -e "\ncups was successfully removed\n"

    fi
}

DHCP_config () {

     if echo $dhcp_output | grep -q "not"; then
        echo "\nNothing was removed, DHCP server not installed\n"

    else
        apt purge isc-dhcp-server

        echo -e "\nDHCP server was successfully removed\n"

    fi
}

LDAP_config () {

    if echo $LDAP_server_output | grep -q "not"; then
        echo -e "\nNothing was removed, LDAP server not installed\n"

    else
        apt purge slapd

        echo -e "\nLDAP server was successfully removed\n"

    fi
}

NFS_config () {

    if echo $NFS_output | grep -q "not"; then
        echo -e "\nNothing was removed, NFS is not installed\n"

    else
        apt purge nfs-kernel-server

        echo -e "\nNFS was successfully removed\n"

    fi
}

DNS_config () {

    if echo $DNS_output | grep -q "not"; then
        echo -e "\nNothing was removed, DNS server is not installed\n"

    else
        apt purge bind9

        echo -e "\nDNS server was successfully removed\n"

    fi
}

FTP_config () {

    if echo $FTP_output | grep -q "not"; then
        echo -e "\nNothing was removed, FTP server is not installed\n"

    else
        apt purge vsftpd

        echo -e "\nFTP server was successfully removed\n"

    fi

}

HTTP_config () {

    if echo $HTTP_server | grep -q "not"; then
        echo -e "\nNothing was removed, HTTP server is not installed\n"

    else
        apt purge apache2

        echo -e "\nHTTP server was successfully removed\n"

    fi
}

IMAP_and_POP3_config () {

    if echo $IMAP_output | grep -q "not"; then
        echo -e "\nNothing was removed, IMAP and POP3 server are not installed\n"

    else
        apt purge dovecot-imapd dovecot-pop3d

        echo -e "\nIMAP and POP3 server was successfully removed\n"

    fi

}

SAMBA_config () {

    if echo $samba_output | grep -q "not"; then
        echo -e "\nNothing was removed, Samba is not installed\n"

    else
        apt purge samba

        echo -e "\nSamba was successfully removed\n"

    fi
}

HTTP_proxy_server_config () {

    if echo $HTTP_proxy_output | grep -q "not"; then
        echo -e "\nNothing was removed, HTTP Proxy Server is not installed\n"

    else
        apt purge squid

        echo -e "\nHTTP Proxy Server was successfully removed\n"

    fi    
}

SNMP_config () {

    if echo $SNMP_output | grep -q "not"; then
        echo -e "\nNothing was removed, SNMP Server is not installed\n"

    else
        apt purge snmp

        echo -e "\nSNMP Server was successfully removed\n"

    fi 
}

NIS_server_config () {

    if echo $NIS_output | grep -q "not"; then
        echo -e "\nNothing was removed, NIS Server is not installed\n"

    else
        apt purge nis

        echo -e "\nNIS Server was successfully removed\n"

    fi 
}

mail_trasfer_agent_config () {

    local file="/etc/postfix/main.cf"
    local line="inet_interfaces = loopback-only"
    
    if grep -q "^inet_interfaces" "$file"; then
        
        sudo sed -i "s/^inet_interfaces.*/$line/" "$file"
    else
        
        echo $line >> $file
    fi

    systemctl restart postfix

    echo -e "\nLine added to the receiving mail section in $file\n"

}

rsync_service_config () {

    if echo $rsync_output | grep -q "not"; then
        echo -e "\nNothing was removed, rsync service is either not installed or masked\n"

    else

        apt purge rsync
        
        systemctl stop rsync

        systemctl mask rsync

        echo -e "\nrsync service removed\n"

    fi 
}

NIS_client_config () {

    if echo $NIS_client_output | grep -q "not"; then
        echo -e "\nNothing was removed, NIS Client is not installed\n"

    else
        apt purge nis

        echo -e "\nNIS Client was successfully removed\n"

    fi 
}

rsh_client_config () {

    if echo $rsh_client_config | grep -q "not"; then
        echo -e "\nNothing was removed, rsh client is not installed\n"

    else
        apt purge rsh-client

        echo -e "\nrsh client was successfully removed\n"

    fi
}

talk_client_config () {

    if echo $talk_output | grep -q "not"; then
        echo -e "\nNothing was removed, talk client is not installed\n"

    else
        apt purge talk

        echo -e "\ntalk client was successfully removed\n"

    fi
}

telnet_client_config () {

    if echo $telnet_output | grep -q "not"; then
        echo -e "\nNothing was removed, telnet client is not installed\n"

    else
        apt purge telnet

        echo -e "\ntelnet client was successfully removed\n"

    fi
}

LDAP_client_config () {

    if echo $LDAP_output | grep -q "not"; then
        echo -e "\nNothing was removed, LDAP client is not installed\n"

    else
        apt purge ldap-utils

        echo -e "\nLDAP client was successfully removed\n"

    fi
}

RPC () {

    if echo $RPC_output | grep -q "not"; then
        echo -e "\nNothing was removed, RPC is not installed\n"

    else
        apt purge ldap-utils

        echo -e "\nRPC was successfully removed\n"

    fi
}

nonessential_services_config () {

    read -p "\nEnter the name of the package that needs to be removed (if not packages need to be removed, type 'none'):\n " package

    if [ "$package" != "none" ]; then
        apt purge $package
    else
        read -p "Enter service name to stop and mask: " service
        systemctl --now mask $service

        if [[ -z $service ]]; then
            echo "\nNo service name was given\n"
            exit 1

        fi
    fi
}






