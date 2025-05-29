# Usage check
if [ "$#" -ne 10 ]; then
  echo "Usage: $0 <PORT> <FEED_NAME> <AGENCYID> <AGENCYNAME> <GTFS_URL> <GTFSRTVEHICLEPOSITIONS> MIN_LATITUDE MAX_LATITUDE MIN_LONGITUDE MAX_LONGITUDE"
  exit 1
fi

PORT="$1"
FEED_NAME="$2"
AGENCYID="$3"
AGENCYNAME="$4"
GTFS_URL="$5"
GTFSRTVEHICLEPOSITIONS="$6"
MIN_LATITUDE="$7"
MAX_LATITUDE="$8"
MIN_LONGITUDE="$9"
MAX_LONGITUDE="$10"

export PGPASSWORD=transitclock

docker stop ${FEED_NAME}-transitime-db
docker stop ${FEED_NAME}-transitime-server

docker rm ${FEED_NAME}-transitime-db
docker rm ${FEED_NAME}-transitime-server

docker rmi ${FEED_NAME,,}-transitime

cp -f ./config/transitclock.properties transitclock.properties

cat <<EOL >> "transitclock.properties"
transitclock.avl.minLatitude=${MIN_LATITUDE}
transitclock.avl.maxLatitude=${MAX_LATITUDE}
transitclock.avl.minLongitude=${MIN_LONGITUDE}
transitclock.avl.maxLongitude=${MAX_LONGITUDE}
EOL

docker build --no-cache -t ${FEED_NAME,,}-transitime \
--build-arg TRANSITCLOCK_PROPERTIES="transitclock.properties" \
--build-arg AGENCYID="$AGENCYID" \
--build-arg AGENCYNAME="$AGENCYNAME" \
--build-arg GTFS_URL="$GTFS_URL" \
--build-arg GTFSRTVEHICLEPOSITIONS="$GTFSRTVEHICLEPOSITIONS" .

#rm transitclock.properties

docker run --name ${FEED_NAME}-transitime-db -e POSTGRES_PASSWORD=$PGPASSWORD -d postgres:9.6.3

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/${FEED_NAME}:/usr/local/transitclock/logs/ ${FEED_NAME,,}-transitime check_db_up.sh

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/${FEED_NAME}:/usr/local/transitclock/logs/ ${FEED_NAME,,}-transitime create_tables.sh

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/${FEED_NAME}:/usr/local/transitclock/logs/ ${FEED_NAME,,}-transitime import_gtfs.sh

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/${FEED_NAME}:/usr/local/transitclock/logs/ ${FEED_NAME,,}-transitime create_api_key.sh

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/${FEED_NAME}:/usr/local/transitclock/logs/ ${FEED_NAME,,}-transitime create_webagency.sh

#docker run --name transitclock-server-instance --rm --link transitclock-db:postgres -e PGPASSWORD=$PGPASSWORD transitclock-server ./import_avl.sh

#docker run --name transitclock-server-instance --rm --link transitclock-db:postgres -e PGPASSWORD=$PGPASSWORD transitclock-server ./process_avl.sh

docker run --name ${FEED_NAME}-transitime-server --rm --link ${FEED_NAME}-transitime-db:postgres -e PGPASSWORD=$PGPASSWORD -v ~/ehcache/${FEED_NAME}:/usr/local/transitclock/cache/ -p $PORT:8080 -d ${FEED_NAME,,}-transitime start_transitclock.sh
