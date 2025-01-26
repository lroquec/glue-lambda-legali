import boto3

def handler(event, context):
    glue = boto3.client('glue')
    glue.start_crawler(Name='connection-logs-crawler')
    return {
        'statusCode': 200,
        'body': 'Started crawler'
    }