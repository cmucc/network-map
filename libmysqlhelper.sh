#!/bin/bash
function mysql_get_xen() {
        declare -A dom0_to_domU;
        declare -A domU_to_dom0;
        OLDIFS=$IFS
        IFS=$'\t'
        while read line; do 
        	if [[ $line =~ dom0 ]]; then continue; fi
        	read -r dom0 domU <<< "$line"
        	dom0_to_domU["$dom0"]+="$domU "
        	domU_to_dom0["$domU"]="$dom0"
    	done < <(mysql -u "#" --host club-db what_xen -e "SELECT h.dom0, i.domU \
    		FROM hardware AS h \
    		LEFT OUTER JOIN (machines AS m JOIN information AS i) \
    		ON h.dom0 = m.dom0 AND m.domU = i.domU")
        IFS=OLDIFS
        declare -p dom0_to_domU
        declare -p domU_to_dom0
}
