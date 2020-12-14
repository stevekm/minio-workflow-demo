#!/usr/bin/env python3
"""
Example for listing the files in the buckets

https://boto3.amazonaws.com/v1/documentation/api/latest/reference/core/boto3.html
https://boto3.amazonaws.com/v1/documentation/api/latest/reference/core/session.html#boto3.session.Session.client
"""
import os
import boto
import boto.s3.connection
import boto3

endpoint_url = os.environ.get('BOTO3_ENDPOINT_URL', 'http://127.0.0.1:9010')
aws_access_key_id = os.environ.get('AWS_ACCESS_KEY_ID', 'minioadmin')
aws_secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY', 'minioadmin')

print(">>> endpoint_url: ", endpoint_url)
# print(">>> aws_access_key_id: ", aws_access_key_id)
# print(">>> aws_secret_access_key: ", aws_secret_access_key)

print(">>> getting files with boto3")
s3 = boto3.resource('s3', endpoint_url = endpoint_url, aws_access_key_id = aws_access_key_id, aws_secret_access_key = aws_secret_access_key)

for bucket in s3.buckets.all():
    for item in bucket.objects.all():
        print(bucket.name, item.key)


# https://boto3.amazonaws.com/v1/documentation/api/latest/guide/migrations3.html
# https://docs.ceph.com/en/latest/radosgw/s3/python/
# https://github.com/minio/minio/issues/5422
# https://github.com/minio/minio/issues/1025
host = os.environ.get('BOTO_HOST', '127.0.0.1')
port = os.environ.get('BOTO_PORT', '9010')
_is_secure = os.environ.get('BOTO_SECURE', 'False')
is_secure = True
if _is_secure == 'False':
    is_secure = False
print(">>> getting files with boto")
print('>>> host: ', host)
print('>>> port: ', port)
print('>>> is_secure: ', is_secure)

s3 = boto.connect_s3(
    aws_access_key_id = aws_access_key_id,
    aws_secret_access_key = aws_secret_access_key,
    host = host,
    port = int(port),
    is_secure=is_secure, # if you are using ssl or not
    calling_format = boto.s3.connection.OrdinaryCallingFormat()
    )

for bucket in s3.get_all_buckets():
    for item in bucket.list():
        print(bucket.name, item.key)
