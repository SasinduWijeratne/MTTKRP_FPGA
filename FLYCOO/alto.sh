export PYSPARK_PYTHON=/usr/bin/python3.8
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3.8

echo "Starting..."

python3.8 alto.py /data/damiano/unprocessed/delicious-4d.tns 4 /data/damiano/alto/delicious-4d-alto.tns
echo "Done with delicious-4d.tns"

python3.8 alto.py /data/damiano/unprocessed/lbnl-network.tns 5 /data/damiano/alto/lbnl-network-alto.tns
echo "Done with lbnl-network.tns"

python3.8 alto.py /data/damiano/unprocessed/patents.tns 3 /data/damiano/alto/patents-alto.tns
echo "Done with patents.tns"

echo "DONE!"