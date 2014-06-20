network-map
===========

The network map makes a map of the room. It queries data from the switches using snmp and builds a JSON output to be read by d3js force layout.

The script can be placed in the monitor host and requires:

* bash 4
* snmpwalk and snmpget
* /usr/sbin/arp
* Bonus: The server knowing the hostname of all the relevant machines (This is true on club monitor due to an existing scrpt)


The script also uses 4 helper libraries that I wrote called libarphelper.sh, libsnmphelper.sh, libjsonhelper.sh, libmysqlhelper.sh. These scripts should be located in the same directory as network-mapper.sh

The script main file is network-mapper.sh and running it with no-args will query all the switches and output to stdout.

Once the JSON has been generated it will echo it out to either stdout or the file passed as the first args. 

I have an older version hosted here http://www.club.cc.cmu.edu/~ssosothi/network.html


Project Page (Club members only for now) https://wiki.club.cc.cmu.edu/org-auth/ccwiki/Network%20Map
