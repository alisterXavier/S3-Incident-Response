variable "user" {
  type    = list(string)
  default = ["user1", "user2"]
}

variable "DB_Admin_User" {
  type    = list(string)
  default = ["user3"]
}

variable "ACCESS_KEY" {
  type = string
}

variable "SECRET_ACCESS_KEY" {
  type = string
}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
data "aws_caller_identity" "current" {}