variable "ecr_name" {
  type = list(string)
}

variable "region" {
  type    = string
  default = "us-west-1"
}

variable "profile" {
  type    = string
  default = null
}
