METADATAFILE=${1}
FILTERNAME=${2}
FILTERVALUE=${3}
SNAPSHOTPARTITION=${4}

echo "UPPER('$FILTERVALUE')"
spark-submit --master yarn --deploy-mode cluster --queue spark --num-executors 7 --executor-memory 5g --proxy-user spark --files /usr/hdp/current/spark-client/conf/hive-site.xml cooking_engine.py $METADATAFILE "$SNAPSHOTPARTITION" "UPPER($FILTERNAME) = UPPER('$FILTERVALUE')" 
