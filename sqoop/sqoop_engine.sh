USERNAME=""
PASSWORD=''
OPERATION="$1"
#set -e
if [ "$OPERATION" = "import" ]
then 
    LOAD_TYPE="$2"
    THREADS="$3"
    SERVER="$4"
    DATABASE="$5"
    TABLE="$6"
    CHECK_COLUMN="$7"
    TARGET_DIR="$8"
    CONDITION=${9}
    TARGET_DIR_TABLESCHEMA=${10}
    SNAPSHOTPARTITION=${11}
    TABLE_CATALOG=${12}
    password="$PASSWORD"
    JOB_NAME="import_"$DATABASE"_"$TABLE"_job"
    list_jobs=`sqoop job -list`

    if [ "$CONDITION" = "" ]
    then
        echo "No Where Clause"
        WHERECLAUSE="1=1"
    else
        echo "We have where clause $CONDITION"
        WHERECLAUSE="$CONDITION"
        echo "$WHERECLAUSE"
    fi

    #echo "List of jobs: $list_jobs"
 
    echo "**********************************************"
    echo "sqoop import table schema metadata for $TABLE"
      sqoop import --connect "jdbc:sqlserver://$SERVER.paraport.com;database=$DATABASE;username=$USERNAME;password=$password" --delete-target-dir --query "select '$TABLE_CATALOG' AS TABLE_NAME,COLUMN_NAME,ORDINAL_POSITION,IS_NULLABLE,DATA_TYPE,case when CHARACTER_MAXIMUM_LENGTH is not null then  CHARACTER_MAXIMUM_LENGTH when NUMERIC_PRECISION is not null then  NUMERIC_PRECISION when DATETIME_PRECISION is not null then  DATETIME_PRECISION else null end as [Precision], case when NUMERIC_SCALE is not null then  NUMERIC_SCALE else null end as [scale] from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = '$TABLE' and \$CONDITIONS" --target-dir $TARGET_DIR_TABLESCHEMA --fields-terminated-by "\0x263A" --lines-terminated-by "\n" -m 1
    if [ $? != 0 ]
    then
	echo "step 1 failed"
	  exit 1
    fi 
    
    if [ "$LOAD_TYPE" = "incremental" ]
    then
        if echo $list_jobs | grep -wq "$JOB_NAME";
        then
            echo "Job exists $JOB_NAME, executing job************************"
            sqoop job --exec $JOB_NAME
        else 
            echo "**********************Job doesnot exists creating new job $JOB_NAME"
            echo "****************** CREATE INCREMENTAL LOAD JOB **********************"
                  sqoop job --create $JOB_NAME -- import --connect "jdbc:sqlserver://$SERVER.paraport.com;database=$DATABASE;username=$USERNAME;password=$password" --table $TABLE  --where "$WHERECLAUSE" --target-dir $TARGET_DIR  --incremental append --check-column $7 --split-by $7 --fields-terminated-by "\0x263A" --lines-terminated-by "\n" -m $THREADS --last-value '1900-01-01 00:00:00.000' --hive-drop-import-delims --null-string '' --null-non-string ''
            if [ $? != 0 ]
	    then
	          echo "incremental load failed"
                  exit 1
            fi	 
	    wait
            echo "****************** EXECUTE INCREMENTAL LOAD JOB *********************"
            sqoop job --exec $JOB_NAME
            make
        fi
    else
        echo "****************** CREATE FULL/SNAPSHOT LOAD JOB ***************************"
        if  [ "$LOAD_TYPE" = "snapshot" ]
        then
            TARGET_DIR=$TARGET_DIR"/"$SNAPSHOTPARTITION
            echo "$TARGET_DIR"
        fi
           sqoop import --connect "jdbc:sqlserver://$SERVER.paraport.com;database=$DATABASE;username=$USERNAME;password=$password" --delete-target-dir --table $TABLE --where "$WHERECLAUSE" --target-dir $TARGET_DIR --fields-terminated-by "\0x263A" --lines-terminated-by "\n" --split-by $CHECK_COLUMN --num-mappers $THREADS --hive-drop-import-delims --null-string '' --null-non-string ''
        if [ $? != 0 ]
        then
            echo "full/snapshot failed"
	    exit 1
	fi
        wait
        echo "****************** EXECUTE FULL LOAD JOB ****************************"
    fi
else
    SERVER="$2"
    DATABASE="$3"
    TABLE="$4"
    VERSION="$6"
    YEARQUARTER="$5"
    password="$PASSWORD" 
    echo "Export -----------------------------$HIVEDATABASE     $HIVETABLE"
    echo "delete from $TABLE where version=$VERSION and reportingperiod='"$YEARQUARTER"'"
    sqoop eval --connect "jdbc:sqlserver://$SERVER.paraport.com;database=$DATABASE;username=$USERNAME;password=$password" --query "delete from $TABLE where version=$VERSION and reportingperiodname='"$YEARQUARTER"'"
    sqoop export --connect "jdbc:sqlserver://$SERVER.paraport.com;database=$DATABASE;username=$USERNAME;password=$password" --table $TABLE --export-dir "/data/ccep/processed/reportingmetricssnapshot_new/reportingperiodname=$YEARQUARTER/version=$VERSION" --input-fields-terminated-by '|' --batch -- --schema dbo
    if [ $? != 0 ]
    then
        echo "export failed"
    	exit 1
    fi 
fi
