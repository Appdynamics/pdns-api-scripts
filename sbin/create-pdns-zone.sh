#!/bin/bash

#FIXME: add license header

USAGE="\
create-pdns-zone.sh [options] zone.name.tld. primary.master.nameserver.tld.
        [supplementary.master.nameserver1.tld. ...]

Create a new zone in the PowerDNS zone running on localhost with the given
name, contact email, and primary, master name server's fully-qualified
hostname.

Options:
    -H <hostmaster email>   Administrative contact for the DNS zone.
                            Default specified by PowerDNS's
                            'default-soa-mail' configuration parameter.
    -t <0-2147483647>       Zone default TTL, in seconds on caching name
                            servers. Default: 86400, (1 day).
    -s <1-4294967295>       Zone serial number.  Unsigned 32-bit integer.
                            Maximum increment: 2147483647. Default: 1
    -r <1-2147483647>       Slave refresh interval, in seconds.
                            Default: 1200, (20 minutes)
    -R <1-2147483647>       Slave retry interval, in seconds, if it fails to
                            contact the master after receiving a NOTIFY
                            message, or after the zone's refresh timer has
                            expired. Default: 180, (3 minutes)
    -e <1-2147483647>       Expiration time, in seconds, since the last zone
                            transfer.  Slave servers will stop responding
                            authoritatively for a zone when this timer expires.
                            Default: 1209600, (2 weeks)
    -n <1-10800>            Time, in seconds that a resolver may cache a
                            negative lookup, (NXDOMAIN), result.
                            Default: 60, (1 minute).
    -d                      Enable additional debugging output.
    -C </path/to/pdns.conf> Path to alternate PowerDNS configuration file.
                            Default: @ETCDIR@/pdns/pdns.conf
    -h                      Print this usage message and exit.
"

PDNS_CONF=@ETCDIR@/pdns/pdns.conf

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_API_IP \
    PDNS_API_PORT \
    PDNS_API_KEY

source @SHAREDIR@/pdns-api-script-functions.sh

# TODO: RFC822, sections 3.3 and 6 actually allow for many more special
# characters in the "local-part" token, but supporting all of them takes us to
# the land of diminishing returns.  If we need to support any RFC822-compliant
# email address, we need to reimplement this tool in a different language that
# has available escape-for-JSON library routines
#
# $1: email address to check for safety.
is_safe_email(){
    [ ${#@} -eq 1 ] && [[ $1 =~ ^[-A-Za-z0-9._+]+@([-A-Za-z0-9]{2,}\.)+$ ]]
}

# Defaults, minimums, and maximums
TTL=86400
TTL_MIN=0
TTL_MAX=2147483647
SERIAL_NUM=1
SERIAL_NUM_MIN=1
SERIAL_NUM_MAX=4294967295
REFRESH=1200
REFRESH_MIN=1
REFRESH_MAX=2147483647
RETRY=180
RETRY_MIN=1
RETRY_MAX=2147483647
EXIRY=1209600
EXPIRY_MIN=1
EXPIRY_MAX=2147483647
NEGATIVE_TTL=60
NEGATIVE_TTL_MIN=0
NEGATIVE_TTL_MAX=10800

HELP=false
DEBUG=false
HOSTMASTER_EMAIL=


# Validate and process input
input_errors=0
while getopts ":H:t:s:r:R:e:n:dC:h" flag; do
    case flag in
        H)
            if is_safe_email "$OPTARG"; then
                HOSTMASTER_EMAIL=$OPTARG
            else
                >&2 echo "'$OPTARG' is not a correctly"
                >&2 echo "formatted or fully-qualified email address."
                trailing_dot_msg
                ((input_errors++))
            fi
        ;;
        t)
            if test "$OPTARG" -ge $TTL_MIN >/dev/null 2>&1 && test "$OPTARG" -le $TTL_MAX >/dev/null 2>&1; then
                TTL=$OPTARG
            else
                >&2 echo "Zone default TTL must be an integer from $TTL_MIN to $TTL_MAX."
            fi
            ((input_errors++))
        ;;
        s)
            if test "$OPTARG" -ge $SERIAL_NUM_MIN >/dev/null 2>&1 && \
                    test "$OPTARG" -le $SERIAL_NUM_MAX >/dev/null 2>&1; then
                SERIAL_NUM=$OPTARG
            else
                >&2 echo "Zone serial number must be an integer from $SERIAL_NUM_MIN to $SERIAL_NUM_MAX."
            fi
            ((input_errors++))
        ;;
        r)
            if test "$OPTARG" -ge $REFRESH_MIN >/dev/null 2>&1 && test "$OPTARG" -le $REFRESH_MAX >/dev/null 2>&1; then
                REFRESH=$OPTARG
            else
                >&2 echo "Zone refresh interval must be an integer from $REFRESH_MIN to $REFRESH_MAX."
            fi
            ((input_errors++))
        ;;
        R)
            if test "$OPTARG" -ge $RETRY_MIN >/dev/null 2>&1 && test "$OPTARG" -le $REFRESH_MAX >/dev/null 2>&1; then
                RETRY=$OPTARG
            else
                >&2 echo "Zone Retry interval must be an integer from $RETRY_MIN to $REFRESH_MAX."
            fi
            ((input_errors++))
        ;;
        e)
            if test "$OPTARG" -ge $EXPIRY_MIN >/dev/null 2>&1 && test "$OPTARG" -le $EXPIRY_MAX >/dev/null 2>&1; then
                EXPIRY=$OPTARG
            else
                >&2 echo "Zone expiry time must be an integer from $EXPIRY_MIN to $EXPIRY_MAX."
            fi
        ;;
        n)
            if test "$OPTARG" -ge $NEGATIVE_TTL_MIN >/dev/null 2>&1 && \
                    test "$OPTARG" -le $NEGATIVE_TTL_MAX >/dev/null 2>&1; then
                NEGATIVE_TTL=$OPTARG
            else
                >&2 echo "Zone negative answer TTL must be an integer from $NEGATIVE_TTL_MIN to $NEGATIVE_TTL_MAX."
            fi
            ((input_errors++))
        ;;
        h)
            HELP=true
        ;;
        d)
            DEBUG=true
            CURL_VERBOSE=-v
        ;;
        C)
            PDNS_CONF="$OPTARG"
        ;;
        *)
            >&2 echo "'-$OPTARG' is not a supported option."
            ((input_errors++))
        ;;
    esac
done

read_pdns_config "$PDNS_CONF"

if [ -z "$HOSTMASTER_EMAIL" ]; then
    HOSTMASTER_EMAIL=$(curl -s --header "X-API-KEY: $PDNS_API_KEY"\
            http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/config | \
            jq -r '.[] | select(.name=="default-soa-mail").value')
    if [ -z "$HOSTMASTER_EMAIL" ]; then
        >&2 echo "Hostmaster email not specified and 'default-soa-mail' not configured in pdns."
        ((input_errors++))
    fi
fi

if $HELP; then
    echo "$USAGE"
    exit 0
fi

shift $((OPTIND-1))

if is_valid_dns_name "$1"; then
    ZONE_NAME=$1
else
    >&2 echo "'$1' is not a correctly"
    >&2 echo "formatted or fully-qualified zone name."
    trailing_dot_msg
    ((input_errors++))
fi

if is_valid_dns_name "$3"; then
    PRIMARY_MASTER=$3
else
    >&2 echo "'$3' is not a correctly"
    >&2 echo "formatted or fully-qualified primary master name server hostname."
    trailing_dot_msg
    ((input_errors++))
fi

shift 2

# grab and validate supplementary name server args
i=0
while [ -n "$1" ]; do
    if is_valid_dns_name "$1"; then
        supplementary_dns[$i]=$1
    else
        >&2 echo "'$1' is not a correctly"
        >&2 echo "formatted or fully-qualified supplementary name server hostname."
        trailing_dot_msg
        ((input_errors++))
    fi
    shift
    ((i++))
done

if [ $input_errors -gt 0 ]; then
    >&2 echo "$USAGE"
    exit $input_errors
fi

if zone_exists "$ZONE_NAME"; then
    >&2 echo "Zone '$ZONE_NAME' already exists."
    exit 1
else
    NAME_SERVERS="\"$PRIMARY_MASTER\""

    for name_server in ${supplementary_dns[@]}; do
        NAME_SERVERS="$NAME_SERVERS, \"$name_server\""
    done

    # REST CALL to create zone
    curl $CURL_VERBOSE\
        --request POST\
        --header "Content-Type: application/json"\
        --header "X-API-Key: $PDNS_API_KEY"\
        --data @-\
        http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones <<REQUEST_BODY
{
    "name": "$ZONE_NAME",
    "type": "Zone",
    "kind": "Native",
    "masters": [],
    "nameservers": [$NAME_SERVERS],
    "rrsets": [
        {
            "name": "$ZONE_NAME",
            "type": "SOA",
            "ttl": $TTL,
            "records": [
                {
                    "disabled": false,
                    "content": "$PRIMARY_MASTER $HOSTMASTER_EMAIL $SERIAL_NUM $REFRESH $RETRY $EXIRY $NEGATIVE_TTL"
                }
            ]
        }
    ]
}
REQUEST_BODY
echo # move prompt below end of curl output
fi
