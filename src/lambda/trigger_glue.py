import os
import boto3
import logging
from urllib.parse import unquote_plus
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    glue = boto3.client('glue')
    
    try:
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing file: {key} from bucket: {bucket}")
            
            response = glue.start_job_run(
                JobName=os.environ['GLUE_JOB_NAME'],
                Arguments={
                    '--bucket': bucket,
                    '--input_file': key
                }
            )
            
            logger.info(f"Started Glue job: {response['JobRunId']}")
            
            return {
                'statusCode': 200,
                'body': f"Started Glue job: {response['JobRunId']}"
            }
            
    except ClientError as e:
        logger.error(f"Error starting Glue job: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        raise