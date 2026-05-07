#!/bin/bash

# =========================================================
# Lightweight EC2 Incident Response Detection Script
# =========================================================
# Flow:
# Detection → Severity Scoring → Lambda Alerting
#
# Current Model:
# - Reactive heuristic-based detection
# - Correlation-aware scoring
# - Reduced false positives for normal admin activity
#
# Future Improvements:
# - Behavioral detection
# - Baseline deviation analysis
# - Threat intelligence enrichment
# =========================================================

# ===== CONFIG =====
REGION="us-east-1"
LAMBDA_NAME="SeverityParser"

# ===== EC2 METADATA =====
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

if [[ ! "$INSTANCE_ID" =~ ^i- ]]; then
  echo "❌ Failed to fetch instance ID"
  exit 1
fi

echo "🚨 IR started for instance: $INSTANCE_ID"

# =========================================================
# INITIALIZATION
# =========================================================

SCORE=0
SIGNALS=()

# Detection State Flags
ROOT_ACTIVE=false
SUSPICIOUS_PROCESS=false
REVERSE_SHELL=false
OUTBOUND_CONNECTION=false

# =========================================================
# STEP 1: FORENSIC COLLECTION
# =========================================================

echo "📦 Collecting system information..."

WHOAMI=$(whoami)
UPTIME=$(uptime)
PROCESSES=$(ps aux)
NETWORK=$(netstat -tulnp 2>/dev/null)
LOGINS=$(last -n 10)

# =========================================================
# STEP 2: DETECTION LOGIC
# =========================================================

# ---------------------------------------------------------
# Root User Activity
# Weak standalone signal
# ---------------------------------------------------------
if [[ "$WHOAMI" == "root" ]]; then
    ROOT_ACTIVE=true
fi

# ---------------------------------------------------------
# Reverse Shell Detection
# Strong signal
# ---------------------------------------------------------
if echo "$PROCESSES" | grep -E "bash -i|/dev/tcp|nc -e|python.*socket" >/dev/null; then
    REVERSE_SHELL=true
    SIGNALS+=("Reverse shell pattern detected")
fi

# ---------------------------------------------------------
# Suspicious Process Detection
# Medium-strength heuristic
# ---------------------------------------------------------
if echo "$PROCESSES" | grep -E "nc " >/dev/null; then
    SUSPICIOUS_PROCESS=true
fi

# ---------------------------------------------------------
# Active Outbound Connections
# Weak standalone signal
# ---------------------------------------------------------
if echo "$NETWORK" | grep ESTABLISHED >/dev/null; then
    OUTBOUND_CONNECTION=true
fi

# ---------------------------------------------------------
# Multiple Recent Logins
# Minor contextual signal
# ---------------------------------------------------------
LOGIN_COUNT=$(echo "$LOGINS" | wc -l)

if [ "$LOGIN_COUNT" -gt 5 ]; then
    SCORE=$((SCORE+1))
    SIGNALS+=("Multiple recent logins detected")
fi

# =========================================================
# STEP 3: CONTEXT-AWARE SCORING
# =========================================================

# ---------------------------------------------------------
# Strong Signals
# ---------------------------------------------------------
if [ "$REVERSE_SHELL" = true ]; then
    SCORE=$((SCORE+5))
fi

# ---------------------------------------------------------
# Medium Signals
# ---------------------------------------------------------
if [ "$SUSPICIOUS_PROCESS" = true ]; then
    SCORE=$((SCORE+2))
    SIGNALS+=("Suspicious process pattern detected")
fi

# ---------------------------------------------------------
# Weak Signals
# ---------------------------------------------------------
if [ "$ROOT_ACTIVE" = true ]; then
    SCORE=$((SCORE+1))
    SIGNALS+=("Root user activity detected")
fi

if [ "$OUTBOUND_CONNECTION" = true ]; then
    SCORE=$((SCORE+1))
    SIGNALS+=("Active outbound connections detected")
fi

# =========================================================
# STEP 4: SIGNAL CORRELATION
# =========================================================

# Root + suspicious process correlation
if [ "$ROOT_ACTIVE" = true ] && [ "$SUSPICIOUS_PROCESS" = true ]; then
    SCORE=$((SCORE+2))
    SIGNALS+=("Root + suspicious process correlation")
fi

# Reverse shell + network activity correlation
if [ "$REVERSE_SHELL" = true ] && [ "$OUTBOUND_CONNECTION" = true ]; then
    SCORE=$((SCORE+2))
    SIGNALS+=("Reverse shell + outbound connection correlation")
fi

# =========================================================
# STEP 5: SEVERITY CLASSIFICATION
# =========================================================

if [ "$SCORE" -ge 8 ]; then
    SEVERITY="CRITICAL"

elif [ "$SCORE" -ge 5 ]; then
    SEVERITY="HIGH"

elif [ "$SCORE" -ge 3 ]; then
    SEVERITY="MEDIUM"

else
    SEVERITY="LOW"
fi

echo "📊 Severity: $SEVERITY (Score: $SCORE)"

# =========================================================
# STEP 6: BUILD JSON PAYLOAD
# =========================================================

SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" \
  | sed 's/"/\\"/g' \
  | awk '{print "\"" $0 "\""}' \
  | paste -sd "," -)

SIGNALS_JSON="[${SIGNALS_JSON}]"

PAYLOAD=$(cat <<EOF
{
  "instance_id": "$INSTANCE_ID",
  "severity": "$SEVERITY",
  "score": $SCORE,
  "details": $SIGNALS_JSON
}
EOF
)

echo "📤 Sending payload to Lambda..."
echo "$PAYLOAD"

# =========================================================
# STEP 7: LAMBDA INVOCATION
# =========================================================

aws lambda invoke \
  --function-name "$LAMBDA_NAME" \
  --region "$REGION" \
  --cli-binary-format raw-in-base64-out \
  --payload "$PAYLOAD" \
  /tmp/lambda_output.json >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Lambda invocation successful"
else
    echo "❌ Lambda invocation failed"
fi

echo "✅ IR Detection Workflow Completed"
