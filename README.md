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
make runserver
```

You will see a message in your console that looks like this;

```
Endpoint:  http://x.x.x.x:9000  http://192.168.x.x:9000  http://127.0.0.1:9000
AccessKey: minioadmin
SecretKey: minioadmin

Browser Access:
   http://x.x.x.x:9000  http://192.168.x.x:9000  http://127.0.0.1:9000

Command-line Access: https://docs.min.io/docs/minio-client-quickstart-guide
  $ mc alias set myminio http://x.x.x.x:9000 minioadmin minioadmin
```

For demonstration purposes, we will use the default access keys and URL's provided.

In a new terminal session in the same directory, run the MinIO server setup steps with

```
make setup
```

This will

- add an alias for the `mc` MinIO client to use this default server as `myminio` (credentials stored under `~/.mc`)

- create a new bucket on the server labeled `bucket1`

- set the bucket for public access so our workflows can use the files more easily

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

This workflow simply copies a file defined in `cwl/input.json` to the output location `cwl/output`. Notably, the file defined as input is a URL pointing to the file object stored in the MinIO server (`http://127.0.0.1:9000/bucket1/files/Run1/Project_1/Sample_ABC/ABC.txt`).

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

# Resources & Links

MinIO repo

- https://github.com/minio/minio

Official docs for MinIO server and client

- https://docs.min.io/docs/minio-quickstart-guide.html

- https://docs.min.io/docs/minio-client-quickstart-guide.html

Usage of AWS S3 protocol with Nextflow

- https://www.nextflow.io/docs/latest/amazons3.html

MinIO iRODS Gateway

- https://github.com/bioteam/minio-irods-gateway

- https://bioteam.net/2018/07/exposing-your-irods-zone-as-aws-s3-object-storage/
