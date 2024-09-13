resource "aws_cloudtrail" "Trail" {
  depends_on                    = [aws_s3_bucket.TrailTestBucket, aws_cloudwatch_log_group.Log_Group, aws_iam_role.Cloud_Watch_Access_Role]
  enable_log_file_validation    = true
  enable_logging                = true
  include_global_service_events = false
  is_multi_region_trail         = false
  name                          = "Trail"
  kms_key_id                    = aws_kms_key.a.arn
  s3_bucket_name                = aws_s3_bucket.TrailTestBucket.id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.Log_Group.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.Cloud_Watch_Access_Role.arn
  advanced_event_selector {
    name = "log_delete_object"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "eventName"
      equals = ["DeleteObjects"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    # field_selector {
    #   field  = "resources.ARN"
    #   equals = ["${aws_s3_bucket.TestBucket.arn}/*"]
    # }

  }
}

resource "aws_kms_key" "a" {
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = false
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "Key policy created by CloudTrail",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${local.account_id}:root",
            "arn:aws:iam::${local.account_id}:user/cloud_user"
          ]
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow CloudTrail to encrypt logs",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : "kms:GenerateDataKey*",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceArn" : "arn:aws:cloudtrail:us-east-1:${local.account_id}:trail/Trail"
          },
          "StringLike" : {
            "kms:EncryptionContext:aws:cloudtrail:arn" : "arn:aws:cloudtrail:*:${local.account_id}:trail/*"
          }
        }
      },
      {
        "Sid" : "Allow CloudTrail to describe key",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : "kms:DescribeKey",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow principals in the account to decrypt log files",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:ReEncryptFrom"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "kms:CallerAccount" : "${local.account_id}"
          },
          "StringLike" : {
            "kms:EncryptionContext:aws:cloudtrail:arn" : "arn:aws:cloudtrail:*:${local.account_id}:trail/*"
          }
        }
      },
      {
        "Sid" : "Allow alias creation during setup",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : "kms:CreateAlias",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "kms:ViaService" : "ec2.us-east-1.amazonaws.com",
            "kms:CallerAccount" : "${local.account_id}"
          }
        }
      },
      {
        "Sid" : "Enable cross account log decryption",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:ReEncryptFrom"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "kms:CallerAccount" : "${local.account_id}"
          },
          "StringLike" : {
            "kms:EncryptionContext:aws:cloudtrail:arn" : "arn:aws:cloudtrail:*:${local.account_id}:trail/*"
          }
        }
      }
    ]
  })

}

resource "aws_kms_alias" "a" {
  name          = "alias/incidentkey"
  target_key_id = aws_kms_key.a.key_id
  # depends_on    = [aws_kms_key.a]
}
