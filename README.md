# minio-workflow-demo

Demo for using [MinIO](https://min.io/) object store with Nextflow and CWL workflows.

This demo shows how to import files from the filesystem into MinIO with custom metadata, then use those files as inputs in CWL and Nextflow workflows.

The included `Makefile` contains the commands used in the demonstration, along with the system environment configurations needed to run them more easily. See the `Makefile` contents for the exact commands being used at each step.

# Usage

## Installation

For convenience, download recipe for MinIO binaries and setup of a local `conda` instance for running CWL workflow has been included. It can be downloaded with

```
make install
```

## Server

In a separate terminal session, start the MinIO server and leave it running with;

```
make server
```

You will see a message in your console that looks like this;

```
Endpoint:  http://127.0.0.1:9010
AccessKey: minioadmin
SecretKey: minioadmin

Browser Access:
   http://127.0.0.1:9010
```

For demonstration purposes, we will use the default access keys and URL's provided.

In a new terminal session in the same directory, run the MinIO server setup steps with

```
make setup
```

This will

- add an alias for the `mc` MinIO client to use this default server as `myminio` (credentials stored under `~/.mc`)

- create new buckets on the server labeled `bucket1` and `bucket2`

- create user `user1` and user group `group1` on the MinIO server

- set the bucket access policies for `bucket1` and `bucket2` to be accessible by `user1`

- import a number of dummy files provided in the `files` directory of this repo, each with custom metadata tags defined in the file contents

## Files

You can see the files we have imported with `make list-files`

```
[2020-11-17 12:11:07 EST]    45B files/Run1/Project_1/Sample_ABC/ABC.txt
[2020-11-17 12:11:07 EST]    45B files/Run2/Project_2/Sample_DEF/DEF.txt
[2020-11-17 12:11:07 EST]    45B files/Run3/Project_3/Sample_GHI/GHI.txt
```

You can see the custom metadata we have attached to each file with `make stat-files`

```
Name      : bucket1/files/Run1/Project_1/Sample_ABC/ABC.txt
Date      : 2020-11-17 12:01:51 EST
Size      : 45 B
ETag      : fb8118ab2f94aa0cf29ff4e473c73dc2
Type      : file
Metadata  :
  X-Amz-Meta-Sample  : Sample_ABC
  Content-Type       : text/plain
  X-Amz-Meta-Mc-Attrs: atime:1605632511#918418000/gid:6119/mode:33188/mtime:1605632511#918529000/uid:1759/uname:kellys5
  X-Amz-Meta-Project : Project_1
  X-Amz-Meta-Run     : Run1

Name      : bucket1/files/Run2/Project_2/Sample_DEF/DEF.txt
Date      : 2020-11-17 12:01:51 EST
Size      : 45 B
ETag      : 90881119d46dd43b59973948dc9accf6
Type      : file
Metadata  :
  Content-Type       : text/plain
  X-Amz-Meta-Project : Project_2
  X-Amz-Meta-Sample  : Sample_DEF
  X-Amz-Meta-Mc-Attrs: atime:1605632511#920117000/gid:6119/mode:33188/mtime:1605632511#920219000/uid:1759/uname:kellys5
  X-Amz-Meta-Run     : Run2

Name      : bucket1/files/Run3/Project_3/Sample_GHI/GHI.txt
Date      : 2020-11-17 12:01:51 EST
Size      : 45 B
ETag      : 2690432dbb218842a18e19be5df06892
Type      : file
Metadata  :
  X-Amz-Meta-Mc-Attrs: atime:1605632511#921162000/gid:6119/mode:33188/mtime:1605632511#921255000/uid:1759/uname:kellys5
  X-Amz-Meta-Run     : Run3
  X-Amz-Meta-Project : Project_3
  X-Amz-Meta-Sample  : Sample_GHI
  Content-Type       : text/plain
```

Notably, you can see the custom metadata we have attached to each file under the keys `X-Amz-Meta-Run`, `X-Amz-Meta-Project`, and `X-Amz-Meta-Sample`.

# Workflows

## CWL

The included CWL workflow can be run from this directory with the recipe

```
make run-cwl
```

This workflow simply copies a file defined in `cwl/input.json` to the output location `cwl/output`. Notably, the file defined as input is a URL pointing to the file object stored in the MinIO server (`http://127.0.0.1:9010/bucket1/files/Run1/Project_1/Sample_ABC/ABC.txt`).

If it ran succesfully, you will be able to see the copied file at that location;

```
$ cat cwl/output/ABC.copy.txt
sample  Sample_ABC
project Project_1
run     Run1
```

## Nextflow

The setup recipe for the Nextflow workflow is stored in the `nextflow` directory in this repo, so first `cd` to there

```
cd nextflow
```

Install the Nextflow executable in the local dir; note that Java should be loaded for this.

```
make install
```

Run the Nextflow workflow with

```
make run
```

As with the CWL workflow, this demo Nextflow workflow simply copies the file objects specified by URL on the MinIO server to the output directory `output`. If the workflow ran successfully, you should be able to see them at that location;

```
$ ls output/
ABC.txt.copy.txt  DEF.txt.copy.txt  GHI.txt.copy.txt
```

And view their contents

```
$ cat output/ABC.txt.copy.txt
sample  Sample_ABC
project Project_1
run     Run1
```

# Extras

Examples usages of files stored in MinIO;

- pipe file object contents to local program via stdin

```
make gunzip
```

- use shell redirection to stream contents of multiple file objects to local program

```
make paste
```

- access the contents of the object store via the `boto` and `boto3` Python libraries

```
make boto-script
```

- access the contents of the MinIO object store via the S3-compatible AWS CLI

```
make awscli
```

# Bucket Notifications

MinIO can be configured to push notifications of bucket events to a database.

## Postgres Integration

Configure Minio to register all file objects in a Postgres SQL database.

Initialize a new Postgres database in this directory:

```
make pg-init
```

Configure the running Minio server to send notifications to Postgres:

```
make pg-config
```

Test it by running the file import recipe again and checking the number of entries; Postgres password should be 'admin'

```
make import-files
make pg-count
```

There should be 3 files now.

## ElasticSearch + Kibana dashboard

Similar to Postgres integration, Minio can also be configured to register listings of all objects in [ElasticSearch](https://www.elastic.co/elasticsearch/), which can be used with [Kibana](https://www.elastic.co/guide/en/kibana/current/get-started.html) dashboards.

Initialize ElasticSearch in the current directory:

```
make es-start
```

Configure the running Minio server to send notifications to ElasticSearch:

```
make es-config
```

NOTE: if you had previously set up another notification database such as Postgres, it might need to be running for this to work

Test it by running the file import recipe again:

```
make import-files
make es-count
```

With ElasticSearch configured and populated, install and setup up Kibana with

```
make kibana
```

Then open your web browser to http://localhost:5601 and set up data import and dashboards to view file events.

## With CWL pipeline updates

With the database integrations described above, we can run a CWL pipeline with input files from the MinIO object store, and then use a simple script to upload pipeline outputs back into the object store for registration in our database (Postgres, ElasticSearch, etc.). An example of this can be run with:

```
make send-cwl-output
```

This recipe will run a CWL workflow several times, capturing each result with the `send_cwl_output.py` script and pushing the files into the MinIO bucket.

# Pipeline Results Delivery

In real-life contexts, it is common to send a copy of your analysis workflow results to a client or collaborator. To simulate running a workflow for a collaborator and preparing a delivery of their results, use the recipe:

```
make delivery
```

In this case, the CWL workflow is run with an output directory of `Project1`. A new bucket on our MinIO server called `project1` is prepared, and upon completion of the CWL workflow, all output files are imported to this bucket. A new MinIO server user account `client1` is created with a default password of `12345678`, and read-only access is applied to bucket `project1` for this user. Additionally, the bucket is given a lifecycle of 1 day for demonstration purposes, so the files in the bucket will automatically delete after 1 day on the server.

Using the MinIO web dashboard, the client can now download their files by navigating to `http://localhost:9010` in their web browser, and logging in with the username and password created for their user account.

![screenshot](https://github.com/stevekm/minio-workflow-demo/blob/main/images/Screen%20Shot%202021-01-08%20at%2010.27.00%20AM.png)

# Resources & Links

MinIO repo

- https://github.com/minio/minio

Official docs for MinIO server and client

- https://docs.min.io/docs/minio-quickstart-guide.html

- https://docs.min.io/docs/minio-client-quickstart-guide.html

MinIO Bucket Notifications configuration guide

- https://docs.min.io/docs/minio-bucket-notification-guide.html

MinIO Bucket Lifecycles

- https://docs.min.io/docs/minio-bucket-lifecycle-guide.html

Usage of AWS S3 protocol with Nextflow

- https://www.nextflow.io/docs/latest/amazons3.html

MinIO iRODS Gateway

- https://github.com/bioteam/minio-irods-gateway

- https://bioteam.net/2018/07/exposing-your-irods-zone-as-aws-s3-object-storage/

- https://github.com/s3fs-fuse/s3fs-fuse
