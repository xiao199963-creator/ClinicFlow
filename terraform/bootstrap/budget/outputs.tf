output "budget_arn" {
  description = "The ARN of the ClinicFlow AWS budget"
  value       = aws_budgets_budget.clinicflow_budget.arn
}