#!/bin/bash

function arp_mac_to_dns() {
	all_results=$(/usr/sbin/arp -a)
	declare -A mac_to_dns;
	OLDIFS=$IFS
        IFS=$'\n'
        for item in $all_results; do
                IFS=' '
		read -r dns ip at mac eth on port <<< "$item"
		if [[ "$dns" == "?" || $mac == "<incomplete>" ]]; then
		continue;
		fi
		mac_to_dns["$mac"]="$dns"
        done
        IFS=OLDIFS
	declare -p mac_to_dns
}

function arp_mac_to_ip() {
	all_results=$(/usr/sbin/arp -a)
	declare -A mac_to_ip;
	OLDIFS=$IFS
        IFS=$'\n'
        for item in $all_results; do
                IFS=' '
		read -r dns ip at mac eth on port <<< "$item"
		if [[ $mac == "<incomplete>" ]]; then
		continue;
		fi
		ip=${ip#*(}
		ip=${ip%)*}
		mac_to_ip["$mac"]="$ip"
        done
        IFS=OLDIFS
	declare -p mac_to_ip
}