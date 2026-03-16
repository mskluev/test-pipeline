variable "permissions_boundary" {
    description = "aws permissions boundary"
    type = string
}

variable "subnet_ids" {
    description = "aws subnet ids"
    type = list(string)
}

variable "security_group_ids" {
    description = "aws security group ids"
    type = list(string)
}