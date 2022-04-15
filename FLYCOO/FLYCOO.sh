
for i in {0..4}
do
    /usr/bin/python3.8 FLYCOO.py /data/damiano/lbnl.tns 5 $i
done

for i in {0..3}
do
    /usr/bin/python3.8 FLYCOO.py /data/damiano/delicious.tns 4 $i
done

for i in {0..2}
do
    /usr/bin/python3.8 FLYCOO.py /data/amazon.tns 3 $i
    /usr/bin/python3.8 FLYCOO.py /data/nell-1.tns 3 $i
    /usr/bin/python3.8 FLYCOO.py /data/nell-2.tns 3 $i
done
