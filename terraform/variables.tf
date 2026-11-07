variable "aws_region" {
  description = "AWS region for the ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the publishing role"
  type        = string
  default     = "Achapatience123/Secure-DevSecOps-CI-CD"
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the publishing role"
  type        = string
  default     = "main"
}

variable "ecr_repository_name" {
  description = "Amazon ECR repository name"
  type        = string
  default     = "secure-devsecops-api"
}
