#!/bin/bash

# Function: sync

sync () {

        output="" l_tsd="" l_sdtd="" chrony="" l_ntp=""
        dpkg-query -W chrony >/dev/null 2>&1 && l_chrony="y"
        dpkg-query -W ntp >/dev/null 2>&1 && l_ntp="y" || l_ntp=""
        systemctl list-units --all --type=service | grep -q 'systemd-
        timesyncd.service' && systemctl is-enabled systemd-timesyncd.service | grep -q 'enabled' && l_sdtd="y"
        # ! systemctl is-enabled systemd-timesyncd.service | grep -q 'enabled' &&
        l_nsdtd="y" || l_nsdtd=""
        if [[ "$l_chrony" = "y" && "$l_ntp" != "y" && "$l_sdtd" != "y" ]]; then
            l_tsd="chrony"
            output="$output\n- chrony is in use on the system"
        elif [[ "$l_chrony" != "y" && "$l_ntp" = "y" && "$l_sdtd" != "y" ]]; then
            l_tsd="ntp"
            output="$output\n- ntp is in use on the system"
        elif [[ "$l_chrony" != "y" && "$l_ntp" != "y" ]]; then
            if
                systemctl list-units --all --type=service | grep -q 'systemd-
                timesyncd.service' && systemctl is-enabled systemd-timesyncd.service | grep -Eq '(enabled|disabled|masked)'
            then
                l_tsd="sdtd"
                output="$output\n- systemd-timesyncd is in use on the system"
            fi
        else
            [[ "$l_chrony" = "y" && "$l_ntp" = "y" ]] && output="$output\n- both
    chrony and ntp are in use on the system"
            [[ "$l_chrony" = "y" && "$l_sdtd" = "y" ]] && output="$output\n- both
    chrony and systemd-timesyncd are in use on the system"
            [[ "$l_ntp" = "y" && "$l_sdtd" = "y" ]] && output="$output\n- both ntp
    and systemd-timesyncd are in use on the system"
        fi
        if [ -n "$l_tsd" ]; then
            echo -e "\n- Audit PASS:\n$output\n"
        else
            echo -e "\n- Audit FAIL:\n$output\n"
        fi

        if echo $output | grep -q "chrony" ; then
            output=$(grep -Pr --include=*.{sources,conf} '^\h*(server|pool)\h+\H+' /etc/chrony/)
            
            if echo "$output" | grep -q "pool\|server"; then
                echo -e "\nAudit passed: Chrony is configured with authorized timeserver\n"
            else
                echo -e "\nAudit failed: Chrony is not configured with authorized timeserver\n"
            fi

            output=$(ps -ef | awk '/[c]hronyd/ && $1!="_chrony" { print $1 }')

            if [ -z "$output" ]; then
                echo -e "\nAudit passed: Chrony is running as user_chrony\n"
            else
                echo -e "\nAudit failed: Chrony is not running as user_chrony\n"
            fi

            output=$(systemctl is-enabled chrony.service)

            output_2=$(systemctl is-active chrony.service)

            if echo "$output $output_2" | grep -q "enabled active"; then
                echo -e "\nAudit passed: Chrony is enabled and running\n"
            else
                echo -e "\nAudit failed: Chrony is not enabled and running\n"
            fi

        elif echo $output | grep -q "systemd-timesyncd" ; then
            output=$(find /etc/systemd -type f -name '*.conf' -exec grep -Ph '^\h*(NTP|FallbackNTP)=\H+' {} +)

            if echo "$output" | grep -q "NTP=\|FallbackNTP="; then
                echo -e "\nAudit passed: systemd-timesyncd configured with authorized timeserver\n"
            else
                echo -e "\nAudit failed: systemd-timesyncd is not configured with authorized timeserver\n"
            fi

            output=$(systemctl is-enabled systemd-timesyncd.service)
            echo "systemd-timesyncd.service: $output"

            output_2=$(systemctl is-active systemd-timesyncd.service)
            echo "systemd-timesyncd.service: $output_2"

            if echo "$output $output_2" | grep -q "enabled active"; then
                echo -e "\nAudit passed: systemd-timesyncd is enabled and running\n"
            else
                echo -e "\nAudit failed: systemd-timesyncd is not enabled and running\n"
            fi

        elif echo $output | grep -q "ntp" ; then
            output=$(grep -P -- '^\h*restrict\h+((-4\h+)?|-6\h+)default\h+(?:[^#\n\r]+\h+)*(?!(?:\2|\3|\4|\5))(\h*\bkod\b\h*|\h*\bnomodify\b\h*|\h*\bnotrap\b\h*|\h*\bnopeer\b\h*|\h*\bnoquery\b\h*)\h+(?:[^#\n\r]+\h+)*(?!(?:\1|\3|\4|\5))(\h*\bkod\b\h*|\h*\bnomodify\b\h*|\h*\bnotrap\b\h*|\h*\bnopeer\b\h*|\h*\bnoquery\b\h*)\h+(?:[^#\n\r]+\h+)*(?!(?:\1|\2|\4|\5))(\h*\bkod\b\h*|\h*\bnomodify\b\h*|\h*\bnotrap\b\h*|\h*\bnopeer\b\h*|\h*\bnoquery\b\h*)\h+(?:[^#\n\r]+\h+)*(?!(?:\1|\2|\3|\5))(\h*\bkod\b\h*|\h*\bnomodify\b\h*|\h*\bnotrap\b\h*|\h*\bnopeer\b\h*|\h*\bnoquery\b\h*)\h+(?:[^#\n\r]+\h+)*(?!(?:\1|\2|\3|\4))(\h*\bkod\b\h*|\h*\bnomodify\b\h*|\h*\bnotrap\b\h*|\h*\bnopeer\b\h*|\h*\bnoquery\b\h*)\h*(?:\h+\H+\h*)*(?:\h+#.*)?$' /etc/ntp.conf)

            if echo "$output" | grep -q "default\|kod\|nomodify\|notrap\|nopeer\|noquery"; then
                echo -e "\nAudit passed: NTP access control is configured\n"
            else
                echo -e "\nAudit failed: NTP access control is not configured\n"
            fi

            output=$(grep -P -- '^\h*(server|pool)\h+\H+' /etc/ntp.conf)

            if echo "$output" | grep -q "pool\|server"; then
                echo -e "\nAudit passed: ntp is configured with authorized timeserver\n"
            else
                echo -e "\nAudit failed: ntp is not configured with authorized timeserver\n"
            fi

            output_1=$(ps -ef | awk '/[n]tpd/ && $1!="ntp" { print $1 }')

            output_2=$(grep -P -- '^\h*RUNASUSER=' /etc/init.d/ntp)

            if [ -z "$output_1" ] && echo "$output_2" | grep -q "ntp"; then
                echo -e "\nAudit passed: ntp is running as user ntp\n"
            else
                echo -e "\nAudit failed: ntp is not running as user ntp\n"
            fi

            output=$(systemctl is-enabled ntp.service)
            echo "ntp: $output"

            output_2=$(systemctl is-active ntp.service)
            echo "ntp: $output_2"

            if echo "$output $output_2" | grep -q "enabled active"; then
                echo -e "\nAudit passed: NTP is enabled and running\n"
            else
                echo -e "\nAudit failed: NTP is not enabled and running\n"
            fi

        else
            echo "No time synchronization method is used on the system"

        fi

}

# Function: telnet_client

telnet_client () {

   telnet_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep telnet )   # Checks if telnet client is not installed 

    if  [[ -z $telnet_output ]] ; then
        echo -e "Audit passed : telnet client is not installed\n"

    else
        echo -e "Audit failed : telnet client is installed\n"

    fi

}

# Function: FTP_server

FTP_server () {

    FTP_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep ftp)   # checks if FTP server is not installed

    if [[ -z $FTP_output ]]; then
        echo -e "\nAudit passed : FTP server is not installed\n"

    else
        echo -e "\nAudit failed : FTP server is installed\n"

    fi

}

# Function: DNS_server

DNS_server () {

    DNS_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep bind9)   # checks if DNS server is not installed

    if [[ -z $DNS_output ]]; then
        echo -e "\nAudit passed : DNS server is not installed\n"

    else
        echo -e "\nAudit failed : DNS server is installed\n"

    fi

}

# Function: mail_transfer_agent

mail_transfer () {

    mail_transfer_output=$(ss -lntu | grep -E ':25\s' | grep -E -v '\s(127.0.0.1|::1):25\s')   # Checks if mail transfer agent is configured for local-only mode 

    if [ -z $mail_transfer_output ] ; then
        echo -e "\nAudit passed : Mail transfer agent is configured for local-only mode\n"

    else
        echo -e "\nAudit failed : Mail transfer agent is not configured for local-only mode\n"

    fi


}

# Function: avahi_server

avahi_server () {
    
    avahi_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep avahi-daemon)   # checks if avahi server is not installed

    if [[ -z $avahi_output ]];  then
        echo -e "\nAudit passed : Avahi server is not installed\n"

    else
        echo -e "\nAudit failed : Avahi server is installed\n"

    fi

}

# Function: SNMP

SNMP () {

    SNMP_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep snmp)   # checks if SNMP server is not installed

    if [[ -z $SNMP_output ]]; then
        echo -e "\nAudit passed : SNMP server is not installed\n"

    else
        echo -e "\nAudit failed : SNMP server is installed\n"

    fi

}

# Function: HTTP_proxy_server

HTTP_proxy_server () {

    HTTP_proxy_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep -E 'squid|proxy')   # checks if HTTP proxy server is not installed

    
    if [[ -z $HTTP_proxy_output ]]; then
        echo -e "\nAudit passed : HTTP Proxy server is not installed\n"

    else
        echo -e "\nAudit failed : HTTP Proxy server is installed\n"

    fi

}

# Function: HTTP_server

HTTP_server () {

    HTTP_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep httpd)   # checks if HTTP server is not installed

    if [[ -z $HTTP_output ]]; then
        echo -e "\nAudit passed : HTTP server is not installed\n"

    else
        echo -e "\nAudit failed : HTTP server is installed\n"

    fi

}

# Function: resync_service

rsync_service_installed () {

    rsync_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep rsync)   # Verifies if rsync is installed

    if [[ -z $rsync_output ]]; then
        echo -e "\nAudit passed : rsync service is not installed\n"

    else
        echo -e "\nAudit failed : rsync is installed\n"

    fi

}

rsync_service_inactive () {   # Verifies if rsync is inactive

    rsync_inactive_output=$(systemctl is-active rsync)
    echo "rsync_service : $rsync_inactive_output"
}

rsync_service_masked () {   # Verifies if rsync is masked

    rsync_masked_output=$(systemctl is-enabled rsync)
    echo "rsync_service_masked : $rsync_masked_output"

    if echo "$rsync_inactive_output" | grep -q "inactive" && echo "$rsync_masked_output" | grep -q "masked" ; then
        echo -e "\nAudit passed : rsync is inactive and masked\n"

    else
        echo -e "\nAudit failed : rsync is not inactive or not masked\n"

    fi

}

# Function: NFS

NFS () {
     
     NFS_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep nfs-kernel-server)   # ensures if NFS is not installed

     if [[ -z $NFS_output ]]; then
        echo -e "\nAudit passed : NFS is not installed\n"

    else
        echo -e "\nAudit failed : NFS is installed\n"

    fi

}

# Function: nonessential_services

nonessential_services () {

    lsof -i -P -n | grep -v "(ESTABLISHED)"   # Checks if nonessential services are removed or masked

}

# Function: NIS

NIS () {

    NIS_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep nis)   # checks if NIS server is not installed

    if [[ -z $NIS_output ]]; then
        echo -e "\nAudit passed : NIS server is not installed\n"

    else
        echo -e "\nAudit failed : NIS server is installed\n"

    fi

}

# Function: NIS_client

NIS_client () {

    NIS_client_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep nis)   # Checks if NIS Client is not installed 

    if [[ -z $NIS_client_output ]]; then
        echo -e "\nAudit passed : NIS client is not installed\n"

    else
        echo -e "\nAudit failed : NIS client is installed\n"

    fi

}

# Function: dhcp_server

dhcp_server () {
    
    dhcp_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep isc-dhcp-server)   # checks if DHCP server is not installed

    if [[ -z $dhcp_output ]]; then
        echo -e "\nAudit passed : DHCP server is not installed\n"

    else
        echo -e "\nAudit failed : DHCP server is installed\n"

    fi

}

# Function: LDAP_server

LDAP_server () {
    
    LDAP_server_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep slapd)   # checks if LDAP server is not installed

    if [[ -z $LDAP_server_output ]]; then
        echo -e "\nAudit passed : LDAP server is not installed\n"

    else
        echo -e "\nAudit failed : LDAP server is installed\n"

    fi

}

# Function: IMAP_and_POP3_server

IMAP_and_POP3 () {

    IMAP_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep dovecot-imapd dovecot-pop3d courier-imap cyrus-imap 2>/dev/null)   # Checks if IMAP and POP3 servers are not installed

    if [[ -z $IMAP_output ]]; then
        echo -e "\nAudit passed : IMAP and POP3 server is not installed\n"

    else
        echo -e "\nAudit failed : IMAP and POP3 server is installed\n"

    fi
}

# Function: samba

samba () {

    samba_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep samba)   # checks if samba is not installed

    if [[ -z $samba_output ]]; then
        echo -e "\nAudit passed : Samba is not installed\n"

    else
        echo -e "\nAudit failed : Samba is installed\n"

    fi

}

# Function: RPC

RPC () {

    RPC_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep rpcbind)   # Checks if RPC is not installed 

    if [[ -z $RPC_output ]]; then
        echo -e "\nAudit passed : RPC is not installed\n"

    else
        echo -e "\nAudit failed : RPC is installed\n"

    fi

}

# Function: rsh_client

rsh_client () {

    rsh_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep rsh-client)   # Checks if rsh client is not installed

    if [[ -z $rsh_output ]]; then
        echo -e "\nAudit passed : rsh client is not installed\n"

    else
        echo -e "\nAudit failed : rsh client is installed\n"

    fi

}

# Function: LDAP_client

LDAP_client () {

    LDAP_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep ldap-utils)   # Checks if LDAP client is not installed 

    if [[ -z $LDAP_output ]]; then
        echo -e "\nAudit passed : LDAP client is not installed\n"

    else
        echo -e "\nAudit failed : LDAP client is installed\n"

    fi

}

# Function: cups

cups () {
    
    cups_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep cups)   # checks if cups is not installed

    if [[ -z $cups_output ]]; then
        echo -e "\nAudit passed : CUPS is not installed\n"

    else
        echo -e "\nAudit failed : CUPS is installed\n"

    fi

}

# Function: talk_client

talk_client () {

    talk_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' | grep talk)   # Checks if talk client is not installed

     if [[ -z $talk_output ]]; then
        echo -e "\nAudit passed : talk client is not installed\n"

    else
        echo -e "\nAudit failed : talk client is installed\n"

    fi


}

# Function: x_window_system

x_window_system () {
    
    window_output=$(dpkg-query -W -f='${binary:Package}\t${Status}\t${db:Status-Status}\n' xserver-xorg* | grep -Pi '\h+installed\b')   # checks if X window system is installed

    if [[ -z $windows_output ]] ; then
        echo -e "\nAudit passed : X Window System is not installed\n"
    else
        echo -e "\nAudit failed : X Window System is installed\n"
    fi

}


