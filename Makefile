SHELL:=/bin/bash
UNAME:=$(shell uname)
.ONESHELL:
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

Configure Minio to register all file objects in a Postgres database

Initialize a new Postgres database in this directory

make pg-init

Configure the running Minio server to send notifications to Postgres

make pg-config

Test it by running the file import recipe again and checking the number of entries; Postgres password should be 'admin'

make import-files
make pg-count
# 3


ElasticSearch (optional)
------------------------

Configure Minio to register all file objects in an ElasticSearch index

Initialize ElasticSearch in the current directory

make es-start

Configure the running Minio server to send notifications to ElasticSearch

make es-config

NOTE: if you had previously set up another notification database such as Postgres, it might need to be running for this to work

Test it by running the file import recipe again

make import-files
make es-count

Kibana
------

With ElasticSearch configured and populated, install and setup up Kibana with

make kibana

Then open your web browser to http://localhost:5601

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
MINIO_CONSOLE:=console-darwin-amd64
MC_URL:=https://dl.min.io/client/mc/release/darwin-amd64/mc
ES_GZ:=elasticsearch-7.10.1-darwin-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-darwin-x86_64.tar.gz
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-darwin-x86_64
endif

ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
MINIO_BIN_URL:=https://dl.min.io/server/minio/release/linux-amd64/minio
MINIO_CONSOLE:=console-linux-amd64
MC_URL:=https://dl.min.io/client/mc/release/linux-amd64/mc
ES_GZ:=elasticsearch-7.10.1-linux-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-linux-x86_64.tar.gz
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-linux-x86_64
endif

ES_URL:=https://artifacts.elastic.co/downloads/elasticsearch/$(ES_GZ)
KIBANA_URL:=https://artifacts.elastic.co/downloads/kibana/$(KIBANA_GZ)
MINIO_CONSOLE_URL:=https://github.com/minio/console/releases/latest/download/$(MINIO_CONSOLE)

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

# https://github.com/minio/console
$(MINIO_CONSOLE):
	wget $(MINIO_CONSOLE_URL) && chmod +x $(MINIO_CONSOLE)
console: $(MINIO_CONSOLE)
	ln -s "$(MINIO_CONSOLE)" console

install: minio mc conda console
	conda install -y \
	anaconda::postgresql=12.2 \
	conda-forge::nodejs \
	conda-forge::jq
	pip install \
	cwltool==3.0.20201203173111 \
	cwlref-runner==1.0 \
	toil[all]==5.0.0 \
	awscli==1.18.194

# interactive session with environment updated
bash:
	bash


# ~~~~~ MinIO Server Setup ~~~~~ #
MINIO_HOSTNAME:=myminio
export MINIO_BUCKET1:=bucket1
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

# add the admin user for access to the Minio Console
CONSOLE_USERNAME:=console
CONSOLE_PASSWORD:=console123
console-user:
	mc admin user add "$(MINIO_HOSTNAME)" "$(CONSOLE_USERNAME)" "$(CONSOLE_PASSWORD)"
	mc admin policy add "$(MINIO_HOSTNAME)" consoleAdmin admin.json
	mc admin policy set "$(MINIO_HOSTNAME)" consoleAdmin user="$(CONSOLE_USERNAME)"

# DO NOT USE THESE IN PRODUCTION !!
# Salt to encrypt JWT payload
export CONSOLE_PBKDF_PASSPHRASE=SECRET
# Required to encrypt JWT payload
export CONSOLE_PBKDF_SALT=SECRET
# MinIO Endpoint
export CONSOLE_MINIO_SERVER=$(MINIO_URL)
console-server:
	./console server

# import the demo files
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

# import files from an arbitrary directory
DIR:=
import-dir:
	for filepath in $$(find "$(DIR)/" -type f ! -name "*.bam"); do \
	mc cp "$$filepath" "$(MINIO_HOSTNAME)/$(MINIO_BUCKET1)/$$filepath" ; \
	done

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
CWL_OUTPUT_JSON:=$(CWL_DIR)/output.json
$(WORK_DIR):
	mkdir -p "$(WORK_DIR)"
run-cwl:
	cwltool \
	--outdir "$(CWL_OUTPUT)" \
	cwl/cp.cwl cwl/input.json

# run a bunch of CWL workflows and upload each output to the Minio server
send-cwl-output:
	for i in 1 2 3 4; do \
	cwltool \
	--outdir "$(CWL_OUTPUT)" \
	cwl/timestamp-workflow.cwl cwl/input.json > "$(CWL_OUTPUT_JSON)" && \
	./send_cwl_output.py "$(CWL_OUTPUT_JSON)"; \
	done

clean-cwl:
	rm -rf "$(CWL_OUTPUT)"
	rm -rf "$(WORK_DIR)"

# Run with Toil
run-toil: $(WORK_DIR)
	toil-cwl-runner --workDir "$(WORK_DIR)" --outdir "$(CWL_OUTPUT)" cwl/cp.cwl cwl/input.json


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
	toil-cwl-runner --workDir "$(WORK_DIR)" --outdir "$(CWL_OUTPUT)" cwl/cp.cwl cwl/input.s3.json

# "s3://toil-datasets/wdl_templates.zip"
wdl_templates.zip:
	wget http://toil-datasets.s3.amazonaws.com/wdl_templates.zip

toil-test-setup: wdl_templates.zip
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/toil-datasets"
	mc cp wdl_templates.zip "$(MINIO_HOSTNAME)/toil-datasets/wdl_templates.zip"




# ~~~~~ Simulate a Project Results Delivery ~~~~~ #
PROJECT_ID:=Project1
# bucket name must be all lowercase
PROJECT_BUCKET:=$(shell echo $(PROJECT_ID) | tr '[:upper:]' '[:lower:]')
PROJECT_USER:=client1
PROJECT_PASSWORD:=12345678
PROJECT_RESOURCE:=arn:aws:s3:::$(PROJECT_BUCKET)/*
PROJECT_POLICYNAME:=$(PROJECT_BUCKET)-read
PROJECT_POLICYFILE:=$(PROJECT_BUCKET).read.json

# NOTE: try this in the future for a real password, with Python 3.6+;
# password:
# 	python3 -c 'import secrets, string; print("".join(secrets.choice(string.ascii_letters + string.digits) for i in range(16) ) )'

# create a MinIO access policy for the user
$(PROJECT_POLICYFILE):
	jq -n --arg resource "$(PROJECT_RESOURCE)" '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:*"],"Resource":[$$resource],"Sid":"BucketAccess"}]}' > "$(PROJECT_POLICYFILE)"
project-policy: $(PROJECT_POLICYFILE)
	mc admin user add "$(MINIO_HOSTNAME)" "$(PROJECT_USER)" "$(PROJECT_PASSWORD)"
	mc admin policy add "$(MINIO_HOSTNAME)" "$(PROJECT_POLICYNAME)" "$(PROJECT_POLICYFILE)"
	mc admin policy set "$(MINIO_HOSTNAME)" "$(PROJECT_POLICYNAME)" "user=$(PROJECT_USER)"
# NOTE: its prob a better idea to do user groups & group policies in production usages

project-bucket:
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/$(PROJECT_BUCKET)" && \
	mc ilm add --expiry-days 1 "$(MINIO_HOSTNAME)/$(PROJECT_BUCKET)"

# run the pipeline and import the results to the project bucket
delivery: project-policy project-bucket
	for i in 1 2 3 4; do \
	cwltool --outdir "$(PROJECT_ID)" cwl/timestamp-workflow.cwl cwl/input.json ; \
	done ; \
	for filepath in $$(find "$(PROJECT_ID)/" -type f ); do \
	mc cp "$$filepath" "$(MINIO_HOSTNAME)/$(PROJECT_BUCKET)/$$filepath" ; \
	done ; \



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



export KIBANA_HOST:=$(MINIO_IP)
export KIBANA_PORT:=5601
export KIBANA_LOG:=kibana.log
export KIBANA_CONFIG:=$(CURDIR)/kibana.yml
$(KIBANA_HOME):
	wget "$(KIBANA_URL)" && \
	tar -xzf $(KIBANA_GZ)
kibana: $(KIBANA_HOME)
	$(KIBANA_HOME)/bin/kibana \
	-e "$(ES_URL)" \
	--port "$(KIBANA_PORT)" \
	--host "$(KIBANA_HOST)" \
	--log-file "$(KIBANA_LOG)" \
	--config "$(KIBANA_CONFIG)"


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
