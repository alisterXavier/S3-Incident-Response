resource "aws_lambda_function" "Revoke_Access" {
  depends_on       = [aws_iam_role.Lambda_Role]
  runtime          = "nodejs20.x"
  function_name    = "revokeAccess"
  handler          = "index.handler"
  filename         = "lambda_function.zip"
  role             = aws_iam_role.Lambda_Role.arn
  source_code_hash = data.archive_file.lambda.output_base64sha256

}
resource "aws_cloudwatch_log_subscription_filter" "Lambda_CloudWatch_Revoke_Access_Sub" {
  depends_on      = [aws_cloudwatch_log_group.Log_Group, aws_lambda_function.Revoke_Access]
  name            = "Lambda_CloudWatch_Revoke_Access_Sub"
  log_group_name  = aws_cloudwatch_log_group.Log_Group.name
  filter_pattern  = "{$.eventName = \"DeleteObjects\"}"
  destination_arn = aws_lambda_function.Revoke_Access.arn
}
resource "aws_lambda_permission" "Lambda_Permissions_For_CloudWatch" {
  depends_on     = [aws_lambda_function.Revoke_Access, aws_cloudwatch_log_group.Log_Group]
  function_name  = aws_lambda_function.Revoke_Access.function_name
  statement_id   = "test"
  principal      = "logs.amazonaws.com"
  action         = "lambda:InvokeFunction"
  source_arn     = "${aws_cloudwatch_log_group.Log_Group.arn}:*"
  source_account = local.account_id
}
