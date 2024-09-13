import zlib from 'zlib';
import {
  S3Client,
  PutBucketPolicyCommand,
  GetBucketPolicyCommand,
} from '@aws-sdk/client-s3';
import { STSClient, GetCallerIdentityCommand } from '@aws-sdk/client-sts';

const config = {},
  input = {};

var s3Client = new S3Client(config);
const stsClient = new STSClient(config);

export const handler = async (event, context) => {
  if (event.awslogs && event.awslogs.data) {
    var log;

    const command = new GetCallerIdentityCommand(input);
    const { Account } = await stsClient.send(command);

    const payload = Buffer.from(event.awslogs.data, 'base64');
    const logevents = JSON.parse(zlib.unzipSync(payload).toString()).logEvents;

    for (const logevent of logevents) {
      log = JSON.parse(logevent.message);
    }

    const userArn = log.userIdentity.arn;

    if (
      !userArn.includes(`arn:aws:sts::${Account}:assumed-role/s3_Access_Role`)
    ) {
      const bucketName = log.requestParameters.bucketName;
      var params = {
        Bucket: bucketName,
      };

      const existingPolicy = new GetBucketPolicyCommand(params);
      const policyResponse = await s3Client.send(existingPolicy);

      const policy = {
        Id: 'DenyAccessForUser',
        Version: '2012-10-17',
        Statement: [
          ...JSON.parse(policyResponse['Policy'])['Statement'],
          {
            Effect: 'Deny',
            Principal: {
              AWS: `${userArn}`,
            },
            Action: 's3:*',
            Resource: [
              `arn:aws:s3:::${bucketName}`,
              `arn:aws:s3:::${bucketName}/*`,
            ],
          },
        ],
      };

      params['Policy'] = JSON.stringify(policy);

      const command = new PutBucketPolicyCommand(params);
      await s3Client.send(command);

      return {
        statusCode: 200,
        message: 'Added user to BPolicy DENY',
      };
    }
  }

  return {
    message: 'Nothing to delete',
  };
};
