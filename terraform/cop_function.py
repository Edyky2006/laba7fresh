import boto3
import json
import os

s3_client = boto3.client('s3', endpoint_url='http://localhost.localstack.cloud:4566')
sqs_client = boto3.client('sqs', endpoint_url='http://localhost.localstack.cloud:4566')

def lambda_handler(event, context):
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    target_bucket = "s3-finish"
    
    print(f"File coping {object_key} з {source_bucket} до {target_bucket}")
    
    try:
        copy_source = {'Bucket': source_bucket, 'Key': object_key}
        s3_client.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=object_key)
        

        queue_url_response = sqs_client.get_queue_url(QueueName='copy-updates-queue')
        queue_url = queue_url_response['QueueUrl']
        
        message_body = {
            "status": "success",
            "file_name": object_key,
            "message": f"File {object_key} copied in {target_bucket}!"
        }
        
        sqs_client.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message_body)
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('File copied and message sent to SQS!')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e