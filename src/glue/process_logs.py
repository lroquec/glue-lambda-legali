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

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'bucket', 'input_file'])

def process_record_line(line):
    """Process a single line from record file"""
    fields = line.strip().split(',')
    if len(fields) < 5:  # Skip invalid lines
        return None
        
    if fields[1] == 'New' or fields[1] == 'Destroy':
        return {
            'type': fields[1],
            'source_ip': fields[2],
            'dest_ip': fields[3],
            'timestamp': fields[4],
            'source_port': fields[5] if len(fields) > 5 else None,
            'dest_port': fields[6] if len(fields) > 6 else None,
            'protocol': fields[7] if len(fields) > 7 else None,
            'nat_ip': fields[8] if len(fields) > 8 else None
        }
    elif 'SESSION-TERMINATED' in line:
        # Extract session termination fields
        # Adjust indices based on your actual format
        return {
            'type': 'SESSION',
            'timestamp': fields[0],
            'private_ip': fields[-3],
            'mac_address': fields[-4],
            'email': fields[8] if len(fields) > 8 else None
        }
    return None

def process_tar_file(bucket, key):
    """Process tar.gz file and convert to parquet"""
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket, Key=key)
    
    # Create temporary directory for extracted files
    with tarfile.open(fileobj=io.BytesIO(response['Body'].read())) as tar:
        for member in tar.getmembers():
            if member.name.endswith('.record'):
                f = tar.extractfile(member)
                if f is not None:
                    # Process records and create DataFrame
                    records = []
                    for line in f:
                        record = process_record_line(line.decode('utf-8'))
                        if record:
                            records.append(record)
                    
                    if records:
                        df = spark.createDataFrame(records)
                        # Write to parquet with partitioning
                        df.write.partitionBy('type').mode('append').parquet(
                            f's3://{bucket}/parquet/'
                        )

# Main job execution
job.init(args['JOB_NAME'], args)
process_tar_file(args['bucket'], args['input_file'])
job.commit()