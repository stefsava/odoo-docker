#!/bin/bash

# This script https://gist.github.com/stefsava/19e60dfd3eff08dd5c8e57177b8abb1f
# install Odoo community edition (https://odoo-community.org)
# on dokku (http://dokku.viewdocs.io/dokku/)
# using the elicocorp docker image (https://github.com/Elico-Corp/odoo-docker).
#
# Any suggestions are welcome.

# APPNAME=odoo
# PGNAME=odoo
VERSION=18.0
# MASTERPASSWORD=strong_odoo_master_password
# PGPASSWORD=strong_pg_odoo_password

usage() { # Function: Print a help message.
  echo "Usage: $0 -a APPNAME -m MASTERPASSWORD -p PGPASSWORD [ -d PGNAME ] [ -v VERSION ]" 1>&2
}

exit_abnormal() { # Function: Exit with error.
  usage
  exit 1
}

if [[ $1 == "" ]]; then # If no parameters.
  exit_abnormal # Exit abnormally.
fi

while getopts ":a:m:p:d:v:" options; do        # Loop: Get the next option;
                                               # use silent error checking;
                                               # options n and t take arguments.
  case "${options}" in                         #
    a)
      APPNAME=${OPTARG}
      ;;
    m)
      MASTERPASSWORD=${OPTARG}
      ;;
    p)
      PGPASSWORD=${OPTARG}
      ;;
    d)
      PGNAME=${OPTARG}
      ;;
    v)
      VERSION=${OPTARG}
      ;;
    :)                                         # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                            # Exit abnormally.
      ;;
    *)                                         # If unknown (any other) option:
      exit_abnormal                            # Exit abnormally.
      ;;
  esac
done

if [[ -z "$APPNAME" ]]; then
  echo "Error: missing -a APPNAME parameter!" 1>&2
  exit_abnormal                            # Exit abnormally.
fi

if [[ -z "$PGNAME" ]]; then
  echo "Notice: PGNAME set as APPNAME (${APPNAME})" 1>&2
  PGNAME="${APPNAME}"
fi

if [[ -z "$MASTERPASSWORD" ]]; then
  echo "Error: missing -m MASTERPASSWORD parameter!" 1>&2
  exit_abnormal                            # Exit abnormally.
fi

if [[ -z "$PGPASSWORD" ]]; then
  echo "Error: missing -p PGPASSWORD parameter!" 1>&2
  exit_abnormal                            # Exit abnormally.
fi

echo "Odoo appname: ${APPNAME}"
echo "Odoo version: ${VERSION}"
echo "Odoo master password: ${MASTERPASSWORD}"
echo "PostgreSQL service name: ${PGNAME}"
echo "PostgreSQL user name: odoo"
echo "PostgreSQL odoo user password: ${PGPASSWORD}"

##############################################################
# exit 0
##############################################################

# ( \
#   [ -z "$APPNAME" ] || \
#   [ -z "$PGNAME" ] || \
#   [ -z "$VERSION" ] || \
#   [ -z "$MASTERPASSWORD" ] || \
#   [ -z "$PGPASSWORD" ] \
# ) && echo "missing config" && exit -1

dokku apps:create $APPNAME

dokku postgres:create $PGNAME
dokku postgres:link $PGNAME $APPNAME

echo "
  CREATE user odoo WITH password '$PGPASSWORD';
  ALTER user odoo WITH createdb;
" | dokku postgres:connect $PGNAME

cd /var/lib/dokku/data/storage/
mkdir -p {$APPNAME/filestore,$APPNAME/sessions,$APPNAME/addons,$APPNAME/ssh}

echo '#!/bin/bash
pip3 install codicefiscale
pip3 install phonenumbers
' > $APPNAME/scripts/startup.sh

echo '# list the OCA project dependencies, one per line
# add a github url if you need a forked version
# url is not required for OCA projects
# project https://github.com/OCA/project.git $VERSION
# project $VERSION
# account-payment $VERSION
# hr $VERSION
# l10n-italy $VERSION
' >> $APPNAME/addons/oca_dependencies.txt

chown -R 32767:32767 $APPNAME
dokku storage:mount $APPNAME /var/lib/dokku/data/storage/$APPNAME/addons:/opt/odoo/additional_addons
dokku storage:mount $APPNAME /var/lib/dokku/data/storage/$APPNAME/filestore:/opt/odoo/data/filestore
dokku storage:mount $APPNAME /var/lib/dokku/data/storage/$APPNAME/sessions:/opt/odoo/data/sessions
dokku storage:mount $APPNAME /var/lib/dokku/data/storage/$APPNAME/scripts:/opt/scripts
dokku storage:mount $APPNAME /var/lib/dokku/data/storage/$APPNAME/ssh:/opt/odoo/ssh:ro
dokku storage:report $APPNAME

dokku proxy:ports-set $APPNAME http:80:8069

dokku config:set $APPNAME \
  TARGET_UID=32767 \
  ODOO_ADMIN_PASSWD=$MASTERPASSWORD\
  ODOO_DB_HOST=dokku-postgres-$PGNAME \
  ODOO_DB_USER=odoo \
  ODOO_DB_PASSWORD=$PGPASSWORD \
  DOKKU_DOCKERFILE_START_CMD="start"

dokku git:from-image $APPNAME elicocorp/odoo:$VERSION

dokku letsencrypt $APPNAME
