#!/usr/bin/env bash
# context-estimator.sh - Estimates context size and tracks efficiency metrics
# Usage: source context-estimator.sh
#        ce_start_profiling [session_name]
#        ce_track_file "file_path" "operation_type"
#        ce_track_operation "operation_name" "type" (script|ai)
#        ce_end_profiling
#
# Enable with ENABLE_PROFILING=1 environment variable
# Example: ENABLE_PROFILING=1 ./run-create-spec.sh input.md

set -eo pipefail

# Global variables for storing metrics
CE_PROFILING_ENABLED=${ENABLE_PROFILING:-0}
CE_SESSION_NAME="default"
CE_SESSION_START_TIME=0
CE_TOTAL_CHARS=0
CE_ESTIMATED_TOKENS=0
CE_AI_OPERATIONS=0
CE_SCRIPT_OPERATIONS=0
CE_OPERATIONS=()
CE_FILES=()
CE_LOG_FILE=""

# Constants
CE_CHAR_TO_TOKEN_RATIO=4  # Approximate ratio (can be adjusted)
CE_LOG_DIR=".agent-os/logs/profiling"

# Initialize profiling session
ce_start_profiling() {
  if [[ $CE_PROFILING_ENABLED -ne 1 ]]; then
    return 0
  fi
  
  # Create a session name based on date/time if not provided
  CE_SESSION_NAME="${1:-$(date +"%Y%m%d_%H%M%S")}"
  CE_SESSION_START_TIME=$(date +%s)
  
  # Create log directory if it doesn't exist
  mkdir -p "$CE_LOG_DIR"
  CE_LOG_FILE="$CE_LOG_DIR/$CE_SESSION_NAME.log"
  
  # Initialize log file
  {
    echo "=== Context Estimator Profiling ==="
    echo "Session: $CE_SESSION_NAME"
    echo "Started: $(date)"
    echo "==================================="
    echo ""
  } > "$CE_LOG_FILE"
  
  echo "[context-estimator] Profiling enabled for session '$CE_SESSION_NAME'"
}

# Track a file that's being processed
ce_track_file() {
  if [[ $CE_PROFILING_ENABLED -ne 1 ]]; then
    return 0
  fi
  
  local file_path="$1"
  local operation_type="$2"
  local file_size=0
  local char_count=0
  local token_estimate=0
  
  if [[ -f "$file_path" ]]; then
    file_size=$(stat --format=%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0")
    char_count=$(wc -m < "$file_path" 2>/dev/null || echo "0")
    token_estimate=$(( char_count / CE_CHAR_TO_TOKEN_RATIO ))
    
    CE_TOTAL_CHARS=$((CE_TOTAL_CHARS + char_count))
    CE_ESTIMATED_TOKENS=$((CE_ESTIMATED_TOKENS + token_estimate))
    
    # Record file info
    CE_FILES+=("$file_path,$operation_type,$file_size,$char_count,$token_estimate")
    
    # Log the file tracking
    {
      echo "[$(date +"%H:%M:%S")] Tracked file: $file_path"
      echo "  - Operation: $operation_type"
      echo "  - Size: $file_size bytes"
      echo "  - Characters: $char_count"
      echo "  - Est. tokens: $token_estimate"
      echo ""
    } >> "$CE_LOG_FILE"
  fi
}

# Track an operation (AI or script)
ce_track_operation() {
  if [[ $CE_PROFILING_ENABLED -ne 1 ]]; then
    return 0
  fi
  
  local operation_name="$1"
  local operation_type="$2" # "ai" or "script"
  local start_time=$(date +%s%N)
  
  # Increment counters
  if [[ "$operation_type" == "ai" ]]; then
    CE_AI_OPERATIONS=$((CE_AI_OPERATIONS + 1))
  elif [[ "$operation_type" == "script" ]]; then
    CE_SCRIPT_OPERATIONS=$((CE_SCRIPT_OPERATIONS + 1))
  fi
  
  # Return the operation ID (used for ending the operation)
  echo "$((${#CE_OPERATIONS[@]} + 1))"
  
  # Store operation details
  CE_OPERATIONS+=("$operation_name,$operation_type,$start_time,0")
  
  # Log the operation start
  {
    echo "[$(date +"%H:%M:%S")] Started $operation_type operation: $operation_name"
  } >> "$CE_LOG_FILE"
}

# End tracking an operation
ce_end_operation() {
  if [[ $CE_PROFILING_ENABLED -ne 1 ]]; then
    return 0
  fi
  
  local operation_id="$1"
  local end_time=$(date +%s%N)
  
  # Get the operation details
  IFS=',' read -r name type start_time _ <<< "${CE_OPERATIONS[$operation_id-1]}"
  
  # Calculate duration in milliseconds
  local duration_ns=$((end_time - start_time))
  local duration_ms=$((duration_ns / 1000000))
  
  # Update the operation with end time
  CE_OPERATIONS[$operation_id-1]="$name,$type,$start_time,$duration_ms"
  
  # Log the operation end
  {
    echo "[$(date +"%H:%M:%S")] Completed $type operation: $name"
    echo "  - Duration: $duration_ms ms"
    echo ""
  } >> "$CE_LOG_FILE"
}

# End profiling and generate report
ce_end_profiling() {
  if [[ $CE_PROFILING_ENABLED -ne 1 ]]; then
    return 0
  fi
  
  local end_time=$(date +%s)
  local total_duration=$((end_time - CE_SESSION_START_TIME))
  local script_ops_pct=0
  local ai_ops_pct=0
  local total_ops=$((CE_SCRIPT_OPERATIONS + CE_AI_OPERATIONS))
  
  if [[ $total_ops -gt 0 ]]; then
    script_ops_pct=$((CE_SCRIPT_OPERATIONS * 100 / total_ops))
    ai_ops_pct=$((CE_AI_OPERATIONS * 100 / total_ops))
  fi
  
  # Generate the final report
  {
    echo ""
    echo "=== Profiling Summary ==="
    echo "Session: $CE_SESSION_NAME"
    echo "Duration: $total_duration seconds"
    echo ""
    echo "Context Metrics:"
    echo "  - Total characters processed: $CE_TOTAL_CHARS"
    echo "  - Estimated tokens: $CE_ESTIMATED_TOKENS"
    echo ""
    echo "Operation Metrics:"
    echo "  - Script operations: $CE_SCRIPT_OPERATIONS ($script_ops_pct%)"
    echo "  - AI operations: $CE_AI_OPERATIONS ($ai_ops_pct%)"
    echo ""
    echo "Files Tracked:"
    for file_info in "${CE_FILES[@]}"; do
      IFS=',' read -r path op size chars tokens <<< "$file_info"
      echo "  - $path ($op): $size bytes, ~$tokens tokens"
    done
    echo ""
    echo "=== End of Profiling ==="
  } >> "$CE_LOG_FILE"
  
  echo "[context-estimator] Profiling completed for session '$CE_SESSION_NAME'"
  echo "[context-estimator] Report saved to $CE_LOG_FILE"
}

# Helper function to human-readable file sizes
ce_human_readable_size() {
  local bytes=$1
  if [[ $bytes -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ $bytes -lt 1048576 ]]; then
    echo "$((bytes/1024))KB"
  else
    echo "$((bytes/1048576))MB"
  fi
}

# Initialize if profiling is enabled
if [[ $CE_PROFILING_ENABLED -eq 1 ]]; then
  ce_start_profiling
fi
