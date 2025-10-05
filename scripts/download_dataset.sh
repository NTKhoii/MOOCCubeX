#!/bin/bash
set -euo pipefail

BASE_URL="https://lfs.aminer.cn/misc/moocdata/data/mooccube2"

mkdir -p entities relations prerequisites

FILES="entities/reply.json entities/video.json entities/comment.json entities/course.json entities/other.json entities/paper.json entities/problem.json entities/school.json entities/teacher.json entities/user.json entities/concept.json relations/course-school.txt relations/course-teacher.txt relations/user-comment.txt relations/video_id-ccid.txt relations/comment-reply.txt relations/concept-other.txt relations/course-comment.txt relations/concept-video.txt relations/exercise-problem.txt relations/user-reply.txt relations/concept-comment.txt relations/concept-paper.txt relations/concept-problem.txt relations/concept-reply.json relations/course-field.json relations/reply-reply.txt relations/user-problem.json relations/user-video.json relations/user-xiaomu.json prerequisites/psy.json prerequisites/cs.json prerequisites/math.json"

for filename in $FILES; do
  echo "Downloading ${filename} ..."
  dir=$(dirname "${filename}")
  mkdir -p "$dir"

  for i in {1..3}; do
    wget -q "$BASE_URL/${filename}" -O "${filename}" && break || {
      echo "⚠️ Attempt $i failed for ${filename}"
      sleep 2
    }
  done

  [[ -f "${filename}" ]] || echo "⚠️ Skipping missing file ${filename}"
done

echo "✅ All files processed. Starting upload to S3..."
aws s3 sync ./entities s3://$S3_BUCKET/entities --region $AWS_REGION || { echo "❌ s3 sync entities failed"; exit 1; }
aws s3 sync ./relations s3://$S3_BUCKET/relations --region $AWS_REGION || { echo "❌ s3 sync relations failed"; exit 1; }
aws s3 sync ./prerequisites s3://$S3_BUCKET/prerequisites --region $AWS_REGION || { echo "❌ s3 sync prerequisites failed"; exit 1; }

# tạo marker file báo hoàn tất
echo "Upload finished at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/upload_done.txt
aws s3 cp /tmp/upload_done.txt s3://$S3_BUCKET/_upload_done --region $AWS_REGION || { echo "❌ failed to put marker"; exit 1; }

echo "✅ Done."
