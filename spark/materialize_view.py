import datetime
import pyspark
from pyspark import SparkConf, SparkContext
from pyspark.sql import SQLContext, SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import StructType, StructField
from pyspark.sql.types import DoubleType, IntegerType, StringType, TimestampType
from pyspark.sql.functions import udf
from subprocess import Popen, PIPE
import sys
import traceback

spark = SparkSession \
    .builder \
    .appName("Test_Aggregation") \
    .enableHiveSupport() \
    .getOrCreate()
sc = spark.sparkContext

if __name__ == "__main__":

    try:
        database_name = None
        source_view_name = None
        partitioning_column_name = None
        partitioning_column_name_and_type = None
        destination_table_name = None

        workflowStartTime = datetime.datetime.now()
        if len(sys.argv) > 1:
            database_name = str(sys.argv[1])
        if len(sys.argv) > 2:
            source_view_name = str(sys.argv[2])
        if len(sys.argv) > 3:
            partitioning_column_name = str(sys.argv[3])
        else:
            partitioning_column_name = ""
        if len(sys.argv) > 4:
            destination_table_name = str(sys.argv[4])
        else:
            destination_table_name = "m_" + source_view_name
        
        destination_table_name = destination_table_name.replace("`", "")

        if ((database_name is None) or (source_view_name is None)):
            # print("ERROR: either database or source view name is not provided.\nUsage: materialize_view.py <database_name> <source_view_name> [<partitioning_column>] [<destination_view_name>]")
            exit

        df = spark.sql("describe `%s`.`%s`" % (database_name, source_view_name)).collect()
        reportingperiods = spark.sql("select reportingperiod from `%s`.current_reporting_period" % (database_name)).collect()
        # sql = "drop table if exists `%s`.`%s`;\n\n" % (database_name, destination_table_name)
        sql = "CREATE TABLE IF NOT EXISTS `%s`.`%s` (" % (database_name, destination_table_name)
        firstRow = True

        for curCol in df:
            dataType = curCol.data_type
            
            if (curCol.col_name.lower() != partitioning_column_name.lower()):
                sql = sql + ("" if firstRow else ",") + "\n\t`" + curCol.col_name + "` " + dataType
                firstRow = False
            else:
                partitioning_column_name_and_type = "`" + curCol.col_name + "` " + dataType

        sql = sql + ")\n"

        if (partitioning_column_name_and_type):
            sql = sql + "PARTITIONED BY (" + partitioning_column_name_and_type + ")\n"

        sql = sql + "STORED AS ORC\n"
        sql = sql + "LOCATION '/data/ccep/processed/%s';\n" % (destination_table_name)

        if (partitioning_column_name_and_type):
            for curReportingPeriod in reportingperiods:
                sql = sql + "ALTER TABLE `%s`.`%s` DROP IF EXISTS PARTITION (`%s` = '%s');\n" % (database_name, destination_table_name, partitioning_column_name, curReportingPeriod.reportingperiod)
        else:
            sql = sql + "DELETE FROM `%s`.`%s`;\n" % (database_name, destination_table_name)

        sql = sql + "\n\nINSERT INTO `%s`.`%s`" % (database_name, destination_table_name)
        
        if (partitioning_column_name_and_type):
            sql = sql + " PARTITION (%s)" % partitioning_column_name
        
        sql = sql + "\nSELECT"
        firstRow = True

        for curCol in df:
            if (curCol.col_name.lower() != partitioning_column_name.lower()):
                sql = sql + ("" if firstRow else ",") + "\n\t`" + curCol.col_name + "`"
                firstRow = False
        
        if (partitioning_column_name_and_type):
            sql = sql + ("" if firstRow else ",") + "\n\t`" + partitioning_column_name.lower() + "`" # partitioning column goes last

        sql = sql + "\nFROM `%s`.`%s`;" % (database_name, source_view_name)

        print(sql)
        # for curSql in sql.split(";"):
        #     # print(curSql)
        #     if (len(curSql) > 0):
        #         spark.sql(curSql)

        workflowEndTime = datetime.datetime.now()
        message = 'INFO: View materialized. Started at: %s, completed at: %s, total time:%s\n\t' % (workflowStartTime, workflowEndTime, workflowEndTime-workflowStartTime)
        # print(message)
    except:
        # print("ERROR: Exception when processing")
        error_message = str(sys.exc_info()[1])
        traceback.print_exc(file=sys.stdout)

    