from alto import number_of_bits, alto_score, generate_lookup

from pyspark import SparkConf
from pyspark.sql import SparkSession
import math
import time
import sys
import os

os.environ['PYSPARK_PYTHON'] = '/usr/bin/python3.8'
os.environ['PYSPARK_DRIVER_PYTHON'] = '/usr/bin/python3.8'

block_size = 1024

# run with
# python3 semi_alto.py /data/damiano/alto/amazon.tns num_dim mode

if __name__ == "__main__":
    start = time.time()
    my_conf = SparkConf().setMaster('local[*]').setAppName('alto').set('spark.driver.memory', '400G')
    spark = SparkSession.builder.config(conf=my_conf).getOrCreate()

    file_path = sys.argv[1]
    file_name = file_path.split('/')[-1]

    data = spark.read.csv(file_path, sep=' ', lineSep='\n', inferSchema='true').rdd.map(list)

    # data = data.sample(withReplacement=False, fraction=0.1)

    n_dimensions = int(sys.argv[2])

    mode_axis = int(sys.argv[3])
    assert mode_axis in [i for i in range(n_dimensions)]

    print('********')
    print(file_name)
    print(mode_axis)
    print('********')

    modes_dict = dict()
    modes_dict['amazon.tns'] = [4821207, 1774269, 1805187]
    modes_dict['delicious-alto.tns'] = [532924, 17262471, 2480308, 1443]
    modes_dict['lbnl-alto.tns'] = [1605, 4198, 1631, 4209, 868131]
    modes_dict['nell-1.tns'] = [2902330, 2143368, 25495389]
    modes_dict['nell-2.tns'] = [12092, 9184, 28818]
    modes_dict['reddit-2015.tns'] = [8211298, 176962, 8116559]
    modes_dict['patents.tns'] = [46, 239172, 239172]
    modes_dict['small.tns'] = [6, 9, 10]

    # n_bits = [number_of_bits(data.map(lambda x: x[i]).distinct().count()) if i != mode_axis else 0 for i in range(n_dimensions)]

    n_bits = [number_of_bits(x) for x in modes_dict[file_name]]
    n_bits[mode_axis] = 0

    lookup = generate_lookup(n_bits)
    print('Done computing number of bits.')

    data = data.map(lambda x: x + [alto_score(x[:n_dimensions], n_bits, lookup)] )
    print('Done computing (semi)alto.')

    # num_partitions = data.map(lambda x: x[1]).distinct().count() // block_size + 1
    num_partitions = modes_dict[file_name][mode_axis] // block_size + 1
    print('num_partitions = ' + str(num_partitions))

    column_names = [str(i) for i in range(n_dimensions + 1)] + ['alto']

    if num_partitions == 1:
        data = data.sortBy(lambda x: x[-1])
        data = data.toDF(column_names)
    else:
        data = data.sortBy(lambda x: x[mode_axis])
        data = data.map(lambda x : (x[mode_axis], [x[i] for i in range(len(x)) if i != mode_axis]))
        data = data.partitionBy(num_partitions, lambda x: int(x // block_size))
        data = data.map(lambda x: x[1][:mode_axis] + [x[0]] + x[1][mode_axis:])
        data = data.toDF(column_names).sortWithinPartitions(['alto'])
    
    data = data.drop('alto')
    file_name = file_name.split('.')[0] + str(mode_axis) + '.tns'
    data.write.option('header', False).option('sep', ' ').option('linSep', '\n').csv('/data/damiano/semi_alto/' + file_name)   

    print('Done')