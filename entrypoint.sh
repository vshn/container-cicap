#!/bin/bash
set -e

envsubst < /usr/local/c-icap/etc/squidclamav.conf.template > /usr/local/c-icap/etc/squidclamav.conf

echo "Starting c-icap..."
exec /usr/local/c-icap/bin/c-icap "$@"
