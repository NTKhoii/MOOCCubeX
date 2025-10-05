#!/bin/bash
set -euo pipefail

# Kiểm tra dung lượng đĩa
REQUIRED_SPACE=30000000  # 30GB tính bằng KB
AVAILABLE_SPACE=$(df -k /home/ec2-user | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
  echo "Lỗi: Không đủ dung lượng đĩa. Còn trống: $AVAILABLE_SPACE KB, Cần: $REQUIRED_SPACE KB"
  exit 1
fi

BASE_URL="https://lfs.aminer.cn/misc/moocdata/data/mooccube2"
mkdir -p entities relations prerequisites

FILES="entities/reply.json entities/video.json entities/comment.json entities/course.json entities/other.json entities/paper.json entities/problem.json entities/school.json entities/teacher.json entities/user.json entities/concept.json relations/course-school.txt relations/course-teacher.txt relations/user-comment.txt relations/video_id-ccid.txt relations/comment-reply.txt relations/concept-other.txt relations/course-comment.txt relations/concept-video.txt relations/exercise-problem.txt relations/user-reply.txt relations/concept-comment.txt relations/concept-paper.txt relations/concept-problem.txt relations/concept-reply.json relations/course-field.json relations/reply-reply.txt relations/user-problem.json relations/user-video.json relations/user-xiaomu.json prerequisites/psy.json prerequisites/cs.json prerequisites/math.json"

echo "Bắt đầu tải song song..."
echo "$FILES" | tr ' ' '\n' | xargs -P 4 -I {} bash -c '
  filename="{}"
  dir=$(dirname "${filename}")
  log_dir="error_$dir"
  log_file="error_${filename}.log"
  mkdir -p "$log_dir"  # Tạo thư mục log
  echo "Đang tải ${filename} ..."
  if ! wget -v --tries=3 --timeout=10 -S "$BASE_URL/${filename}" -O "${filename}" 2> "$log_file"; then
    echo "Lỗi: Tải ${filename} thất bại. Xem chi tiết trong $log_file."
    cat "$log_file"
    exit 1
  fi
'

echo "Tất cả file đã tải xong. Bắt đầu upload lên S3..."
aws s3 sync ./entities s3://$S3_BUCKET/entities --region $AWS_REGION || { echo "Lỗi: Upload entities thất bại"; exit 1; }
aws s3 sync ./relations s3://$S3_BUCKET/relations --region $AWS_REGION || { echo "Lỗi: Upload relations thất bại"; exit 1; }
aws s3 sync ./prerequisites s3://$S3_BUCKET/prerequisites --region $AWS_REGION || { echo "Lỗi: Upload prerequisites thất bại"; exit 1; }

echo "Dọn dẹp file cục bộ..."
rm -rf entities relations prerequisites

echo "Tạo file đánh dấu hoàn tất..."
echo "Upload hoàn tất vào $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/upload_done.txt
aws s3 cp /tmp/upload_done.txt s3://$S3_BUCKET/_upload_done || { echo "Lỗi: Tải file đánh dấu thất bại"; exit 1; }

echo "Hoàn tất."
