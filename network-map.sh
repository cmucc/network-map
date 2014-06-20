#!/bin/bash
cd "$(dirname "$0")"
if [[ ${BASH_VERSION%%[^0-9.]*} < 4 ]]; then
echo "This script requires bash version 4 or greater";
exit 1
fi
command -v /usr/sbin/arp >/dev/null 2>&1 || { echo >&2 "I require /usr/sbin/arp but it's not installed.  Aborting."; exit 1; }

# We should find a way to automatically update this
SWITCH_LIST="10.0.0.2 10.0.0.3"
GATEWAY="10.0.0.1"
PORTCHANNEL_PREFIX="Po"
OUTPUT=$1

source libsnmphelper.sh
source libarphelper.sh
source libjsonhelper.sh
source libmysqlhelper.sh

# create some Associative Arrays
declare -A switch_mapping_mac
declare -A switch_mapping_ip
declare -A switch_mapping_port
declare -A switch_internal_mac
declare -A switch_internal_ports

eval "$(arp_mac_to_ip)"
eval "$(arp_mac_to_dns)"
eval "$(arp_ip_to_mac)"

eval "$(mysql_get_xen)"

gateway_mac=${ip_to_mac[$GATEWAY]}
parent_switch=
echo "Will now query $SWITCH_LIST for connected macs, ports, and bridges information"
for switch in $SWITCH_LIST; do
	echo "Querying $switch"
	eval "$(snmp_switch_get_mac_to_bridge_port "$switch")"
	switch_mapping_ip[$switch]="root"
	for mac in "${!rtn[@]}"; do
		port=${rtn[$mac]}
		switch_mapping_mac[$switch,$mac]=$port
		switch_mapping_port[$switch,$port]+=" $mac"
		switch_internal_ports[$switch]+=" $port"
	done

	uplink=${switch_mapping_mac["$switch","$gateway_mac"]}
	#change this to work in all cases later
	if [ "$PORTCHANNEL_PREFIX" != "${uplink:0:2}" ]; then
		echo "I am connected to uplink at $uplink"
		parent_switch="$switch";
	fi
	unset uplink
	switch_mac_address=$(snmp_switch_mac_address $switch)
	switch_internal_mac[$switch,self]=$switch_mac_address
	switch_internal_ports[$switch]=$(for i in ${switch_internal_ports[$switch]}; do echo $i;done | sort -u)
	switch_internal_ports[$switch]=${switch_internal_ports[$switch]//$'\n'/ }
	switch_mac_address=$(snmp_switch_mac_address $switch)
	switch_internal_mac[$switch,self]=$switch_mac_address
	switch_internal_mac[$switch_mac_address,self]=$switch
	eval "$(snmp_switch_mac_port_mapping $switch)"
	for my_port_mac in "${!rtn[@]}"; do
		switch_internal_mac[$my_port_mac,self]=$switch
	done
done
for port in ${switch_internal_ports[$parent_switch]}; do
	#check every returned mac whether it belonged to a switch
	for mac_in_port in ${switch_mapping_port[$parent_switch,$port]}; do
		child_switch=${switch_internal_mac[$mac_in_port,self]};
		if [ -n "$child_switch" ]; then
			switch_mapping_ip[$child_switch]=$parent_switch
			switch_mapping_port[$parent_switch,$port,child]=$child_switch

			# find the port on the child that is connected to the parent
			for child_port in ${switch_internal_ports[$child_switch]}; do
				for child_mac_in_port in ${switch_mapping_port[$child_switch,$child_port]}; do
					if [ "X${switch_internal_mac[$child_mac_in_port,self]}" == "X$parent_switch" ]; then
						switch_mapping_port[$child_switch,$child_port,parent]=$parent_switch
					fi
				done;
			done
		fi
	done 
done

# Explicity setup some outputs for generate_connections_list
node_list=""
link_list=""
echo "Computing JSON output"
generate_connections_list $parent_switch


# Save stdout to file discriptor 3
exec 3>&1
if [ -n "$OUTPUT" ]; then
	#change stdout to be conntected to the input file
    exec 3>$OUTPUT
fi
exec 4>&1
exec 1>&3
echo '{"nodes":['
echo "${node_list%?}"
echo '],"links":['
echo "${link_list%?}"
echo "]}"

# Restore stdout and close temporary file description
exec 1>&4 4>&-
exec 3>&-
