#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 && "$#" == 1 ]]
[[ "$1" =~ ^[a-f0-9]{64}$ ]]
archive=/home/huahua/teacher-workbench-pilot-release-copy-20261029.tar.gz
source_dir=/home/huahua/teacher-workbench-pilot-release-copy-20261029
base=sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64
tag=teacher-workbench-pilot-web:release-copy-20261029

[[ ! -e "$source_dir" && ! -L "$source_dir" ]]
echo "$1  $archive" | sha256sum -c -
[[ "$(docker inspect -f '{{.Image}}' teacher-workbench-pilot-web-1)" == "$base" ]]
[[ "$(docker inspect -f '{{.Image}}' teacher-workbench-pilot-worker-1)" == "$base" ]]
docker image tag "$base" teacher-workbench-pilot-web:release-copy-base-20261029
mkdir -m 700 "$source_dir"
tar -xzf "$archive" -C "$source_dir"
[[ "$(find "$source_dir" -type f | wc -l)" == 3 ]]
grep -Fq '通过 EasyTier 私网访问。账号由管理员创建。' "$source_dir/templates/registration/login.html"
grep -Fq '教师AI工作平台 · EasyTier 私网' "$source_dir/templates/base.html"
! grep -Eq '功能验证环境|先在测试环境' "$source_dir/templates/base.html" "$source_dir/templates/registration/login.html"
cd "$source_dir"
docker build --pull=false --network none --build-arg BASE_IMAGE=teacher-workbench-pilot-web:release-copy-base-20261029 -t "$tag" .
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" manage.py check
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" manage.py test workbench --noinput --verbosity 1
docker image inspect -f '{{.Id}}' "$tag" > IMAGE_ID
echo PILOT_RELEASE_COPY_OFFLINE_IMAGE_TESTED_NO_SWITCH
cat IMAGE_ID
