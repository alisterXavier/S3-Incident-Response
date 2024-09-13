resource "aws_s3_bucket" "TestBucket" {
  bucket        = "testbucketbucketbucketbucket1011"
  force_destroy = true
}

resource "aws_s3_bucket" "TrailTestBucket" {
  bucket        = "trailtestbucketbucketbucket1011"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "TestBucketVersioning" {
  bucket = aws_s3_bucket.TestBucket.id
  versioning_configuration {
    status = "Enabled"
  }
  depends_on = [aws_s3_bucket.TestBucket]
}

resource "aws_s3_bucket_policy" "name" {
  bucket = aws_s3_bucket.TestBucket.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          AWS : values(data.aws_iam_user.Admin_Users)[*].arn
        },
        Action : "s3:*"
        Resource : [
          aws_s3_bucket.TestBucket.arn
        ],
      }
    ]
  })
  depends_on = [aws_s3_bucket.TestBucket]
}

resource "aws_s3_bucket_policy" "Trailname" {
  bucket = aws_s3_bucket.TrailTestBucket.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "AWSCloudTrailAclCheck",
        Effect : "Allow",
        Principal : {
          Service : "cloudtrail.amazonaws.com"
        },
        Action : "s3:GetBucketAcl",
        Resource : "${aws_s3_bucket.TrailTestBucket.arn}"
        # Condition : {
        # StringEquals : {
        # "AWS:SourceArn" : "arn:aws:cloudtrail:us-east-1:${local.account_id}:trail/Trail"
        # }
        # }
      },
      {
        Sid : "AWSCloudTrailWrite",
        Effect : "Allow",
        Principal : {
          Service : "cloudtrail.amazonaws.com"
        },
        Action : "s3:PutObject",
        Resource : "${aws_s3_bucket.TrailTestBucket.arn}/*"
        # Condition : {
        #   StringEquals : {
        #     "AWS:SourceArn" : "arn:aws:cloudtrail:us-east-1:${local.account_id}:trail/Trail",
        #     "s3:x-amz-acl" : "bucket-owner-full-control"
        #   }
        # }
      }
    ]
  })
  depends_on = [aws_s3_bucket.TrailTestBucket]
}
