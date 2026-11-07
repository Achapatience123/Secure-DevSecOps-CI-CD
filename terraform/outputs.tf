output "ecr_repository_url" {
  description = "URL of the application ECR repository"
  value       = aws_ecr_repository.application.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the application ECR repository"
  value       = aws_ecr_repository.application.arn
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "aws_account_id" {
  description = "AWS account hosting the infrastructure"
  value       = data.aws_caller_identity.current.account_id
}
