SHELL:=/bin/bash
UNAME:=$(shell uname)
export PATH:=$(CURDIR):$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME

define help
Installation
------------

make install

Setup
-----

In a separate terminal session in this directory, run

make server

In this session, run

make setup

Postgres Database (optional)
----------------------------

Initialize a new Postgres database in this directory

make pg-init

Configure the running Minio server to send notifications to Postgres

make pg-config

Test it by running the file import recipe again and checking the number of entries; Postgres password should be 'admin'

make import-files
make pg-count
# 3

endef
export help
help:
	@printf "$$help"
.PHONY : help


# ~~~~~ Installation of dependencies for running MinIO, CWL workflow ~~~~~ #
# versions for Mac or Linux
ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.7.12.1-MacOSX-x86_64.sh
MINIO_BIN_URL:=https://dl.min.io/server/minio/release/darwin-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/darwin-amd64/mc
ES_GZ:=elasticsearch-7.10.1-darwin-x86_64.tar.gz
ES_URL:=https://artifacts.elastic.co/downloads/elasticsearch/$(ES_GZ)
endif

ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
MINIO_BIN_URL:=https://dl.min.io/server/minio/release/linux-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/linux-amd64/mc
ES_GZ:=elasticsearch-7.10.1-linux-x86_64.tar.gz
ES_URL:=https://artifacts.elastic.co/downloads/elasticsearch/$(ES_GZ)
endif

export ES_HOME:=$(CURDIR)/elasticsearch-7.10.1
export PATH:=$(ES_HOME)/bin:$(PATH)

CONDAURL:=https://repo.continuum.io/miniconda/$(CONDASH)
conda:
	@echo ">>> Setting up conda..."
	@wget "$(CONDAURL)" && \
	bash "$(CONDASH)" -b -p conda && \
	rm -f "$(CONDASH)"

minio:
	wget "$(MINIO_BIN_URL)" && \
	chmod +x minio

mc:
	wget "$(MC_URL)" && \
	chmod +x mc

install: minio mc conda
	conda install -y anaconda::postgresql=12.2
	pip install \
	cwltool==3.0.20201203173111 \
	cwlref-runner==1.0 \
	toil[all]==5.0.0 \
	awscli==1.18.194

# ~~~~~ MinIO Server Setup ~~~~~ #
MINIO_HOSTNAME:=myminio
MINIO_BUCKET1:=bucket1
MINIO_BUCKET2:=bucket2
MINIO_USER:=user1
MINIO_USER_PASSWORD:=password1234
MINIO_GROUP:=group1
MINIO_POLICYFILE:=bucket-readwrite.json
MINIO_POLICYNAME:=bucket-access
export MINIO_PORT:=9010
export MINIO_IP:=127.0.0.1
export MINIO_ADDRESS:=$(MINIO_IP):$(MINIO_PORT)
export MINIO_URL:=http://$(MINIO_ADDRESS)
export MINIO_ACCESS_KEY:=minioadmin
export MINIO_SECRET_KEY:=minioadmin
# set the mc alias for the minio server
alias:
	mc alias set "$(MINIO_HOSTNAME)" "$(MINIO_URL)" "$(MINIO_ACCESS_KEY)" "$(MINIO_SECRET_KEY)"

# set up two buckets
bucket:
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/$(MINIO_BUCKET2)"

# make one bucket public for http access
policy:
	mc policy set public "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"

# add users and groups and give them access to bucket2
user-groups:
	mc admin user add "$(MINIO_HOSTNAME)" "$(MINIO_USER)" "$(MINIO_USER_PASSWORD)"
	mc admin group add "$(MINIO_HOSTNAME)" "$(MINIO_GROUP)" "$(MINIO_USER)"
	mc admin policy add "$(MINIO_HOSTNAME)" "$(MINIO_POLICYNAME)" "$(MINIO_POLICYFILE)"
	mc admin policy set "$(MINIO_HOSTNAME)" "$(MINIO_POLICYNAME)" "group=$(MINIO_GROUP)"
	mc admin group info "$(MINIO_HOSTNAME)" "$(MINIO_GROUP)"

FILES_DIR:=files
import-files:
	for filepath in $$(find $(FILES_DIR) -type f -name '*.txt'); do \
	sample=$$(grep 'sample' $$filepath | cut -f2); \
	project=$$(grep 'project' $$filepath | cut -f2); \
	run=$$(grep 'run' $$filepath | cut -f2); \
	mc cp \
	--attr "sample=$$sample;project=$$project;run=$$run" \
	"$$filepath" "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)/$$filepath" ; \
	mc cp \
	--attr "sample=$$sample;project=$$project;run=$$run" \
	"$$filepath" "$(MINIO_HOSTNAME)/$(MINIO_BUCKET2)/$$filepath" ; \
	done

setup: alias bucket user-groups policy import-files


# example usages
list-files:
	mc ls --recursive "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"

stat-files:
	mc stat --recursive "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"

remove-files:
	mc rm --recursive --force "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"

# create an archived file, import it, then pass its contents to gunzip
gunzip:
	[ -f foo.txt.gz ] && rm -f foo.txt.gz || :
	echo "this will be archived" > foo.txt
	gzip foo.txt
	mc cp foo.txt.gz "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)"/foo.txt.gz
	mc cat "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)/foo.txt.gz" | gunzip

# stream the file object contents to a local program
paste:
	paste \
	<(mc cat $(MINIO_HOSTNAME)/$(MINIO_BUCKET1)/files/Run1/Project_1/Sample_ABC/ABC.txt) \
	<(mc cat $(MINIO_HOSTNAME)/$(MINIO_BUCKET1)/files/Run3/Project_3/Sample_GHI/GHI.txt)

# run the example boto scripts to access files
export BOTO3_ENDPOINT_URL:=$(MINIO_URL)
export AWS_ACCESS_KEY_ID:=$(MINIO_USER)
export AWS_SECRET_ACCESS_KEY:=$(MINIO_USER_PASSWORD)
export BOTO_HOST:=$(MINIO_IP)
export BOTO_PORT:=$(MINIO_PORT)
export BOTO_SECURE:=False
boto-script:
	python3 get_file.py


# get MinIO server contents from S3-compatible AWS CLI
awscli:
	aws s3 ls "$(MINIO_BUCKET1)" --endpoint-url "$(BOTO3_ENDPOINT_URL)"



# ~~~~~ Start the MinIO server; run this in a separate terminal session ~~~~~ #
SERVER_DIR:=./data
server:
	minio server --address "$(MINIO_ADDRESS)" "$(SERVER_DIR)"

server2:
	minio server --address "$(MINIO_ADDRESS)" "$(SERVER_DIR){1...4}"

# ~~~~~ Run the CWL workflow ~~~~~ #
CWL_DIR:=$(CURDIR)/cwl
WORK_DIR:=$(CWL_DIR)/work
CWL_OUTPUT:=$(CWL_DIR)/output
$(WORK_DIR):
	mkdir -p "$(WORK_DIR)"
run-cwl:
	cwltool \
	--outdir "$(CWL_OUTPUT)" \
	cwl/job.cwl cwl/input.json

clean-cwl:
	rm -rf "$(CWL_OUTPUT)"
	rm -rf "$(WORK_DIR)"

# Run with Toil
run-toil: $(WORK_DIR)
	toil-cwl-runner --workDir "$(WORK_DIR)" --outdir "$(CWL_OUTPUT)" cwl/job.cwl cwl/input.json


# NOTE: Need to run `aws configure` first to set access key and secret key configs in ~/.aws
# $ cat ~/.aws/credentials
# [default]
# aws_access_key_id = user1
# aws_secret_access_key = password1234
# $ aws s3 ls bucket1 --endpoint-url http://127.0.0.1:9010
# TODO: update this for toil with new configs from this PR; https://github.com/DataBiosphere/toil/pull/3370
export BOTO3_ENDPOINT_URL:=$(MINIO_URL)
export AWS_ACCESS_KEY_ID:=$(MINIO_USER)
export AWS_SECRET_ACCESS_KEY:=$(MINIO_USER_PASSWORD)
run-toil-s3: $(WORK_DIR)
	toil-cwl-runner --workDir "$(WORK_DIR)" --outdir "$(CWL_OUTPUT)" cwl/job.cwl cwl/input.s3.json

# "s3://toil-datasets/wdl_templates.zip"
wdl_templates.zip:
	wget http://toil-datasets.s3.amazonaws.com/wdl_templates.zip

toil-test-setup: wdl_templates.zip
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/toil-datasets"
	mc cp wdl_templates.zip "$(MINIO_HOSTNAME)/toil-datasets/wdl_templates.zip"


# interactive session with environment updated
bash:
	bash



# ~~~~~ ElasticSearch setup ~~~~~ #
# https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-system-settings.html
export ES_PORT:=9200
export ES_HOST:=$(MINIO_IP)
export ES_URL:=http://$(ES_HOST):$(ES_PORT)
export ES_PIDFILE:=$(CURDIR)/es_pid
export ES_DATA:=$(CURDIR)/es_data
export ES_LOGS:=$(CURDIR)/es_logs
export ES_INDEX:=minio_events
$(ES_HOME):
	wget "$(ES_URL)" && \
	tar -xzf $(ES_GZ)
$(ES_DATA):
	mkdir -p "$(ES_DATA)"
$(ES_LOGS):
	mkdir -p "$(ES_LOGS)"

# ElasticSearch download, installation, and dir setup
es: $(ES_HOME) $(ES_DATA) $(ES_LOGS)

# start the ElasticSearch server in daemon mode
es-start: es
	$(ES_HOME)/bin/elasticsearch \
	-E "path.data=$(ES_DATA)" \
	-E "path.logs=$(ES_LOGS)" \
	-d -p "$(ES_PIDFILE)"

# stop ElasticSearch daemon
es-stop:
	pkill -F "$(ES_PIDFILE)"

# check if ElasticSearch is running
es-check:
	curl -X GET "$(ES_URL)/?pretty"

# get the entries in the ElasticSearch index
es-count:
	curl  "$(ES_URL)/$(ES_INDEX)/_search?pretty=true"

# configure the Minio server to use ElasticSearch
es-config:
	mc admin config set "$(MINIO_HOSTNAME)" notify_elasticsearch:1 url="$(ES_URL)" format="namespace" index="$(ES_INDEX)"
	mc admin service restart "$(MINIO_HOSTNAME)"
	mc event add "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)" arn:minio:sqs::1:elasticsearch

# ~~~~~ Postgres Setup ~~~~~ #
# https://docs.min.io/docs/minio-bucket-notification-guide.html
USERNAME:=$(shell whoami)
# data dir for db
export PGDATA:=$(CURDIR)/pg_db
# name for db
export PGDATABASE=minio_db
# if PGUSER is not current username then need to initialize pg server user separately
export PGUSER=$(USERNAME)
export PGHOST=$(MINIO_IP)
export PGLOG=postgres.log
# export PGPASSWORD=admin
export PGPORT=9011
export PG_MINIO_TABLE:=bucketevents
export connection_string:=host=$(PGHOST) port=$(PGPORT) user=$(PGUSER) password=$(PGPASSWORD) database=$(PGDATABASE) sslmode=disable

# directory to hold the Postgres database files
$(PGDATA):
	mkdir -p "$(PGDATA)"

# set up & start the Postgres db server instance
pg-init: $(PGDATA)
	set -x && \
	pg_ctl -D "$(PGDATA)" initdb && \
	pg_ctl -D "$(PGDATA)" -l "$(PGLOG)" start && \
	createdb

# setup the Minio server to send notifications to postgres
pg-config:
	mc admin config set "$(MINIO_HOSTNAME)" notify_postgres:1 connection_string="$(connection_string)" table="$(PG_MINIO_TABLE)" format="namespace"
	mc admin service restart "$(MINIO_HOSTNAME)"
	mc event add "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)" arn:minio:sqs::1:postgresql

# start the Postgres database server process
pg-start: $(PGDATA)
	pg_ctl -D "$(PGDATA)" -l "$(PGLOG)" start

# stop the db server
pg-stop:
	pg_ctl -D "$(PGDATA)" stop

# check if db server is running
pg-check:
	pg_ctl status

# interactive Postgres console
# use command `\dt` to show all tables
pg-inter:
	psql -p "$(PGPORT)" -U "$(PGUSER)" -W "$(PGDATABASE)"

pg-count:
	echo "SELECT COUNT(*) FROM $(PG_MINIO_TABLE)" | psql -p "$(PGPORT)" -U "$(PGUSER)" -W "$(PGDATABASE)" -At
