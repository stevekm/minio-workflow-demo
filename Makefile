SHELL:=/bin/bash
UNAME:=$(shell uname)
export PATH:=$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME

# ~~~~~ Installation of dependencies for running MinIO, CWL workflow ~~~~~ #
# versions for Mac or Linux
ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.7.12.1-MacOSX-x86_64.sh
MINIO_URL:=https://dl.min.io/server/minio/release/darwin-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/darwin-amd64/mc
endif

ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
MINIO_URL:=https://dl.min.io/server/minio/release/linux-amd64/minio
MC_URL:=https://dl.min.io/client/mc/release/linux-amd64/mc
endif

CONDAURL:=https://repo.continuum.io/miniconda/$(CONDASH)
conda:
	@echo ">>> Setting up conda..."
	@wget "$(CONDAURL)" && \
	bash "$(CONDASH)" -b -p conda && \
	rm -f "$(CONDASH)"

minio:
	wget "$(MINIO_URL)" && \
	chmod +x minio

mc:
	wget "$(MC_URL)" && \
	chmod +x mc

install: minio conda
	pip install \
	cwltool==2.0.20200126090152 \
	cwlref-runner==1.0



# ~~~~~ MinIO Server Setup ~~~~~ #
MINIO_HOSTNAME:=myminio
MINIO_BUCKET:=bucket1

alias:
	./mc alias set "$(MINIO_HOSTNAME)" http://127.0.0.1:9000 minioadmin minioadmin

bucket:
	./mc mb "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)"

policy:
	./mc policy set public "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)"

FILES_DIR:=files
import-files:
	for filepath in $$(find $(FILES_DIR) -type f -name '*.txt'); do \
	sample=$$(grep 'sample' $$filepath | cut -f2); \
	project=$$(grep 'project' $$filepath | cut -f2); \
	run=$$(grep 'run' $$filepath | cut -f2); \
	./mc cp \
	--attr "sample=$$sample;project=$$project;run=$$run" \
	"$$filepath" "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)/$$filepath" ; \
	done

list-files:
	./mc ls --recursive "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)"

stat-files:
	./mc stat --recursive "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)"

remove-files:
	./mc rm --recursive --force "$(MINIO_HOSTNAME)/$(MINIO_BUCKET)"

setup: alias bucket import-files policy



# ~~~~~ Start the MinIO server; run this in a separate terminal session ~~~~~ #
SERVER_DIR:=./data
runserver:
	./minio server "$(SERVER_DIR)"



# ~~~~~ Run the CWL workflow ~~~~~ #
run-cwl:
	cwltool \
	--outdir cwl/output \
	cwl/job.cwl cwl/input.json

clean-cwl:
	rm -rf cwl/output


# interactive session with environment updated
bash:
	bash
