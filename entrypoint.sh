#!/bin/bash
set -e
if [[ -z "${MINIO_HOST}" ]]; then
  echo "Skipping Minio Server Configuration"
else
  mc config host add minio ${MINIO_HOST} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} && \
  mc alias set minio ${MINIO_HOST} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4 && \
  mc mb -p minio/spark && \
  mc mb -p minio/mlflow && \
  sleep 5 && \
  mlflow server --backend-store-uri postgresql://${MLFLOW_POSTGRES_USER}:${MLFLOW_POSTGRES_PASSWORD}@${MLFLOW_DB_HOST}/mlflow --default-artifact-root ${MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT} --artifacts-destination ${MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT} --host 0.0.0.0 &
fi

if [[ -z "${SQL_HOST}" ]]; then
  echo "Database for Metastore is skipped"
else
  schematool -dbType mssql -initSchema || true
  ${HIVE_HOME}/bin/start-metastore &
  ${SPARK_HOME}/sbin/start-thriftserver.sh --master=local[1] --driver-memory=1g \
    --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
    --hiveconf hive.server2.thrift.port=10000 \
    --hiveconf hive.server2.authentication=NOSASL \
    --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
    --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"
fi

if [[ -z "${AIRFLOW_HOME}" ]]; then
  echo "Skipping Airflow configuration"
else
  echo "Configuring airflow"
  airflow db init || true
  airflow users create -f admin -l admin -r Admin -u admin -e youremail@email.com --password admin
  airflow scheduler &
  airflow webserver &
fi

SHELL=bash jupyter lab --port 8888 --no-browser --ip=* --NotebookApp.token='' --NotebookApp.password='' --allow-root &
# Wait in background mode
tail -f /dev/null