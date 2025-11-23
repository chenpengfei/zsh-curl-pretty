curlpj() {
  local tmpfile=$(mktemp)
  local http_code
  local time_ms

  # 调用 curl：
  #  -s 静默输出
  #  -D - 将 HTTP 响应头输出到 stdout（后面解析状态码）
  #  -o 将响应 body 写到临时文件
  #  -w 自定义格式：仅输出状态码和耗时（毫秒）
  http_code=$(curl -s -D - -o "$tmpfile" -w "%{http_code}" "$@" 2>/dev/null | head -n 1 | awk '{print $2}')

  time_ms=$(curl -s -o /dev/null -w "%{time_total}" "$@" 2>/dev/null)
  time_ms=$(printf "%.0f" $(echo "$time_ms * 1000" | bc))

  # 彩色状态码
  local green="\033[32m"
  local red="\033[31m"
  local yellow="\033[33m"
  local reset="\033[0m"

  if [[ "$http_code" == 2* ]]; then
    echo -e "${green}✔ HTTP $http_code${reset}  (${time_ms}ms)"
  elif [[ "$http_code" == 3* ]]; then
    echo -e "${yellow}→ HTTP $http_code${reset}  (${time_ms}ms)"
  else
    echo -e "${red}✘ HTTP $http_code${reset}  (${time_ms}ms)"
  fi

  # 读取 body
  local output
  output=$(cat "$tmpfile")

  # 判断是否 JSON
  if [[ "$output" == \{* || "$output" == \[* ]]; then
    echo "$output" | jq | bat -l json
  else
    echo "$output"
  fi

  rm "$tmpfile"
}
