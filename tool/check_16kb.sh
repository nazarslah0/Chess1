#!/usr/bin/env bash
# يتحقق أن كل مقاطع LOAD في ملفات ELF محاذاة على 16KB (متطلب Google Play).
# الاستخدام: READELF=/path/to/llvm-readelf tool/check_16kb.sh <elf|apk|aab>...
set -uo pipefail

READELF="${READELF:-llvm-readelf}"
fail=0

check_elf() {
  local f="$1" name="$2" bad=0 n=0 align
  while read -r align; do
    n=$((n + 1))
    if [ $((align)) -lt 16384 ]; then bad=1; fi
  done < <("$READELF" -lW "$f" | awk '$1=="LOAD"{print $NF}')

  if [ "$n" -eq 0 ]; then
    echo "SKIP  $name (لا مقاطع LOAD)"
  elif [ "$bad" -eq 1 ]; then
    echo "FAIL  $name (المحاذاة أقل من 16KB)"
    fail=1
  else
    echo "OK    $name"
  fi
}

for target in "$@"; do
  case "$target" in
    *.apk|*.aab)
      tmp="$(mktemp -d)"
      unzip -q -o "$target" 'lib/arm64-v8a/*.so' 'base/lib/arm64-v8a/*.so' -d "$tmp" 2>/dev/null || true
      while IFS= read -r so; do
        check_elf "$so" "${so#"$tmp"/}"
      done < <(find "$tmp" -name '*.so' | sort)
      rm -rf "$tmp"
      ;;
    *)
      check_elf "$target" "$target"
      ;;
  esac
done

exit "$fail"
