#!/usr/bin/env bash
set -euo pipefail

# context-optimizer.sh
# Portable, CRLF-safe context optimizer for LLM inputs without subagents.
# Features:
# - Semantic chunking by Markdown headings and fenced code blocks
# - Token estimation per chunk and overall
# - Lossless compression (dedupe, whitespace collapse) and optional aggressive elision
# - Adaptive summarization for over-budget chunks
# - Emits optional metadata JSON describing chunks and actions taken
#
# Usage:
#   bash tools/context-optimizer.sh \
#     --input path/to/input.md \
#     --output path/to/output.md \
#     --metadata-out path/to/output.meta.json \
#     --max-chunk-tokens 500 \
#     --summarize-threshold 600 \
#     --compression lossless \
#     --dedupe 1 \
#     --strip-fences 0
#
# Notes:
# - Token estimation is heuristic: ceil(chars/4). Adjust via TOKEN_DIVISOR env.
# - CRLF is normalized by removing \r before processing.
# - Aggressive compression replaces long code blocks with placeholders.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

INPUT=""
OUTPUT=""
METADATA_OUT=""
MAX_CHUNK_TOKENS=500
SUMMARIZE_THRESHOLD=800
COMPRESSION="lossless" # lossless|aggressive|none
DEDUPE=1
STRIP_FENCES=0
TOKEN_DIVISOR=${TOKEN_DIVISOR:-4}

die() { echo "[context-optimizer] error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT=${2:-}; shift 2;;
    --output) OUTPUT=${2:-}; shift 2;;
    --metadata-out) METADATA_OUT=${2:-}; shift 2;;
    --max-chunk-tokens) MAX_CHUNK_TOKENS=${2:-}; shift 2;;
    --summarize-threshold) SUMMARIZE_THRESHOLD=${2:-}; shift 2;;
    --compression) COMPRESSION=${2:-}; shift 2;;
    --dedupe) DEDUPE=${2:-}; shift 2;;
    --strip-fences) STRIP_FENCES=${2:-}; shift 2;;
    -h|--help) sed -n '1,120p' "$0" | sed 's/^# \?//'; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

[[ -n "$INPUT" ]] || die "--input is required"
[[ -f "$INPUT" ]] || die "input not found: $INPUT"

# Normalize to a temp file (strip CR)
tmp_dir="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
work_in="$tmp_dir/ctxopt.$$.in.md"
tr -d '\r' < "$INPUT" > "$work_in"

json_escape() {
  # Escape JSON special chars in a string
  # shellcheck disable=SC2001
  sed -e 's/\\/\\\\/g' -e 's/\"/\\\"/g' -e 's/\t/\\t/g' -e 's/\n/\\n/g' -e 's/\r//g'
}

estimate_tokens() {
  # Rough heuristic: ceil(chars/TOKEN_DIVISOR)
  local text=$1
  local chars
  chars=$(printf "%s" "$text" | wc -c | tr -d ' ')
  if [[ "$chars" -le 0 ]]; then echo 0; return; fi
  local div=${TOKEN_DIVISOR}
  awk -v c="$chars" -v d="$div" 'BEGIN { print int((c + d - 1)/d) }'
}

# Chunking: split by top-level headings and treat fenced code blocks as atomic units
chunk_file="$tmp_dir/ctxopt.$$.chunks"
meta_file="$tmp_dir/ctxopt.$$.meta.json"
>"$chunk_file"; >"$meta_file"

awk -v max_tokens="$MAX_CHUNK_TOKENS" -v summarize_thr="$SUMMARIZE_THRESHOLD" -v strip_fences="$STRIP_FENCES" '
  BEGIN{
    in_code=0; code_fence=""; chunk_idx=0; chunk=""; title="# (preamble)";
  }
  function flush_chunk(){
    if(length(chunk)>0){
      chunk_idx++;
      printf("---CTXOPT_CHUNK_START %d %s\n", chunk_idx, title);
      printf("%s", chunk);
      printf("\n---CTXOPT_CHUNK_END %d\n", chunk_idx);
      chunk="";
    }
  }
  {
    line=$0;
    if(!in_code && line ~ /^#{1,6} /){
      flush_chunk();
      title=line;
      next;
    }
    # fenced code blocks ``` or ~~~
    if(line ~ /^(```|~~~)/){
      if(in_code==0){ in_code=1; code_fence=line; }
      else { in_code=0; code_fence=""; if(strip_fences==1){ next; } }
    }
    chunk = chunk line "\n";
  }
  END{ flush_chunk(); }
' "$work_in" > "$chunk_file"

# Iterate chunks, compress, summarize if needed, collect metadata
out_buf=""
meta_items=""
chunk_idx=0

# Helper: lossless compress a chunk
lossless_compress() {
  # - trim trailing spaces, collapse >2 blank lines, dedupe consecutive duplicates
  awk '
    { sub(/[ \t]+$/, ""); lines[NR]=$0 }
    END{
      prev=""; blank=0;
      for(i=1;i<=NR;i++){
        l=lines[i];
        if(l==prev){ continue }
        if(l==""){
          blank++;
          if(blank>1){ continue }
        } else { blank=0 }
        print l; prev=l;
      }
    }
  '
}

# Helper: summarize a chunk heuristically
summarize_chunk() {
  # - first heading, count of list items, code blocks, approximate size
  awk '
    BEGIN{ lists=0; codes=0; in_code=0; heading=""; lines=0; }
    {
      lines++;
      if(heading=="" && $0 ~ /^#{1,6} /){ heading=$0 }
      if($0 ~ /^(```|~~~)/){ in_code = 1 - in_code; if(in_code==1){ codes++ } }
      if($0 ~ /^\s*[-*+] / || $0 ~ /^\s*[0-9]+[.)] /){ lists++ }
    }
    END{
      if(heading=="") heading="# (no heading)";
      printf("%s\\n- list_items: %d\\n- code_blocks: %d\\n- lines: %d\\n", heading, lists, codes, lines);
    }
  '
}

emit_placeholder_for_code() {
  # Replace long code blocks with a compact placeholder indicating lines
  awk '
    BEGIN{ in_code=0; buf=""; code_lines=0 }
    function flush_code(){ if(code_lines>0){ printf("[code block elided: %d lines]\n", code_lines); code_lines=0 } }
    {
      if($0 ~ /^(```|~~~)/){
        if(in_code==0){ in_code=1; next }
        else { in_code=0; flush_code(); next }
      }
      if(in_code==1){ code_lines++; next }
      print $0
    }
  '
}

while IFS= read -r line; do
  if [[ "$line" =~ ^---CTXOPT_CHUNK_START ]]; then
    # extract header
    # shellcheck disable=SC2206
    parts=($line)
    chunk_idx=${parts[1]}
    title=${parts[@]:2}
    chunk_content=""
    continue
  fi
  if [[ "$line" =~ ^---CTXOPT_CHUNK_END ]]; then
    # Process chunk_content
    raw_chunk="$chunk_content"
    tokens=$(estimate_tokens "$raw_chunk")
    action="none"
    final_chunk="$raw_chunk"

    # Optional aggressive code elision before token checks
    if [[ "$COMPRESSION" == "aggressive" ]]; then
      final_chunk=$(printf "%s" "$final_chunk" | emit_placeholder_for_code)
      action="aggressive-elide"
    fi

    # Lossless compression
    if [[ "$COMPRESSION" == "lossless" || "$COMPRESSION" == "aggressive" ]]; then
      final_chunk=$(printf "%s" "$final_chunk" | lossless_compress)
      if [[ "$action" == "none" ]]; then action="lossless"; fi
    fi

    tokens_after=$(estimate_tokens "$final_chunk")

    summary=""
    if (( tokens_after > SUMMARIZE_THRESHOLD )); then
      summary=$(printf "%s" "$final_chunk" | summarize_chunk)
      # Append summary header before the chunk, keep chunk if <= 2x over threshold; else keep summary only
      if (( tokens_after > (SUMMARIZE_THRESHOLD * 2) )); then
        final_render="[summary only]\n""$summary""\n"
        action="summary-only"
      else
        final_render="[summary]\n""$summary""\n[content]\n""$final_chunk"
        action="summary+content"
      fi
    else
      final_render="$final_chunk"
    fi

    out_buf+="$final_render\n\n"

    # Build per-chunk JSON meta
    # escape strings
    esc_title=$(printf "%s" "$title" | json_escape)
    esc_action=$(printf "%s" "$action" | json_escape)
    esc_tokens_before=$tokens
    esc_tokens_after=$tokens_after
    chunk_meta="{\"index\":$chunk_idx,\"title\":\"$esc_title\",\"action\":\"$esc_action\",\"tokens_before\":$esc_tokens_before,\"tokens_after\":$esc_tokens_after}"
    if [[ -n "$meta_items" ]]; then meta_items+=" , $chunk_meta"; else meta_items="$chunk_meta"; fi
    continue
  fi
  # accumulate
  chunk_content+="$line\n"
done < "$chunk_file"

# Dedupe entire output if requested (consecutive paragraph-level)
if [[ "$DEDUPE" == "1" ]]; then
  out_buf=$(printf "%s" "$out_buf" | awk '{ sub(/[ \t]+$/, ""); if($0==prev) next; print; prev=$0 }')
fi

# Final write
if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")" 2>/dev/null || true
  printf "%s" "$out_buf" > "$OUTPUT"
else
  printf "%s" "$out_buf"
fi

# Metadata
total_before=$(estimate_tokens "$(cat "$work_in")")
total_after=$(estimate_tokens "$out_buf")
reduction=$(
  awk -v b="$total_before" -v a="$total_after" 'BEGIN{ if(b==0){print 0} else { printf("%.2f", (b-a)*100.0/b) } }'
)
{
  printf '{"input":"%s","output":"%s","total_tokens_before":%s,"total_tokens_after":%s,"reduction_percent":%s,"chunks":[%s]}' \
    "$(printf "%s" "$INPUT" | json_escape)" \
    "$(printf "%s" "${OUTPUT:-stdout}" | json_escape)" \
    "$total_before" "$total_after" "$reduction" "$meta_items"
} > "$meta_file"

if [[ -n "$METADATA_OUT" ]]; then
  mkdir -p "$(dirname "$METADATA_OUT")" 2>/dev/null || true
  cp "$meta_file" "$METADATA_OUT"
else
  # default: if OUTPUT provided, write sibling .meta.json; else print to stderr
  if [[ -n "$OUTPUT" ]]; then
    cp "$meta_file" "${OUTPUT%.md}.meta.json" 2>/dev/null || cp "$meta_file" "$OUTPUT.meta.json"
  else
    echo "$(cat "$meta_file")" >&2
  fi
fi

exit 0
