from pyspark import SparkContext, SparkConf
from pyspark.sql import SparkSession
import math
import time
import sys
import os

# export PYSPARK_PYTHON=/usr/bin/python3.8
# export PYSPARK_DRIVER_PYTHON=/usr/bin/python3.8

os.environ['PYSPARK_PYTHON'] = '/usr/bin/python3.8'
os.environ['PYSPARK_DRIVER_PYTHON'] = '/usr/bin/python3.8'



if __name__ == "__main__":
    start = time.time()
    my_conf = SparkConf().setMaster('local[*]').setAppName('alto').set('spark.driver.memory', '6G').set('spark.executor.memory', '16G')
    spark = SparkSession.builder.config(conf=my_conf).getOrCreate()

    # read file
    file_path = sys.argv[1]
    data = spark.read.csv(file_path, sep=' ', lineSep='\n', inferSchema='true').rdd
    data = data.map(lambda x: x[:-1])
    data.toDF().write.option('header', False).option('sep', ' ').option('linSep', '\n').csv('/data/damiano/alto/amazon-reviews.tns')
    print('Time: ', time.time() - start)