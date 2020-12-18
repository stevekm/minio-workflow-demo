SHELL:=/bin/bash
UNAME:=$(shell uname)
export PATH:=$(CURDIR):$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME

# ~~~~~ Installation of dependencies for running MinIO, CWL workflow ~~~~~ #
# versions for Mac or Linux
ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.7.12.1-MacOSX-x86_64.sh
MINIO_BIN_URL:=https://dl.min.io/server/minio/release/darwin-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/darwin-amd64/mc
endif

ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
MINIO_BIN_URL:=https://dl.min.io/server/minio/release/linux-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/linux-amd64/mc
endif

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


# "s3://toil-datasets/wdl_templates.zip"
wdl_templates.zip:
	wget http://toil-datasets.s3.amazonaws.com/wdl_templates.zip

toil-test-setup: wdl_templates.zip
	mc mb --ignore-existing "$(MINIO_HOSTNAME)/toil-datasets"
	mc cp wdl_templates.zip "$(MINIO_HOSTNAME)/toil-datasets/wdl_templates.zip"


# NOTE: Need to run `aws configure` first to set access key and secret key configs in ~/.aws
# $ cat ~/.aws/credentials
# [default]
# aws_access_key_id = user1
# aws_secret_access_key = password1234
# $ aws s3 ls bucket1 --endpoint-url http://127.0.0.1:9010
export BOTO3_ENDPOINT_URL:=$(MINIO_URL)
export AWS_ACCESS_KEY_ID:=$(MINIO_USER)
export AWS_SECRET_ACCESS_KEY:=$(MINIO_USER_PASSWORD)
run-toil-s3: $(WORK_DIR)
	toil-cwl-runner --workDir "$(WORK_DIR)" --outdir "$(CWL_OUTPUT)" cwl/job.cwl cwl/input.s3.json

# interactive session with environment updated
bash:
	bash
