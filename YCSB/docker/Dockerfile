FROM openjdk:11

ENV RUN_TYPE=load\
    CONNECT_STRING=localhost:2181\
    RECORD_COUNT=100\
    OPERATION_COUNT=100\
    WORLOAD=workloadb\
    SERVER_PORT=80

RUN set -eux;\
    apt-get update;\
    DEBIAN_FRONTEND=noninteractive\
    apt-get install -y --no-install-recommends\
        git\
        python3\
        maven;

RUN git clone https://github.com/arift/YCSB.git
WORKDIR /YCSB
RUN mvn -pl site.ycsb:zookeeper-binding -am clean package -DskipTests
RUN mkdir /output
VOLUME /output
ENTRYPOINT export OUTPUT_FILE_NAME=run-cluster.$RUN_TYPE.$WORLOAD.$RECORD_COUNT.$OPERATION_COUNT.txt; \
/YCSB/bin/ycsb $RUN_TYPE zookeeper \
-s -P /YCSB/workloads/$WORLOAD \
-p zookeeper.connectString=$CONNECT_STRING \
-p recordcount=$RECORD_COUNT \
-p operationcount=$OPERATION_COUNT > /output/$OUTPUT_FILE_NAME; \
python3 -m http.server --directory /output $SERVER_PORT;