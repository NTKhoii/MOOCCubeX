#!/bin/bash
set -euo pipefail

# Check disk space
REQUIRED_SPACE=30000000  # 30GB in KB
AVAILABLE_SPACE=$(df -k /home/ec2-user | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
  echo "Error: Insufficient disk space. Available: $AVAILABLE_SPACE KB, Required: $REQUIRED_SPACE KB"
  exit 1
fi

BASE_URL="https://lfs.aminer.cn/misc/moocdata/data/mooccube2"
mkdir -p entities relations prerequisites

FILES="entities/reply.json entities/video.json entities/comment.json entities/course.json entities/other.json entities/paper.json entities/problem.json entities/school.json entities/teacher.json entities/user.json entities/concept.json relations/course-school.txt relations/course-teacher.txt relations/user-comment.txt relations/video_id-ccid.txt relations/comment-reply.txt relations/concept-other.txt relations/course-comment.txt relations/concept-video.txt relations/exercise-problem.txt relations/user-reply.txt relations/concept-comment.txt relations/concept-paper.txt relations/concept-problem.txt relations/concept-reply.json relations/course-field.json relations/reply-reply.txt relations/user-problem.json relations/user-video.json relations/user-xiaomu.json prerequisites/psy.json prerequisites/cs.json prerequisites/math.json"

echo "Starting parallel download..."
echo "$FILES" | tr ' ' '\n' | xargs -P 4 -I {} bash -c '
  filename="{}"
  dir=$(dirname "${filename}")
  mkdir -p "$dir"
  echo "Downloading ${filename} ..."
  if ! wget --tries=3 --timeout=10 -S "$BASE_URL/${filename}" -O "${filename}" 2> "error_${filename}.log"; then
    echo "Error: Failed to download ${filename}. See error_${filename}.log for details."
    cat "error_${filename}.log"
    exit 1
  fi
'

echo "All files downloaded. Starting upload to S3..."
aws s3 sync ./entities s3://$S3_BUCKET/entities --region $AWS_REGION || { echo "s3 sync entities failed"; exit 1; }
aws s3 sync ./relations s3://$S3_BUCKET/relations --region $AWS_REGION || { echo "s3 sync relations failed"; exit 1; }
aws s3 sync ./prerequisites s3://$S3_BUCKET/prerequisites --region $AWS_REGION || { echo "s3 sync prereq failed"; exit 1; }

echo "Cleaning up local files..."
rm -rf entities relations prerequisites

echo "Creating marker file..."
echo "Upload finished at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/upload_done.txt
aws s3 cp /tmp/upload_done.txt s3://$S3_BUCKET/_upload_done || { echo "failed to put marker"; exit 1; }

echo "Done."
