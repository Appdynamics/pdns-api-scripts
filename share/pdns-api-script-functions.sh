# FIXME: add license header here

if [[ $(id -u) -ne 0 ]]; then
    >&2 echo $0 must be run as root to access the PowerDNS REST API
    exit 1
fi

# 'declare' variables we set with 'eval' below just to keep the IDE happy
declare PDNS_API_IP \
    PDNS_API_PORT \
    PDNS_API_KEY

# set $PDNS_API_IP and $PDNS_API_PORT based on the contents of '@ETCDIR@/pdns/pdns.conf'
eval $(awk -F = '/^webserver-address=/{print "PDNS_API_IP="$2"\n"};/^webserver-port=/{print "PDNS_API_PORT="$2"\n"}'\
    "@ETCDIR@/pdns/pdns.conf")

# set $PDNS_API_KEY based on the contents of '@ETCDIR@/pdns/pdns.conf.d/api-key.conf'
eval $(awk -F = '/^api-key=/{print "PDNS_API_KEY="$2"\n"}' "@ETCDIR@/pdns/pdns.conf.d/api-key.conf")

# return 0 (true) if given exactly one argument, and $1 is a valid hostname
is_valid_dns_name(){
    [ ${#@} -eq 1 ] && [[ $1 =~ ^([-A-Za-z0-9]{2,}\.)+$ ]]
}

is_valid_ipv4_address(){
    [ ${#@} -eq 1 ] # FIXME: add validation for IP addresses
}

zone_exists(){
    is_valid_dns_name $@ && \
        [[ $(curl -s -w \\n%{http_code}\\n --header "X-API-KEY: $PDNS_API_KEY" \
            http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$1 | tail -1) -eq 200 ]]
}

trailing_dot_msg(){
    >&2 echo "Please note that the trailing dot, ('.'), is required."
}