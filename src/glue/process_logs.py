import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
import tarfile
import boto3
import io

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'bucket', 'input_file'])

def process_record_line(line):
   try:
       fields = line.strip().split(',')
       
       # For connection lines (New/Destroy)
       if len(fields) > 4 and fields[1] in ['New', 'Destroy']:
           timestamp = fields[4]
           return {
               'type': fields[1],
               'source_ip': fields[2],
               'dest_ip': fields[3],
               'timestamp': timestamp,
               'year': timestamp.split('-')[0],
               'month': timestamp.split('-')[1],
               'day': timestamp.split('-')[2].split(' ')[0],
               'source_port': fields[5] if len(fields) > 5 else None,
               'dest_port': fields[6] if len(fields) > 6 else None,
               'protocol': fields[7] if len(fields) > 7 else None,
               'nat_ip': fields[8] if len(fields) > 8 else None
           }
       
       # For SESSION-TERMINATED lines
       elif 'SESSION-TERMINATED' in line:
           timestamp = fields[0].strip('"')
           return {
               'type': 'SESSION',
               'timestamp': timestamp,
               'year': timestamp.split('-')[0],
               'month': timestamp.split('-')[1],
               'day': timestamp.split('-')[2].split(' ')[0],
               'private_ip': fields[26].strip('"'),
               'mac_address': fields[28].strip('"'),
               'username': fields[3].strip('"'),
               'location': fields[25].strip('"'),
               'email': fields[8].strip('"')
           }
   except Exception as e:
       print(f"Error processing line: {line}")
       print(f"Error: {str(e)}")
       return None
   return None

def process_tar_file(bucket, key):
   s3 = boto3.client('s3')
   response = s3.get_object(Bucket=bucket, Key=key)
   
   with tarfile.open(fileobj=io.BytesIO(response['Body'].read())) as tar:
       for member in tar.getmembers():
           if member.name.endswith('.record'):
               f = tar.extractfile(member)
               if f is not None:
                   records = []
                   for line in f:
                       record = process_record_line(line.decode('utf-8'))
                       if record:
                           records.append(record)
                   
                   if records:
                       df = spark.createDataFrame(records)
                       # Escribir con particiones
                       df.write.partitionBy('year', 'month', 'day', 'type').mode('append').parquet(
                           f's3://{bucket}/parquet/'
                       )

job.init(args['JOB_NAME'], args)
process_tar_file(args['bucket'], args['input_file'])
job.commit()