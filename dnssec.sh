#!/bin/bash
# 2014-11-08 Ingo Juergensmann
# https://github.com/ingoj/dnssec.sh
# use at own risk

set -e

MODE=$1
DOMAIN=$2
if [ "${MODE}" = "update-tlsa" ] ; then 
	OLDTLSA=$3
	NEWTLSA=$4
fi
TLD=`echo ${DOMAIN} | cut -d '.' -f 2`

echo "m: ${MODE}, d: ${DOMAIN}, t: ${TLD}"

modify_zone () {
	sed -i".bak" "s/file\ \"\/etc\/bind\/${TLD}\/${DOMAIN}\";/file\ \"\/etc\/bind\/${TLD}\/${DOMAIN}\";\n\tkey-directory \"\/etc\/bind\/${TLD}\/keys\";\n\tauto-dnssec\ maintain;\n\tinline-signing yes;/g" /etc/bind/named.conf.local
	chown bind:bind /etc/bind/named.conf.local
	inc_serial
	rndc reconfig
	sleep 3
}

inc_serial () {
	SERIAL1=`grep -i serial /etc/bind/${TLD}/${DOMAIN} |  tr -d "\t" | cut -d";" -f 1`
        SERIAL2=`dig ${domain} +nssearch | awk '{print $4,$11}' | sed 's/\ /,/g' | head -n 1 | cut -d"," -f1`
	if [ ${SERIAL1} -gt ${SERIAL2} ]; then
		SERIAL=${SERIAL1}
	else 
		SERIAL=${SERIAL2}
	fi
	NEWSERIAL=`echo $((${SERIAL} + 10))`
	sed -i".bak" "s/${SERIAL1}/${NEWSERIAL}/g" /etc/bind/${TLD}/${DOMAIN}
}

edit_zone () {
	/etc/alternatives/editor /etc/bind/${TLD}/${DOMAIN}
	chown bind:bind /etc/bind/${TLD}/${DOMAIN}
	inc_serial
	named-checkzone ${DOMAIN} /etc/bind/${TLD}/${DOMAIN}
	RC=$?
	if [ $RC -eq 0 ]; then 
		rndc reload ${DOMAIN}
	else
		echo "Zone ${DOMAIN} contains errors."
	fi
}

create_dnskey () {
	echo "Generating ZSK for zone ${DOMAIN}..."
	dnssec-keygen -a RSASHA256 -b 2048 -3 -K /etc/bind/${TLD}/keys/ ${DOMAIN}
	echo "Generating KSK for zone ${DOMAIN}..."
	dnssec-keygen -a RSASHA256 -b 2048 -3 -fk -K /etc/bind/${TLD}/keys/ ${DOMAIN}
	find /etc/bind/${TLD}/keys/ -iname "K${DOMAIN}*" -exec chown bind:bind {} \;
}

load_dnskey () {
	echo "Loading keys & signing the zone ${DOMAIN}..."
	rndc loadkeys ${DOMAIN}
	rndc_reload
}

rndc_reload () {
	rndc reload
}

enable_nsec3param () {
	echo "Enabling NSEC3..."
	SALT=`pwgen -n 1024 1 | sha256sum | cut -c 20-27`
	ITER=`echo $(($RANDOM % 15 +10 ))`
	rndc signing -nsec3param 1 0 ${ITER} ${SALT} ${DOMAIN}
}

show_ds () {
	echo "Extracting DS records..."
	dig @127.0.0.1 dnskey ${DOMAIN} | dnssec-dsfromkey -f - ${DOMAIN}
}

zoneadd_ds () {
	echo "Adding DS records to zone file /etc/bind/${TLD}/${DOMAIN}..."
	rndc reconfig
	sleep 2
	echo ";; begin of DS keys" >> /etc/bind/${TLD}/${DOMAIN}
	dig @127.0.0.1 dnskey ${DOMAIN} | dnssec-dsfromkey -f - ${DOMAIN} >> /etc/bind/${TLD}/${DOMAIN}
	echo ";; end of DS keys" >> /etc/bind/${TLD}/${DOMAIN}
	show_ds
}

show_dnskey () {
	echo "Extracting DNSKEY record for ${DOMAIN}:"
	dig @127.0.0.1 dnskey ${DOMAIN} | grep "DNSKEY.*257"
	echo "Extracting DNSKEY key only for ${DOMAIN} for registrar:"
	dig @127.0.0.1 dnskey ${DOMAIN} | grep "DNSKEY.*257" | awk '{$1=$2=$3=$4=$5=$6=$7=""; print $0}'
}

update_tlsa () {
	sed -i".bak" "s/${OLDTLSA}/${NEWTLSA}/g" /etc/bind/${TLD}/${DOMAIN}
	inc_serial
	rndc_reload
}

case ${MODE} in
	enable-dnssec)
		modify_zone
		create_dnskey
		load_dnskey
		enable_nsec3param
		zoneadd_ds
		show_dnskey
		;;
	modify-zone)
		modify_zone
		;;
	edit-zone)
		edit_zone
		;;
	inc-serial)
		inc_serial
		echo $SERIAL1 $SERIAL2 $NEWSERIAL
		;;
	create-dnskey)
		create_dnskey
		;;
	load-dnskey)
		load-dnskey
		;;
	show-ds)
		show_ds
		;;
	zoneadd-ds)
		zoneadd_ds
		;;
	show-dnskey)
		show_dnskey
		;;
	update-tlsa)
		update_tlsa
		;;
	*)
		echo "No parameter given."
		echo "Usage: dnsec.sh MODE DOMAIN"
		echo ""
		echo "MODE can be one of the following:"
		echo "enable-dnssec : perform all steps to enable DNSSEC for your domain"
		echo "edit-zone     : safely edit your zone after enabling DNSSEC"
		echo "create-dnskey : create new dnskey only"
		echo "load-dnskey   : loads new dnskeys and signs the zone with them"
		echo "show-ds       : shows DS records of zone"
		echo "zoneadd-ds    : adds DS records to the zone file"
		echo "show-dnskey   : extract DNSKEY record that needs to uploaded to your registrar"
		echo "update-tlsa   : update TLSA records with new TLSA hash, needs old and new TLSA hashes as additional parameters"
		exit 1
		;;
esac


