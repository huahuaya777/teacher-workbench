#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 ]]
archive=/home/huahua/teacher-workbench-pilot-member-ai-math-20261029.tar.gz
source_dir=/home/huahua/teacher-workbench-pilot-member-ai-math-20261029
base=sha256:7f81c32b41368bf26c5f85a9f4fd602ee6393360ba1f4a8f8b0a75d93a675bf5
base_tag=teacher-workbench-pilot-web:member-ai-compact-20261029
tag=teacher-workbench-pilot-web:member-ai-math-20261029
echo 'af1ed96be46c55e16384e8b14508683bcef29306fa600c0b9bdbf745808d8e5b  /home/huahua/teacher-workbench-pilot-member-ai-math-20261029.tar.gz' | sha256sum -c -
[[ ! -e "$source_dir" && ! -L "$source_dir" ]]
[[ "$(docker image inspect -f '{{.Id}}' "$base_tag")" == "$base" ]]
mkdir -m 700 "$source_dir"
tar -xzf "$archive" -C "$source_dir"
[[ "$(find "$source_dir" -type f | wc -l)" == 7 ]]
python3 -m py_compile "$source_dir/workbench/export.py" \
  "$source_dir/workbench/templatetags/worksheet_display.py" \
  "$source_dir/workbench/ai.py" "$source_dir/workbench/tests.py" \
  "$source_dir/workbench/tests_member_flow.py"
cd "$source_dir"
docker build --pull=false --network none --build-arg BASE_IMAGE="$base_tag" -t "$tag" .
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" \
  manage.py test workbench.tests.MathFormattingTests \
    workbench.tests.WorkflowTests.test_simple_powers_have_editable_word_structure_and_safe_preview \
    workbench.tests.WorkflowTests.test_provider_dollar_math_is_editable_and_matches_preview \
    workbench.tests.WorkflowTests.test_simple_square_roots_render_as_editable_word_math \
    workbench.tests.WorkflowTests.test_literal_model_line_breaks_match_preview_and_teacher_word \
    workbench.tests_member_flow.MemberProviderAdapterTests --noinput --verbosity 1
docker run --pull never --rm --network none -e DJANGO_DEBUG=1 --entrypoint python "$tag" manage.py check
docker image inspect -f '{{.Id}}' "$tag" > IMAGE_ID
echo PILOT_MEMBER_AI_MATH_OFFLINE_IMAGE_TESTED_NO_SWITCH
cat IMAGE_ID
