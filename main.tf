module "project-services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "14.4.0"
  disable_services_on_destroy = false
  project_id  = var.project_id
  enable_apis = true

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "cloudapis.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",    
    "bigtable.googleapis.com",    
  ]
}

resource "time_sleep" "wait_after_apis_activate" {
  depends_on      = [module.project-services]
  create_duration = "120s"
}

#Creates a dataset resource for Google BigQuery in project
resource "google_bigquery_dataset" "default" {
  project                     = var.project_id
  dataset_id                  = "bqcdc"
  friendly_name               = "bq cdc dataset"
  description                 = "Table CDC"
  location                    = "US"
  default_table_expiration_ms = 3600000

  labels = {
    env = "default"
  }
}

#Creates a table resource with schema hardcoded in configuration for Google BigQuery#
resource "google_bigquery_table" "taxi_realtime" {
  project                     = var.project_id
  dataset_id = google_bigquery_dataset.default.dataset_id
  table_id   = "taxi_realtime"
  time_partitioning {
    type = "DAY"
  }
  labels = {
    env = "default"
  }
  schema = <<EOF
[
  {
    "description": "Name of a subscription.",
    "mode": "NULLABLE",
    "name": "subscription_name",
    "type": "STRING"
  },
  {
    "description": "ID of a message",
    "mode": "NULLABLE",
    "name": "message_id",
    "type": "STRING"
  },
  {
    "description": "The time of publishing a message.",
    "mode": "NULLABLE",
    "name": "publish_time",
    "type": "TIMESTAMP"
  },
  {
    "description": "The message body. Must be valid JSON.",
    "mode": "NULLABLE",
    "name": "data",
    "type": "JSON"
  },
  {
    "description": "A JSON object containing all message attributes. It also contains additional fields that are part of the Pub/Sub message including the ordering key, if present.",
    "mode": "NULLABLE",
    "name": "attributes",
    "type": "JSON"
  }
]
EOF
  depends_on = [google_bigquery_dataset.default, time_sleep.wait_after_apis_activate]
  deletion_protection=false
}

resource "google_pubsub_subscription" "taxi_realtime_subscription" {
  project      = var.project_id
  name  = "taxi_realtime_subscription"
  topic = "projects/pubsub-public-data/topics/taxirides-realtime"

  bigquery_config {
    table = "${google_bigquery_table.taxi_realtime.project}.${google_bigquery_table.taxi_realtime.dataset_id}.${google_bigquery_table.taxi_realtime.table_id}"
    write_metadata = true
  }

  depends_on = [google_bigquery_table.taxi_realtime, time_sleep.wait_after_apis_activate]
 
}

# Create a Bigtable instance
resource "google_bigtable_instance" "default" {
  project      = var.project_id
  name             = "cdc-instance"
  cluster {
    cluster_id   = "cdc-instance-cluster"
    num_nodes    = 1
    storage_type = "HDD"
    zone    = var.zone
  }  
  deletion_protection = false
}

# Create Bigtable table "continuousstream"
resource "google_bigtable_table" "continuousstream" {
  project      = var.project_id
  name          = "continuousstream"
  instance_name = google_bigtable_instance.default.name
}

# Create Bigtable table "continuousdml"
resource "google_bigtable_table" "continuousdml" {
  project       = var.project_id
  name          = "continuousdml"
  instance_name = google_bigtable_instance.default.name
  depends_on = [google_bigtable_instance.default]
}

output "query_to_run_on_console" {
  value = <<EOF
EXPORT DATA
 OPTIONS (
 format = 'CLOUD_BIGTABLE',
 uri = "https://bigtable.googleapis.com/projects/${var.project_id}/instances/${google_bigtable_instance.default.name}/appProfiles/default/tables/${google_bigtable_table.continuousstream.name}",
 truncate = TRUE,
 overwrite = TRUE,
 auto_create_column_families = TRUE
 )
AS (
 SELECT
  CAST(CONCAT(ride_id, timestamp,latitude, longitude) AS STRING) AS rowkey,
  STRUCT( timestamp,
    latitude,
    longitude,
    meter_reading,
    ride_status,
    passenger_count ) AS features
FROM 
  (
    SELECT
    JSON_VALUE(DATA, '$.latitude') AS latitude,
    JSON_VALUE(DATA, '$.longitude') AS longitude,
    JSON_VALUE(DATA, '$.meter_reading') AS meter_reading,
    JSON_VALUE(DATA, '$.passenger_count') AS passenger_count,
    JSON_VALUE(DATA, '$.ride_id') AS ride_id,
    JSON_VALUE(DATA, '$.ride_status') AS ride_status,
    JSON_VALUE(DATA, '$.timestamp') AS timestamp
    FROM ${google_bigquery_table.taxi_realtime.project}.${google_bigquery_table.taxi_realtime.dataset_id}.${google_bigquery_table.taxi_realtime.table_id}
  )
  WHERE ride_status = "enroute"  
);
EOF
}

# Creates a BigQuery Reservation
resource "google_bigquery_reservation" "reservation" {
  project           = var.project_id
  name              = "reservation"
  edition           = "ENTERPRISE"      
  location          = "us"
  // Set to 0 for testing purposes
  // In reality this would be larger than zero
  slot_capacity     = 100
  
}

resource "google_bigquery_reservation_assignment" "continuous" {
  project           = var.project_id
  assignee  = "projects/${var.project_id}"
  job_type = "CONTINUOUS"
  reservation = google_bigquery_reservation.reservation.id
  depends_on = [ google_bigquery_reservation.reservation ]
}

#############################################################################################
#RESOURCE FOR SERVICE_ACCOUNT CREATION, ALLOWS MANAGEMENT OF A GOOGLE CLOUD SERVICE ACCOUNT.    
#############################################################################################

resource "google_service_account" "service_account" {
  project      = var.project_id
  account_id   = "bq-continuous-query-sa"
  display_name = "Continuous Query Service Account"  
}

resource "google_project_iam_member" "iam_permission_continuous_query_bq_viewer" {
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = format("serviceAccount:%s", google_service_account.service_account.email)
  depends_on = [time_sleep.wait_after_apis_activate, google_service_account.service_account]
}

resource "google_project_iam_member" "iam_permission_continuous_bigtable" {
  project    = var.project_id
  role       = "roles/bigtable.user"
  member     = format("serviceAccount:%s", google_service_account.service_account.email)
  depends_on = [time_sleep.wait_after_apis_activate, google_service_account.service_account]
}
resource "google_project_iam_member" "iam_permission_continuous_bq_user" {
  project    = var.project_id
  role       = "roles/bigquery.user"
  member     = format("serviceAccount:%s", google_service_account.service_account.email)
  depends_on = [time_sleep.wait_after_apis_activate, google_service_account.service_account]
}

resource "google_project_iam_member" "iam_permission_continuous_bq_job_user" {
  project    = var.project_id
  role       = "roles/bigquery.jobUser"
  member     = format("serviceAccount:%s", google_service_account.service_account.email)
  depends_on = [time_sleep.wait_after_apis_activate, google_service_account.service_account]
}


####################################################################################
# Local Variables used inside the module, 
####################################################################################
# Create a random string for the project/bucket suffix
resource "random_string" "project_random" {
  length  = 10
  upper   = false
  lower   = true
  numeric  = true
  special = false
}
resource "random_id" "server" {
  byte_length = 4
}
