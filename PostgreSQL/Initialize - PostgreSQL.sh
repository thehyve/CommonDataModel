#!/bin/bash
# Creates all OMOP tables in a new schema
# If path given, loads vocabulary with a filled omop cdm (vocabulary + sample data)
# If path given, loads a dataset
# Applies indices and constraints
# Example usage: sh execute.sh omops cdm5_2_1 postgres /Documents/OHDSI/OMOP_Data/vocab_download_v5_meddra/ /Documents/OHDSI/OMOP_Data/synpuf_1k/

# Variables
HOST_NAME="$1"
PORT="$2"
DATABASE_NAME="$3"
DATABASE_SCHEMA="$4"
USER="$5"
PASSWORD="$6"
VOCABULARY_PATH="$7" # Absolute path
CDM_DATA_PATH="$8"

# Check whether command line arguments are given
if test "$DATABASE_NAME" = ""  || "$USER" = "" || "$DATABASE_SCHEMA" = ""; then
    printf "Usage: \n"
    printf "   ./execute_etl.sh <host> <port> <database_name> <schema_name> <user_name> <password> [<vocabulary_path> [<cdm_data_path>]]\n"
    exit 1
fi

printf "===== Starting Create OMOP CDM instance =====\n"
printf "Using the database '$DATABASE_NAME' and the '$DATABASE_SCHEMA' schema.\n"
printf "Creating OMOP CDM, load vocabulary from '$VOCABULARY_PATH' and load CDM data form '$CDM_DATA_PATH'.\n"

export PGPASSWORD=$PASSWORD


# Create new schema and set it as default schema (no schema specified in loading scripts)
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "DROP SCHEMA IF EXISTS $DATABASE_SCHEMA CASCADE;"
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "CREATE SCHEMA $DATABASE_SCHEMA;"
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "ALTER DATABASE $DATABASE_NAME SET search_path TO $DATABASE_SCHEMA, public;"

# Create cdm tables
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -f "./OMOP CDM postgresql ddl.txt" -q

# Load vocabulary
if test "$VOCABULARY_PATH" != ""; then
    printf "\nLoading Vocabulary...\n"
    vocab_tables="CONCEPT DRUG_STRENGTH CONCEPT_RELATIONSHIP CONCEPT_ANCESTOR CONCEPT_SYNONYM VOCABULARY RELATIONSHIP CONCEPT_CLASS DOMAIN"
    for tableName in $vocab_tables; do
        printf "$tableName: "
        path="$VOCABULARY_PATH/$tableName.csv"
        psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "COPY $tableName FROM '$path' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b'"
    done
fi

# Load sample data
if test "$CDM_DATA_PATH" != ""; then
    printf "\nLoading CDM Data...\n"
    cdm_tables="CARE_SITE CONDITION_OCCURRENCE DEATH DRUG_EXPOSURE DEVICE_EXPOSURE LOCATION MEASUREMENT OBSERVATION PERSON PROCEDURE_OCCURRENCE PROVIDER VISIT_OCCURRENCE DRUG_ERA CONDITION_ERA"
    for tableName in $cdm_tables; do
        printf "$tableName: "
        path="$CDM_DATA_PATH/$tableName.csv"
        psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "COPY $tableName FROM '$path' WITH DELIMITER E',' CSV HEADER QUOTE E'\b'"
    done
fi

printf "\nApplying constraints...\n"
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -f "./OMOP CDM postgresql constraints - PostgreSQL.txt" -q
printf "\nApplying indices...\n"
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -f "./OMOP CDM postgresql pk indexes.txt"

# Restore search path
psql -h $HOST_NAME -p $PORT -U $USER -d $DATABASE_NAME -c "ALTER DATABASE $DATABASE_NAME SET search_path TO \"\$user\", public;"


