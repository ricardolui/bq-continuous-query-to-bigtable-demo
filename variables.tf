variable "project_id" {
  type        = string
  description = "project id required"
}
variable "project_name" {
 type        = string
 description = "project name in which demo deploy"
}
variable "project_number" {
 type        = string
 description = "project number in which demo deploy"
}
variable "gcp_account_name" {
 description = "user performing the demo"
}
variable "deployment_service_account_name" {
 description = "Cloudbuild_Service_account having permission to deploy terraform resources"
}
variable "org_id" {
 description = "Organization ID in which project created"
}
variable "data_location" {
 type        = string
 default     = "us" 
 description = "Location of source data file in central bucket"
}
variable "secret_stored_project" {
  type        = string
  description = "Project where secret is accessing from"
}

#############################################################
#Variables related to modules
#############################################################

###############################################################################################################################################
#Local declaration block is for the user to declare those variables here which is being used in .tf files in repetitive manner OR get the exact #definition from terraform document
###############################################################################################################################################
locals {
  # The project is the provided name OR the name with a random suffix
  local_project_id = var.project_number == "" ? "${var.project_id}-${random_string.project_random.result}" : var.project_id
  # Apply suffix to bucket so the name is unique
  local_storage_bucket = "${var.project_id}-${random_string.project_random.result}"
  # Use the GCP user or the service account running this in a DevOps process
  # local_impersonation_account = var.deployment_service_account_name == "" ? "user:${var.gcp_account_name}" : "serviceAccount:${var.deployment_service_account_name}"

}

############################################################################
#Variables which are required for running modules
############################################################################

#GCP Region to Deploy
variable "region" {
  type        = string
  default     = "us-east4"
  description = "The GCP region to deploy"
}

#Zone in the region
variable "zone" {
  type        = string  
  default     = "us-east4-a"
  description = "The GCP zone in the region. Must be in the region."  
}

#Variable for BiqQuery
variable "bigquery_region" {
  type        = string
  default     = "us"
  description = "The GCP region to deploy BigQuery.  This should either match the region or be 'us' or 'eu'.  This also affects the GCS bucket and Data Catalog."
}

variable "omni_dataset" {
  type        = string
  description = "The full path project_id.dataset_id to the OMNI data."
  default     = "Keep you dataset name.table name"
}
