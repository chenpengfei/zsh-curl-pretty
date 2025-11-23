curlpj() {
  # 1. 一次 curl：输出 = body + 换行 + "HTTP_CODE TIME_TOTAL"
  local raw_output
  raw_output=$(curl -s -w "\n%{http_code} %{time_total}" "$@")

  # 2. meta = 最后一行（状态码 + 总耗时）
  local meta=${raw_output##*$'\n'}
  local http_code=${meta%% *}
  local time_total=${meta#* }

  # 3. body = 除去最后一行后的所有内容
  local body=${raw_output%$'\n'"$meta"}

  # 4. 把秒转换成毫秒
  local time_ms
  time_ms=$(printf '%.0f' "$(echo "$time_total * 1000" | bc -l 2>/dev/null)")

  # 5. 彩色状态码
  local green="\033[32m"
  local yellow="\033[33m"
  local red="\033[31m"
  local reset="\033[0m"

  if [[ "$http_code" == 2* ]]; then
    echo -e "${green}✔ HTTP $http_code${reset} (${time_ms}ms)"
  elif [[ "$http_code" == 3* ]]; then
    echo -e "${yellow}→ HTTP $http_code${reset} (${time_ms}ms)"
  else
    echo -e "${red}✘ HTTP $http_code${reset} (${time_ms}ms)"
  fi

  # 6. 和你手动行为保持一致：body 原样交给 jq | bat
  # 如果 jq 解析失败（如遇到未转义的控制字符），则回退到原始输出
  if [[ "$body" == \{* || "$body" == \[* ]]; then
    if printf '%s' "$body" | jq . >/dev/null 2>&1; then
      printf '%s' "$body" | jq | bat -l json
    else
      echo -e "${yellow}⚠ JSON parse failed, showing raw output${reset}"
      printf '%s' "$body"
    fi
  else
    printf '%s' "$body"
  fi
}
