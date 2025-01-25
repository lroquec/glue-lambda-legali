import os
import boto3
from urllib.parse import unquote_plus

def handler(event, context):
    glue = boto3.client('glue')
    
    # Get bucket and key from event
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        # Start Glue job
        response = glue.start_job_run(
            JobName=os.environ['GLUE_JOB_NAME'],
            Arguments={
                '--bucket': bucket,
                '--input_file': key
            }
        )
        
        return {
            'statusCode': 200,
            'body': f"Started Glue job: {response['JobRunId']}"
        }