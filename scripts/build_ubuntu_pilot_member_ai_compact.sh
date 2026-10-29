#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 ]]
archive=/home/huahua/teacher-workbench-pilot-member-ai-compact-20261029.tar.gz
source_dir=/home/huahua/teacher-workbench-pilot-member-ai-compact-20261029-v2
base=sha256:7d85997d168c880e059069b537d5a3b9029b3b8b20682968d98fb408b8fda34f
base_tag=teacher-workbench-pilot-web:member-ai-length-20261028
tag=teacher-workbench-pilot-web:member-ai-compact-20261029
echo 'fc1395ab65097738a83602ec9f6e4e6efece4bdc73eb49063939d15ea642f414  /home/huahua/teacher-workbench-pilot-member-ai-compact-20261029.tar.gz' | sha256sum -c -
[[ ! -e "$source_dir" && ! -L "$source_dir" ]]
[[ "$(docker image inspect -f '{{.Id}}' "$base_tag")" == "$base" ]]
mkdir -m 700 "$source_dir"
tar -xzf "$archive" -C "$source_dir"
[[ "$(find "$source_dir" -type f | wc -l)" == 4 ]]
python3 -m py_compile "$source_dir/config/settings.py" "$source_dir/workbench/ai.py" "$source_dir/workbench/tests_member_flow.py"
cd "$source_dir"
docker build --pull=false --network none --build-arg BASE_IMAGE="$base_tag" -t "$tag" .
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" \
  manage.py test workbench.tests_member_flow.MemberProviderAdapterTests workbench.tests_member_tasks --noinput --verbosity 1
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" manage.py check
docker image inspect -f '{{.Id}}' "$tag" > IMAGE_ID
echo PILOT_MEMBER_AI_COMPACT_OFFLINE_IMAGE_TESTED_NO_SWITCH
cat IMAGE_ID
