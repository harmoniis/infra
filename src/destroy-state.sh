# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# If the bucket does not exist, create it
echo "Checking if the bucket $BACKEND_BUCKET_NAME exists..."

# Check if the bucket already exists
bucket_exists=$(
  gsutil ls -b -L $BACKEND_BUCKET_NAME >/dev/null 2>&1
  echo $?
)

# If the bucket does not exist echo error and exit
if [ $bucket_exists -eq 0 ]; then
  echo "The bucket $BACKEND_BUCKET_NAME exists. Starting destroy..."
  gcloud storage rm -r $BACKEND_BUCKET_NAME
else
  echo "The bucket $BACKEND_BUCKET_NAME doesn't exists. Exiting..."
fi