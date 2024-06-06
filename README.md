## BigQuery Continuous Data Capture to Cloud Bigtable using Terraform

This Terraform module sets up a data pipeline on Google Cloud Platform (GCP) for capturing real-time taxi ride data and ingesting it into Cloud Bigtable. 

### Architecture

The following diagram illustrates the architecture of the data pipeline:

```
[Pub/Sub Public Topic (taxirides-realtime)] --> [Pub/Sub Subscription] --> [BigQuery Table (taxi_realtime)] --> [BigQuery Continuous Query] --> [Cloud Bigtable Table (continuousstream)]
```

### Resources Created

Here's a breakdown of the resources created by the Terraform module:

**Project Setup:**
* **Project Services:** Enables necessary APIs (BigQuery, Pub/Sub, Bigtable, etc.).

**BigQuery:**
* **Dataset:** Creates a dataset named "bqcdc".
* **Table:** Creates a partitioned table named "taxi_realtime" within the dataset.

**Pub/Sub:**
* **Subscription:** Creates a subscription to the public "taxirides-realtime" topic, streaming data to the BigQuery table.

**Cloud Bigtable:**
* **Instance:** Creates an instance named "cdc-instance".
* **Tables:** Creates two tables: "continuousstream" (for real-time data) and "continuousdml" (if you want to test with arbitrary tables and do INSERT DML).

**BigQuery Reservation:**
* **Reservation:** Creates an Enterprise edition reservation to ensure dedicated resources for continuous queries.
* **Assignment:** Assigns the reservation to continuous queries in the project.

**Service Account:**
* **Service Account:** Creates a service account for running the continuous query.
* **IAM Permissions:** Grants necessary permissions to the service account.

### How to Deploy

1. **Prerequisites:**
    * **Terraform installed:** Download and install Terraform from [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).
    * **GCP project:** Create a GCP project and enable billing.
    * **Google Cloud SDK:** Install the Google Cloud SDK and authenticate your account ([https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)).

2. **Clone the repository:**
    ```bash
    git clone https://github.com/ricardolui/bq-continuous-query-to-bigtable-demo.git
    cd bq-continuous-query-to-bigtable-demo
    ```

3. **Initialize Terraform:**
    ```bash
    terraform init
    ```

4. **Set Project ID:**
    * Replace `${_PROJECT_ID}` with your GCP project ID:
    ```bash
    export _PROJECT_ID="your-gcp-project-id"
    ```

5. **Apply Terraform Configuration:**
    ```bash
    terraform apply -auto-approve -var 'project_id=${_PROJECT_ID}'
    ```

6. **Manually Execute Continuous Query:**
    * After deployment, Terraform will output a BigQuery query.
    * Copy and execute this query in the BigQuery console.
    * Make sure to change the Settings to use Continuous Query and Select the continuousquery service account
    * Run the Query to start continuous data export to Cloud Bigtable.

### Note:

* **Continuous Query Management:** The provided query needs to be manually set up and managed (scheduling, monitoring, etc.) within BigQuery.
* **"continuousdml" Table:** The purpose of the "continuousdml" Bigtable table is not explicitly defined in the code and may require further configuration based on your use case.
