#!/usr/bin/env bash
# Dò giới hạn dung lượng video của Locket (bucket locket-video) bằng cách
# mô phỏng đúng flow resumable upload: POST start -> PUT bytes.
# Rule chỉ chặn theo size nên dùng data giả (/dev/zero) là đủ.
#
# Dùng: ID_TOKEN='<token>' ./probe-locket-video-limit.sh
set -uo pipefail

ID_TOKEN="${ID_TOKEN:?Set ID_TOKEN env var}"
UID_LOCKET="ubnDy27WfjdtwPXglvWD5WRFdnu1"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CREATED_NAMES=()      # các enc-path tạo ra trong lần chạy này (PUT 200)
LAST_CODE=""

rand_name() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20; }
auth=(-H "Authorization: Firebase ${ID_TOKEN}" -H "X-Ios-Bundle-Identifier: com.locket.Locket")

# try_size <bytes> : đặt LAST_CODE = HTTP code của PUT; append CREATED_NAMES nếu 200
try_size() {
  local size="$1"
  local name; name="$(rand_name).mp4"
  local path="users/${UID_LOCKET}/moments/videos/${name}"
  local enc="users%2F${UID_LOCKET}%2Fmoments%2Fvideos%2F${name}"
  local base="https://firebasestorage.googleapis.com/v0/b/locket-video/o/${enc}?uploadType=resumable&name=${enc}"

  local hdr
  hdr="$(curl -s -D - -o /dev/null -X POST "$base" "${auth[@]}" \
    -H "content-type: application/json; charset=UTF-8" \
    -H "x-goog-upload-protocol: resumable" -H "accept: */*" \
    -H "x-goog-upload-command: start" \
    -H "x-goog-upload-content-length: ${size}" \
    -H "x-goog-upload-content-type: video/mp4" \
    --data "{\"name\":\"${path}\",\"contentType\":\"video/mp4\",\"bucket\":\"\",\"metadata\":{\"creator\":\"${UID_LOCKET}\",\"visibility\":\"private\"}}")"

  local upload_url
  upload_url="$(printf '%s' "$hdr" | grep -i '^x-goog-upload-url:' | sed 's/^[^:]*: *//I' | tr -d '\r')"
  if [[ -z "$upload_url" ]]; then
    LAST_CODE="START_$(printf '%s' "$hdr" | grep -iE '^HTTP/' | head -1 | tr -d '\r')"
    return
  fi

  local f="$TMP/data.bin"
  dd if=/dev/zero of="$f" bs=1 count=0 seek="$size" 2>/dev/null

  LAST_CODE="$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$upload_url" "${auth[@]}" \
    -H "content-type: application/octet-stream" \
    -H "x-goog-upload-protocol: resumable" -H "x-goog-upload-offset: 0" \
    -H "x-goog-upload-command: upload, finalize" \
    --data-binary "@$f")"

  [[ "$LAST_CODE" == "200" ]] && CREATED_NAMES+=("$enc")
}

echo "== Coarse probe (MB) =="
declare -a PROBES=(4 5 6 8)
last_ok_b=0; first_fail_b=0
for m in "${PROBES[@]}"; do
  try_size "$(( m * 1024 * 1024 ))"
  printf "  %4d MB -> HTTP %s\n" "$m" "$LAST_CODE"
  if [[ "$LAST_CODE" == "200" ]]; then last_ok_b=$(( m * 1024 * 1024 ));
  elif [[ "$LAST_CODE" == "403" ]]; then first_fail_b=$(( m * 1024 * 1024 )); break;
  else echo "  (mã lạ '$LAST_CODE' — token hết hạn? dừng)"; break; fi
done

if (( first_fail_b > 0 && last_ok_b > 0 )); then
  echo "== Binary search tới độ chính xác ~16KB giữa $((last_ok_b/1024))KB và $((first_fail_b/1024))KB =="
  lo=$last_ok_b; hi=$first_fail_b
  while (( hi - lo > 16384 )); do
    mid=$(( (lo + hi) / 2 ))
    try_size "$mid"
    printf "  %8d B (%6.2f MB / %d MiB-frac) -> HTTP %s\n" "$mid" "$(echo "scale=2; $mid/1048576" | bc)" "$mid" "$LAST_CODE"
    if [[ "$LAST_CODE" == "200" ]]; then lo=$mid; else hi=$mid; fi
  done
  echo ""
  echo ">> Pass tới ${lo} B ($(echo "scale=3; $lo/1048576" | bc) MiB). Fail từ ${hi} B ($(echo "scale=3; $hi/1048576" | bc) MiB)."
  echo ">> Ngưỡng nằm trong (${lo}, ${hi}] bytes."
fi

# Chỉ xoá object do CHÍNH lần chạy này tạo ra (đã track tên) — an toàn, không đụng video thật.
echo "== Dọn object test của lần chạy này =="
for enc in "${CREATED_NAMES[@]:-}"; do
  [[ -z "$enc" ]] && continue
  curl -s -o /dev/null -X DELETE "https://firebasestorage.googleapis.com/v0/b/locket-video/o/${enc}" "${auth[@]}"
  echo "  deleted: $enc"
done

# Liệt kê (CHỈ ĐỌC) các object trong thư mục videos để em tự rà object sót từ lần chạy trước.
echo "== Object hiện có trong users/${UID_LOCKET}/moments/videos/ (chỉ liệt kê, không xoá) =="
python3 - "$ID_TOKEN" "$UID_LOCKET" <<'PY'
import sys, json, urllib.request
tok, uid = sys.argv[1], sys.argv[2]
base="https://firebasestorage.googleapis.com/v0/b/locket-video/o"
r=urllib.request.Request(f"{base}?prefix=users/{uid}/moments/videos/",
    headers={"Authorization":f"Firebase {tok}","X-Ios-Bundle-Identifier":"com.locket.Locket"})
data=json.loads(urllib.request.urlopen(r).read())
items=data.get("items", [])
if not items:
    print("  (trống)")
for it in items:
    size=int(it.get("size","0")); name=it["name"]
    flag=" <- nghi data test (bội số chẵn 1MiB)" if size>0 and size%(1024*1024)==0 else ""
    print(f"  {size/1048576:8.3f} MiB  {name}{flag}")
PY
echo "Done."
