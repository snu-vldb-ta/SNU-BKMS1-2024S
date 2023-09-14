# Run TPC-C Benchmark Varying Buffer Pool Size

## Overview
In this experiment, you will learn to measure the hit/miss ratio in MySQL while running the TPC-C benchmark. You will also measure the performence metrics by changing the buffer sizes. Then, you will analyze the impact of different buffer sizes on the overall performance (e.g., transaction throughput, hit ratio, read write IOPS, etc.)

Follow the guide below. If you have any questions, don't hesitate to contact me via email (kyongshikl@gmail.com)

## Prerequisite
- You should install Ubuntu, MySQL, and tpcc-mysql before you start this experiment.
- Follow the [guide](https://github.com/kyongs/MySQL-TPCC-Installation) for the installation.
- Refer to the [link](https://github.com/kyongs/mysql57-buffer-pool-experiment.md/blob/main/FAQ.md) to solve the errors.

## Instructions


1. Restart a MySQL server
- Before starting a MySQL server, update the buffer pool size to 10% (then,30%, 50%) of your TPC-C database size. For example, if you load 20 warehouses (e.g., about 2G database size), change the value of innodb_buffer_pool_size in my.cnf to 200M:
```bash
$ vi /path/to/my.cnf
...
innodb_buffer_pool_size=200M
...
```

- (Optional) Also, if you have a backup test directory, overwrite it to the existing test directory.
```bash
$ rm -rf /path/to/data-dir/*
$ cp -r /path/to/data-dir-backup/* /path/to/data-dir

# Ex)
# $ rm -rf /home/vldb/test-data/*
# $ cp -r /home/vldb/test-data-backup/* /home/vldb/test-data
```

- Start a MySQL server:
```bash
$ ./bin/mysqld_safe --defaults-file=/path/to/my.cnf
```

2. Run the TPC-C benchmark
Run the benchmark by modifying the experimental parameters to match your system specifications. For example:
```bash
$ ./tpcc_start -h 127.0.0.1 -S /tmp/mysql.sock -d tpcc -u root -p "yourPassword" -w 20 -c 8 -r 10 -l 1200 | tee tpcc-result.txt
```

3. Monitor the buffer hit/miss ratio of MySQL
- While running the benchmark, collect performance metrics (e.g., I/O status, transaction throughput, hit/miss ratio) and record them in a separate file for future analysis. Refer to the [performance monitoring guide](https://github.com/kyongs/MySQL-TPCC-Installation/blob/main/4_performance_analysis.md).
- Also, regarding hit ratio, this is a way to monitor buffer hit rate.
```bash
$ ./bin/mysql -uroot -pyourPassword
Welcome to the MySQL monitor.  Commands end with ; or \g.Your MySQL connection id is 8Server version: 8.0.15 Source distribution
Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show engine innodb status;
...
----------------------
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 2353004544
Dictionary memory allocated 373557
Buffer pool size   524288
Free buffers       0
Database pages     524287
Old database pages 193695
Modified db pages  0
Pending reads      1
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 0, not young 36985
0.00 youngs/s, 2465.50 non-youngs/s
Pages read 576950, created 160, written 177
38431.37 reads/s, 0.13 creates/s, 11.13 writes/s
Buffer pool hit rate 986 / 1000, young-making rate 0 / 1000 not 63 / 1000
Pages read ahead 0.00/s, evicted without access 3444.10/s, Random read ahead 0.00/s
LRU len: 524287, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
...
```
- Note the ``Buffer pool hit rate`` metric
- It means the buffer pool page hit rate for pages read from the buffer pool vs. from disk storage
- In the example above, ``buffer pool hit rate = 0.986``


4. When the benchmark ends, note the `TpmC` value. It is the metric for evaluating TPC-C performance.

```bash
***************************************
*** ###easy### TPC-C Load Generator ***
***************************************
option h with value '127.0.0.1'
option S (socket) with value '/tmp/mysql.sock'
option d with value 'tpcc'
option u with value 'root'
option p with value 'yourPassword'
option w with value '20'
option c with value '8'
option r with value '10'
option l with value '1200'
<Parameters>
     [server]: 127.0.0.1
     [port]: 3306
     [DBname]: tpcc
       [user]: root
       [pass]: 1234
  [warehouse]: 20
 [connection]: 8
     [rampup]: 10 (sec.)
    [measure]: 1200 (sec.)

RAMP-UP TIME.(10 sec.)

MEASURING START.

10, trx: 11204, 95%: 5.681, 99%: 6.864, max_rt: 17.443, 11206|15.114, 1121|1.739, 1120|17.696, 1120|20.223
20, trx: 11173, 95%: 5.588, 99%: 6.494, max_rt: 13.516, 11169|6.150, 1117|0.965, 1117|17.845, 1118|18.300
30, trx: 11335, 95%: 5.475, 99%: 6.095, max_rt: 10.298, 11338|8.255, 1133|0.937, 1134|16.660, 1133|17.742
...
1200, trx: 11080, 95%: 5.632, 99%: 6.517, max_rt: 10.721, 11082|8.663, 1109|2.241, 1108|18.519, 1107|18.890

STOPPING THREADS........

<Raw Results>
  [0] sc:1125874 lt:223356  rt:0  fl:0 avg_rt: 3.9 (5)
  [1] sc:1347068 lt:2142  rt:0  fl:0 avg_rt: 1.0 (5)
  [2] sc:134924 lt:0  rt:0  fl:0 avg_rt: 0.5 (5)
  [3] sc:134923 lt:0  rt:0  fl:0 avg_rt: 10.5 (80)
  [4] sc:134890 lt:32  rt:0  fl:0 avg_rt: 12.5 (20)
 in 1200 sec.

<Raw Results2(sum ver.)>
  [0] sc:1125875  lt:223356  rt:0  fl:0
  [1] sc:1347090  lt:2142  rt:0  fl:0
  [2] sc:134924  lt:0  rt:0  fl:0
  [3] sc:134923  lt:0  rt:0  fl:0
  [4] sc:134890  lt:32  rt:0  fl:0

<Constraint Check> (all must be [OK])
 [transaction percentage]
        Payment: 43.48% (>=43.0%) [OK]
   Order-Status: 4.35% (>= 4.0%) [OK]
       Delivery: 4.35% (>= 4.0%) [OK]
    Stock-Level: 4.35% (>= 4.0%) [OK]
 [response time (at least 90% passed)]
      New-Order: 83.45%  [NG] *
        Payment: 99.84%  [OK]
   Order-Status: 100.00%  [OK]
       Delivery: 100.00%  [OK]
    Stock-Level: 99.98%  [OK]

<TpmC>
                 67461.500 TpmC
```

5. After the benchmark ends, shut down the MySQL server:
   
```bash
$ ./bin/mysqladmin -uroot -pyourPassword shutdown
$ sudo killall mysqld
```

5. For the report submission, please refer to the [link](https://github.com/kyongs/mysql57-buffer-pool-experiment.md/blob/main/submission-guide.md). <br/>



## Reference
- https://www.percona.com/blog/tpcc-mysql-simple-usage-steps-and-how-to-build-graphs-with-gnuplot/
- https://github.com/Percona-Lab/tpcc-mysql
