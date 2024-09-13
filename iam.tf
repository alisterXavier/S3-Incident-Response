data "aws_iam_user" "Users" {
  for_each   = toset(var.user)
  user_name  = each.value
  depends_on = [aws_iam_user.Users]
}
data "aws_iam_user" "Admin_Users" {
  for_each   = toset(var.DB_Admin_User)
  user_name  = each.value
  depends_on = [aws_iam_user.Users]
}
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "./S3_Incident_Response/index.mjs"
  output_path = "./lambda_function.zip"
}

# Users and User Policies
resource "aws_iam_user" "Users" {
  for_each = toset(concat(var.user, var.DB_Admin_User))
  name     = each.value
}
resource "aws_iam_user_policy_attachment" "User_Policy_Attachment" {
  for_each   = data.aws_iam_user.Users
  user       = each.value.user_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  depends_on = [data.aws_iam_user.Users, aws_iam_user.Users]
}

# Full Access S3 Role Policy
resource "aws_iam_role" "S3_Access_Role" {
  name = "S3_Access_Role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          AWS : values(data.aws_iam_user.Admin_Users)[*].arn
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "S3_Access_Role_Policy_Attachment" {
  role       = aws_iam_role.S3_Access_Role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  depends_on = [aws_iam_role.S3_Access_Role]
}

# For CloudTrail to access CloudWatch
resource "aws_iam_role" "Cloud_Watch_Access_Role" {
  name = "Cloud_Watch_Access_Role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "cloudtrail.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_policy" "Upsert_Cloud_Watch_Logs" {
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "AWSCloudTrailCreateLogStream",
        Effect : "Allow",
        Action : [
          "logs:CreateLogStream"
        ],
        Resource : ["${aws_cloudwatch_log_group.Log_Group.arn}:*"]
      },
      {
        Sid : "AWSCloudTrailPutLogEvents",
        Effect : "Allow",
        Action : [
          "logs:PutLogEvents"
        ],
        Resource : ["${aws_cloudwatch_log_group.Log_Group.arn}:*"]
      }
    ]
  })
  depends_on = [aws_iam_role.Cloud_Watch_Access_Role]
}
resource "aws_iam_role_policy_attachment" "Cloud_Watch_Role_Policy_Attachment" {
  role       = aws_iam_role.Cloud_Watch_Access_Role.name
  policy_arn = aws_iam_policy.Upsert_Cloud_Watch_Logs.arn
  depends_on = [aws_iam_role.Cloud_Watch_Access_Role, aws_iam_policy.Upsert_Cloud_Watch_Logs]
}

# For Lambda
resource "aws_iam_role" "Lambda_Role" {
  name = "Lambda_Role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_policy" "Lambda_Policy" {
  name = "Lambda_Role_Policy"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : ["s3:PutBucketPolicy", "s3:GetBucketPolicy"],
        Resource : "${aws_s3_bucket.TestBucket.arn}"
      },
      {
        Effect : "Allow",
        Action : "logs:CreateLogGroup",
        Resource : "arn:aws:logs:us-east-1:${local.account_id}:*"
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : [
          "arn:aws:logs:us-east-1:${local.account_id}:log-group:*"
        ]
      }
    ]
  })

  depends_on = [aws_iam_role.Lambda_Role]
}
resource "aws_iam_role_policy_attachment" "Lambda_Role_policy_Attachment" {
  role       = aws_iam_role.Lambda_Role.name
  policy_arn = aws_iam_policy.Lambda_Policy.arn
  depends_on = [aws_iam_role.Lambda_Role, aws_iam_policy.Lambda_Policy]
}
