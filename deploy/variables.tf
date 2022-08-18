variable "profile"{
  default = "eike"
}

variable "environment" {
  description = "environment"
  default = "dev"
}

variable "application" {
  description = "application"
  default = "sharepass"
}

variable "lambda_logs_retention_in_days" {
  description = "default retention time for lambda logs"
  default = 30
}

variable "tags" {
  description = "default tags"
  type = map(string)
  default = {
    application = "sharepass"
  }
}