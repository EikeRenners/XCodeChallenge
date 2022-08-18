
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "super-unique-bucket-asdf-eike"
  force_destroy = true
}

resource "aws_s3_object" "sharepass_lambda" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lmb-${var.application}.zip"
  source = data.archive_file.lmb-sharepass.output_path
  etag = filemd5(data.archive_file.lmb-sharepass.output_path)  

  depends_on = [
    data.archive_file.lmb-sharepass
  ]
}