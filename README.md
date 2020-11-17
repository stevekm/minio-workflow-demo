# minio-workflow-demo
Demo for using MinIO object store with Nextflow and CWL workflows

# Usage


```
$ make runserver
./minio server "./data"
Endpoint:  http://x.x.x.x:9000  http://192.168.x.x:9000  http://127.0.0.1:9000
AccessKey: minioadmin
SecretKey: minioadmin

Browser Access:
   http://x.x.x.x:9000  http://192.168.x.x:9000  http://127.0.0.1:9000

Command-line Access: https://docs.min.io/docs/minio-client-quickstart-guide
  $ mc alias set myminio http://x.x.x.x:9000 minioadmin minioadmin
```


# Resources

- https://docs.min.io/docs/minio-quickstart-guide.html
