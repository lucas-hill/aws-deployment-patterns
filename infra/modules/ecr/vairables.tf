variable "name" {
  description = "Name of the ECR repository (also used as the image name)"
  type        = string
}

#image_tag_mutability is the most production-relevant decision here.
#MUTABLE means you can push a new image and tag it latest, replacing what latest previously pointed at.
#IMMUTABLE means every tag is fixed — once v1.0.3 exists, you cannot overwrite it. You'd push v1.0.4 instead.
variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. MUTABLE allows :latest to move; IMMUTABLE locks each tag forever."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Whether to scan images for vulnerabilities when they're pushed"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Whether terraform destroy can remove the repo even if it contains images. Set true for dev, false for prod."
  type        = bool
  default     = false
}

variable "lifecycle_policy_keep_count" {
  description = "How many recent images to retain. Older untagged images are deleted automatically."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}
