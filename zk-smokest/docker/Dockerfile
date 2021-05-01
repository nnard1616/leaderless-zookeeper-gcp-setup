FROM ubuntu:20.04

ENV CONNECT_STRING=localhost:2181 \
Z_NODE_COUNT=100 \
Z_NODE_SIZE=100 \
SERVER_PORT=80

RUN set -eux; \
apt-get update; \
DEBIAN_FRONTEND=noninteractive \
apt-get install -y --no-install-recommends \
python-dev \
libzookeeper-mt-dev \
python2 \
python3 \
curl \
ca-certificates \
git \
gcc;

RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py --output get-pip.py
RUN python2 get-pip.py;
RUN pip2 install zkpython;

RUN git clone https://github.com/phunt/zk-smoketest.git
RUN mkdir /output
VOLUME /output
ENTRYPOINT python2 /zk-smoketest/zk-latencies.py \
--servers $CONNECT_STRING \
--znode_count=$Z_NODE_COUNT \
--znode_size=$Z_NODE_SIZE \
--synchronous \
--verbose >  /output/output.txt; \
python3 -m http.server --directory /output $SERVER_PORT;