{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAI",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${oai_arn}"
      },
      "Action": "s3:GetObject",
      "Resource": "${bucket_arn}/*"
    }
  ]
}
