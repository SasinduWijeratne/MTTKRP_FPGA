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

def number_of_bits(x:int) -> int:
    return math.ceil(math.log(x, 2))

def alto_score(x:list, n_bits:list, lookup:list) -> int:
    """
    Calculate the Alto score for a given list of integers.
    i: take ith elem of x
    j: take jth bit of that element
    lookup[i][j]: final position of the bit

    Note: order represents the order in which to iterate over x.
    It always break ties in favor of the first element. 
    I.e. if n_bits[i] == n_bits[j] and i < j, then i is favored.
    """
    order = [a for _, a in sorted(zip(n_bits, [i for i in range(len(x))]))]
    alto = 0
    for i, arr in enumerate(lookup):
        for j, pos in enumerate(arr):
            elem = x[order[i]]
            mask = 1 << j
            alto |= ((elem & mask) << (pos - j))
    return alto

def generate_lookup(n_bits:list) -> list:
    """
    Generates 2D lookup table in which lookup[i][j]
    represents the final position of the jth bit of the ith element.
    """
    n_bits = sorted(n_bits)
    total_bits = sum(n_bits)
    lookup = []
    counter = 0
    for i in range(len(n_bits)):
        lookup.append([])
    while counter < total_bits:
        for i in range(len(n_bits)):
            if(len(lookup[i]) < n_bits[i]):
                lookup[i].append(counter)
                counter += 1
    return lookup

if __name__ == "__main__":
    start = time.time()
    my_conf = SparkConf().setMaster('local[*]').setAppName('alto').set('spark.driver.memory', '10G').set('spark.executor.memory', '10G')
    spark = SparkSession.builder.config(conf=my_conf).getOrCreate()

    # read file

    # get command line arg
    file_path = sys.argv[1]

    data = spark.read.csv(file_path, sep=' ', lineSep='\n', inferSchema='true').rdd.map(list)
    # data = data.sample(withReplacement=False, fraction=0.1)
    n_dimensions = int(sys.argv[2])
    n_bits = [number_of_bits(data.map(lambda x: x[i]).distinct().count()) for i in range(n_dimensions)]
    lookup = generate_lookup(n_bits)
    print('Done computing number of bits.')
    # alto = alto_score([6324, 1422, 5])
    data = data.map(lambda x: x + [alto_score(x[:n_dimensions], n_bits, lookup)] ).sortBy(lambda x: x[-1])
    print('Done computing (semi)alto.')

    data = data.map(lambda x: x[:-1]) # drop alto score
    
    # save to csv
    data.toDF().write.option('header', False).option('sep', ' ').option('linSep', '\n').csv(sys.argv[3])
    print('Done in ' + str(time.time() - start) + ' seconds.')
