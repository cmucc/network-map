#!/bin/bash
command -v snmpwalk >/dev/null 2>&1 || { echo >&2 "I require snmpwalk but it's not installed.  Aborting."; exit 1; }
command -v snmpget >/dev/null 2>&1 || { echo >&2 "I require snmpget but it's not installed.  Aborting."; exit 1; }

COMMUNITY_STRING='a private string'

snmp_switch_oid_mapper() {
    ip=$1;
    from_oid=$2;
    to_oid=$3
    declare -A tmp_to_mapping
    declare -A rtn
        tmp_snmp_readout=$(snmpwalk -v2c -c $COMMUNITY_STRING -ObentUq $ip $to_oid)
        #tmp_snmp_readout=${tmp_snmp_readout//.$to_oid./}
        OLDIFS=$IFS
        IFS=$'\n'
        for item in $tmp_snmp_readout; do
                IFS=' '
        read -r id string <<< "$item"
                tmp_to_mapping["${id##${id%.*.*}.}"]="$(${5:-echo} $string)"
                #tmp_to_mapping["${id##*.}"]="$(${5:-echo} $string)"
        done
    IFS=OLDIFS
    tmp_snmp_readout=$(snmpwalk -v2c -c $COMMUNITY_STRING -ObentUq $ip $from_oid)
        tmp_snmp_readout=${tmp_snmp_readout//.$from_oid./}
    OLDIFS=$IFS
    IFS=$'\n'
        for item in $tmp_snmp_readout; do
                IFS=' '
        read -r id string <<< "$item"
        if [ "${string}" ]; then
            rtn[$(${4:-echo} "$string")]="${tmp_to_mapping["${id##${id%.*.*}.}"]}"
        fi
        done
    declare -p rtn
}

snmp_switch_oid_mapper_key_to_value() {
        ip=$1;
        from_oid=$2;
        to_oid=$3
        declare -A tmp_to_mapping
        declare -A rtn
        tmp_snmp_readout=$(snmpwalk -v2c -c $COMMUNITY_STRING -ObentUq $ip $to_oid)
        #tmp_snmp_readout=${tmp_snmp_readout//.$to_oid./}
        OLDIFS=$IFS
        IFS=$'\n'
        for item in $tmp_snmp_readout; do
                IFS=' '
                read -r id string <<< "$item"
                tmp_to_mapping["${id##*.}"]="$(${5:-echo} $string)"
        done
        IFS=OLDIFS
        tmp_snmp_readout=$(snmpwalk -v2c -c $COMMUNITY_STRING -ObentUq $ip $from_oid)
        tmp_snmp_readout=${tmp_snmp_readout//.$from_oid./}
        OLDIFS=$IFS
        IFS=$'\n'
        for item in $tmp_snmp_readout; do
                IFS=' '
                read -r id string <<< "$item"
                if [ "${string}" ]; then
                        rtn["${id##*.}"]="${tmp_to_mapping[$(${4:-echo} "$string")]}"
                fi
        done
        declare -p rtn
}


snmp_switch_mac_address() {
        ip=$1;
    tmp_OID=".1.3.6.1.2.1.4.20.1.2.$ip "
    switch_iface_id=$(snmpget -v2c -c $COMMUNITY_STRING -ObentUq $ip $tmp_OID)
        switch_iface_id=${switch_iface_id:${#tmp_OID}}
    tmp_OID=".1.3.6.1.2.1.2.2.1.6.$switch_iface_id "
    switch_mac_address=$(snmpget -v2c -c $COMMUNITY_STRING -ObentUq $ip $tmp_OID)
    switch_mac_address=${switch_mac_address:${#tmp_OID}}
    printf "%02x:%02x:%02x:%02x:%02x:%02x" 0x${switch_mac_address//:/ 0x}
}
snmp_switch_mac_port_mapping_format_mac(){
    printf "%02x:%02x:%02x:%02x:%02x:%02x" 0x${1//:/ 0x}
}
snmp_switch_mac_port_mapping() {
    snmp_switch_oid_mapper $1 1.3.6.1.2.1.2.2.1.6 1.3.6.1.2.1.31.1.1.1.1 snmp_switch_mac_port_mapping_format_mac
}
__internal_format_mac() {
    local t=${1//\"/}
    t=${t%?}
    printf "%02x:%02x:%02x:%02x:%02x:%02x"  0x${t// / 0x}
}

snmp_strip_results () {
    ip=$1;
    oid=$2;

    tmp_snmp_readout=$(snmpwalk -v2c -c $COMMUNITY_STRING -ObentUq $ip $oid);
    OLDIFS=$IFS;
    IFS=$'\n';
        for item in $tmp_snmp_readout; do
                IFS=' '
                read -r id string <<< "$item"
                echo "${id##*.} $string"
        done
        IFS=OLDIFS

}
snmp_switch_get_mac_to_bridge_port() {
    mac_to_bridge=$(snmp_switch_oid_mapper $1 1.3.6.1.2.1.17.4.3.1.1 1.3.6.1.2.1.17.4.3.1.2 __internal_format_mac)
    eval "$mac_to_bridge"
    bridge_to_port=$(snmp_switch_oid_mapper_key_to_value $1 1.3.6.1.2.1.17.1.4.1.2 1.3.6.1.2.1.31.1.1.1.1)
    bridge_to_port="declare -A bridge_to_port_mapping=${bridge_to_port#*=}"; eval "$bridge_to_port"

    for i in "${!rtn[@]}"
    do
      rtn[$i]=${bridge_to_port_mapping[${rtn[$i]}]}
    done
    declare -p rtn

}
