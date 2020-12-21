#!/usr/bin/env python3
"""
Send CWL output saved in JSON file to Minio server
"""
import os
import sys
import json
import boto3

endpoint_url = os.environ.get('BOTO3_ENDPOINT_URL', 'http://127.0.0.1:9010')
aws_access_key_id = os.environ.get('AWS_ACCESS_KEY_ID', 'minioadmin')
aws_secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY', 'minioadmin')
bucket = os.environ.get('MINIO_BUCKET1', 'bucket1')

args = sys.argv[1:]
input_json = args[0]
with open(input_json) as f:
    input_data = json.load(f)

s3 = boto3.resource('s3', endpoint_url = endpoint_url, aws_access_key_id = aws_access_key_id, aws_secret_access_key = aws_secret_access_key)

for key in input_data.keys():
    entry = input_data[key]
    if entry['class'] == 'File':
        path = entry['path']
        basename = entry['basename']
        print(">>> uploading file {} to bucket {} as {}".format(path, bucket, basename))
        s3.meta.client.upload_file(path, bucket, basename)
