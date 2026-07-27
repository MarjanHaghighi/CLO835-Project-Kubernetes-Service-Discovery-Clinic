variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}


variable "key_name" {
  description = "Existing EC2 Key Pair name"
  type        = string
}

variable "student_id" {
  description = "Seneca student ID"
  type        = string
  default     = "127878254"
}

variable "github_repo" {
  description = "Public GitHub repository clone URL"
  type        = string
}
