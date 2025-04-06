variable "name_prefix" {
  type        = string
  description = "Prefix for naming the SQS and DLQ"
}

variable "visibility_timeout" {
  type        = number
  description = "Visibility timeout for the main queue (in seconds)"
}

variable "max_receive_count" {
  type        = number
  description = "Max number of times a message can be received before going to DLQ"
}