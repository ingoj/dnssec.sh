# dnssec.sh
Small Shell Script to handle DNSSEC and other useful things with bind9 nameserver on Debian Linux. 

It assumes zone files to be in `/etc/bind/$TLD/$zone` directory structure and needs some DNSSEC specific configuration to bind9 config files to enable DNSSEC. 

# Command Line Options:
```
vserv:~# dnssec.sh
m: , d: , t:
No parameter given.
Usage: dnsec.sh MODE DOMAIN

MODE can be one of the following:
enable-dnssec : perform all steps to enable DNSSEC for your domain
edit-zone     : safely edit your zone after enabling DNSSEC
create-dnskey : create new dnskey only
load-dnskey   : loads new dnskeys and signs the zone with them
show-ds       : shows DS records of zone
zoneadd-ds    : adds DS records to the zone file
show-dnskey   : extract DNSKEY record that needs to uploaded to your registrar
update-tlsa   : update TLSA records with new TLSA hash, needs old and new TLSA hashes as additional parameters
```

Basically these command line options are pretty much self-explaining.

# Examples: 
Enable DNSSEC on a domain:
```
dnssec.sh enable-dnssec domain.tld
```
This will take all necessary steps to enable DNSSEC on your domain `domain.tld`, modify your zone configuration in `named.conf.local` file and output the DS key that you will need to copy & paste to your registrars website. 

When you want to change your zone file it is best to use `dnssec.sh edit-zone domain.tld`. This will load your configured editor (vim/emacs/nano/joe/...) and - after saving the zone file - increase your serial of your zone, check the zone file for errors and reloading the domain where there were no errors. 
