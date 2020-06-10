#! /bin/bash


trap "exit" INT TERM
trap "kill 0" EXIT

#! /bin/bash

if [ -z "$EMAIL" ]
then
    echo "EMAIL environment variable undefined - exiting"
    exit 1
fi


PRODUCTION_URL="https://acme-v02.api.letsencrypt.org/directory"
STAGING_URL="https://acme-staging-v02.api.letsencrypt.org/directory"


get_certificate() {
    DOMAIN=$1
    USER=$2
    
    echo "Getting certificate for domain $DOMAIN for user $USER (staging $IS_STAGING)"

    if [ "$IS_STAGING" = "1" ]
    then
        SERVER_URL=$STAGING_URL
    else
        SERVER_URL=$PRODUCTION_URL
    fi

    certbot certonly \
        --agree-tos \
        --keep \
        -n \
        --text \
        --email $USER \
        -d $DOMAIN \
        --server $SERVER_URL \
        --preferred-challenges=dns \
        --dns-dnsimple --dns-dnsimple-credentials /etc/dnsimple.ini \
        --debug
}


is_renewal_required() {
    DOMAIN=$1

    current_file="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    if [ ! -e "$current_file" ]
    then
        return
    fi

    test $(find $current_file -mtime +7)
}

find_domains() {
    for conf_file in /etc/nginx/conf.d/*.conf*
    do
        conf_file_name=${conf_file##*/}
        echo "${conf_file_name%.conf*}"
    done
}

configure_domains() {
    for domain in $(find_domains)
    do
        echo "Configuring domain $domain"

        confFile=$(ls /etc/nginx/conf.d/${domain}.conf*)
        certFile=/etc/letsencrypt/live/${domain}/fullchain.pem
        if [ -f $certFile ]
        then
            ext=${confFile##*.}
            echo "Extension = $ext"
            if [ "$ext" = "missing" ]
            then
                echo "Enabling ${domain}"
                mv $confFile ${confFile%.*}
            else
                echo "Already enabled ${domain}"
            fi
        else
            if [ "$ext" = "conf" ]
            then
                echo "Disabling ${domain}"
                mv ${confFile} "${confFile}.missing"
            else
                echo "Already disabled ${domain}"
            fi
        fi
    done
}

run_certbot() {
    exit_code=0

    echo "Starting"
    ls /etc/nginx/conf.d


    for domain in $(find_domains)
    do
        if is_renewal_required $domain
        then
            echo "Get certificate for $domain and $EMAIL"
            if ! get_certificate $domain $EMAIL
            then
                echo "Failed to get certificate for $domain"
                exit_code=1
            fi
        fi
    done

    return $exit_code

}

configure_domains

nginx -g "daemon off;" &
NGINX_PID=$!

# Manually run certbot and sleep in between invocations
while [ true ]
do
    # Run certbot, then get nginx to reload
    run_certbot
    configure_domains
    kill -HUP $NGINX_PID

    # Sleep for a week!
    sleep 604810 &
    SLEEP_PID=$!

    wait -n $SLEEP_PID $NGINX_PID
done
