#!/usr/bin/env python3
"""
Example for listing the files in the buckets

https://boto3.amazonaws.com/v1/documentation/api/latest/reference/core/boto3.html
https://boto3.amazonaws.com/v1/documentation/api/latest/reference/core/session.html#boto3.session.Session.client
"""
import os
import boto3

endpoint_url = os.environ.get('BOTO3_ENDPOINT_URL', 'http://127.0.0.1:9010')
aws_access_key_id = os.environ.get('AWS_ACCESS_KEY_ID', 'minioadmin')
aws_secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY', 'minioadmin')

s3 = boto3.resource('s3', endpoint_url = endpoint_url, aws_access_key_id = aws_access_key_id, aws_secret_access_key = aws_secret_access_key)

for bucket in s3.buckets.all():
    for item in bucket.objects.all():
        print(bucket.name, item.key)
