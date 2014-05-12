#!/bin/bash
node_count=-1
group=0

generate_connections_list(){
    local self_ip=$1
    local self_mac=${switch_internal_mac[$self_ip,self]}
    ((group++))
    local switch_group=$group
    if [ ! $3 ]; then
        __output_node "$switch_group" "$2" "$self_mac" "Switch"
    else
        __output_node "$switch_group" "$2" "$self_mac" "$3:Switch:${switch_mapping_mac[$4,$self_mac]:-?}"
    fi
    local switch_node_id=$node_count
    for port in ${switch_internal_ports[$self_ip]}; do
        child_switch_ip=${switch_mapping_port[$self_ip,$port,child]}
        parent_switch_ip=${switch_mapping_port[$self_ip,$port,parent]}
        if [ $child_switch_ip ]; then
            generate_connections_list $child_switch_ip $switch_node_id "$port" $self_ip
        elif [ $parent_switch_ip ]; then
            :
        else
            local nodes=${switch_mapping_port[$self_ip,$port]}
            nodes=( $nodes )
            #find a way not to convert to array?
            #if [ ${#nodes[@]} == 1 ]; then
            #    __output_node "$switch_group" "$switch_node_id" "$nodes" "$port:"
            #else
                ((group++))
                __output_node "$group" "$switch_node_id" "" "$port"
                # ((group++))
                # __output_node "$switch_group" "$switch_node_id" "" "$port"
                portid=$node_count

                declare -A dom0_info;
                for leaf in "${nodes[@]}"; do
                    dns_name="${mac_to_dns["$leaf"],,}"
                    if [ -n "$dns_name" ]; then
                        dns_name="${dns_name%%.*}"
                        if [ -n "${dom0_to_domU[$dns_name]}" ]; then
                            if [ "${#dom0_info[@]}" -eq 0 ]; then
                                saved_group=$group;
                            fi
                            ((group++))
                            __output_node "$group" "$portid" "$leaf" ""
                            dom0_info["$dns_name"]="$group $node_count"
                        fi
                    fi
                done
                for leaf in "${nodes[@]}"; do
                    long_dns_name="${mac_to_dns["$leaf"],,}"
                    if [ "${#dom0_info[@]}" -gt 0 -a -n "$long_dns_name" ]; then
                        dns_name="${long_dns_name%%.*}"
                        if [ "${dom0_info[$dns_name]}" ]; then continue; fi
                        dom0=( ${dom0_info[${domU_to_dom0[$dns_name]}]} );
                        if [ "$dom0"  ]; then
                            __output_node "${dom0[0]}" "${dom0[1]}" "$leaf" ""
                            continue;
                        fi
                        dom0=( ${dom0_info[${domU_to_dom0[$long_dns_name]}]} );
                        if [ "$dom0"  ]; then
                            __output_node "${dom0[0]}" "${dom0[1]}" "$leaf" ""
                            continue;
                        fi
                    fi
                    __output_node "${saved_group:-$group}" "$portid" "$leaf" ""
                done
                saved_group=""
                unset dom0_info
            #fi
        fi
    done
}
__output_node() {
    ((node_count++))
    node_list+="{\"name\":\"${4:+$4 }${3:+${mac_to_dns["$3"]:-${mac_to_ip[$3]:-$3}}}\",\"group\":$1},"
    if [ $2 ]; then
    __output_links "$2" "$node_count" ;
    fi
}
__output_links() {
    link_list+="{\"source\":$1,\"target\":$2,\"value\":1},"
}
