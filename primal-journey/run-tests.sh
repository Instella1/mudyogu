#!/bin/sh
# 원시인록 여행기 회귀 검사 (Node 내장 fs/vm/assert 만 사용)
cd "$(dirname "$0")/tests" || exit 1
fail=0
for t in balance raptor journey debug ptera spino course; do
  if node "test-$t.cjs" > /dev/null 2>&1; then echo "통과  test-$t.cjs"; else echo "실패  test-$t.cjs"; fail=1; fi
done
exit $fail
