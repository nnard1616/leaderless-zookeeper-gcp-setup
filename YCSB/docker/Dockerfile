FROM openjdk:11

ENV CONNECT_STRING=localhost:2181\
    RECORD_COUNT=100\
    OPERATION_COUNT=100\
    WORKLOAD_LOAD=workloadb\
    WORKLOAD_RUN=workloadb\
    SERVER_PORT=80\
    YCSB_BINDING=zookeeper-binding

RUN set -eux;\
    apt-get update;\
    DEBIAN_FRONTEND=noninteractive\
    apt-get install -y --no-install-recommends\
        git\
        python3\
        maven;

RUN git clone https://github.com/arift/YCSB.git
RUN mkdir /output
VOLUME /output
ENTRYPOINT cd /YCSB && mvn -pl site.ycsb:$YCSB_BINDING -am clean package -DskipTests; \
/YCSB/bin/ycsb load zookeeper \
-s -P /YCSB/workloads/$WORKLOAD_LOAD \
-p zookeeper.connectString=$CONNECT_STRING \
-p recordcount=$RECORD_COUNT \
-p operationcount=$OPERATION_COUNT > /output/run-cluster.load.$WORKLOAD_LOAD.$RECORD_COUNT.$OPERATION_COUNT.txt; \
for WORKLOAD in $(echo $WORKLOAD_RUN | sed "s/,/ /g"); \
do \
/YCSB/bin/ycsb run zookeeper \
-s -P /YCSB/workloads/$WORKLOAD \
-p zookeeper.connectString=$CONNECT_STRING \
-p recordcount=$RECORD_COUNT \
-p operationcount=$OPERATION_COUNT > /output/run-cluster.run.$WORKLOAD.$RECORD_COUNT.$OPERATION_COUNT.txt; \
done;\
python3 -m http.server --directory /output $SERVER_PORT;