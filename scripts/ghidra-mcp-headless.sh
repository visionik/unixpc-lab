#!/usr/bin/env bash
# Start bethington/ghidra-mcp GhidraMCPHeadlessServer against the local
# win3b-ether project (ether.o). Default: bind 127.0.0.1:8089.
#
# Usage:
#   scripts/ghidra-mcp-headless.sh              # project + ether.o
#   scripts/ghidra-mcp-headless.sh --no-project # empty server
#   GHIDRA_MCP_PORT=8090 scripts/ghidra-mcp-headless.sh
set -euo pipefail

GHIDRA_HOME="${GHIDRA_HOME:-$HOME/Tools/ghidra_12.1.4_PUBLIC}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
JAVA="${JAVA_HOME}/bin/java"
JAR="${GHIDRA_MCP_JAR:-/tmp/ghidra-mcp/target/GhidraMCP-7.0.0.jar}"
PORT="${GHIDRA_MCP_PORT:-8089}"
BIND="${GHIDRA_MCP_BIND_ADDRESS:-127.0.0.1}"
PROJECT_DIR="${GHIDRA_PROJECT_DIR:-$HOME/Projects/unixpc-lab/re/ghidra}"
PROJECT_NAME="${GHIDRA_PROJECT_NAME:-win3b-ether}"
PROGRAM_NAME="${GHIDRA_PROGRAM_NAME:-ether.o}"
JAVA_OPTS="${JAVA_OPTS:--Xmx4g -XX:+UseG1GC}"
LOAD_PROJECT=1

for arg in "$@"; do
  case "$arg" in
    --no-project) LOAD_PROJECT=0 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

if [[ ! -x "$JAVA" ]]; then
  echo "error: java not found at $JAVA (brew install openjdk@21)" >&2
  exit 1
fi
if [[ ! -d "$GHIDRA_HOME/Ghidra" ]]; then
  echo "error: GHIDRA_HOME invalid: $GHIDRA_HOME" >&2
  exit 1
fi
if [[ ! -f "$JAR" ]]; then
  echo "error: GhidraMCP jar missing: $JAR" >&2
  echo "build: cd /tmp/ghidra-mcp && mvn -q -DskipTests package" >&2
  exit 1
fi
if [[ ! -x "$GHIDRA_HOME/Ghidra/Features/Decompiler/os/mac_arm_64/decompile" ]]; then
  echo "error: mac_arm_64 decompile native missing under GHIDRA_HOME" >&2
  echo "fix: cd \$GHIDRA_HOME/support/gradle && ./gradlew buildNatives" >&2
  echo "then copy Features/*/build/os/mac_arm_64 -> Features/*/os/mac_arm_64" >&2
  exit 1
fi

CLASSPATH="$JAR"
for jar in "$GHIDRA_HOME"/Ghidra/Framework/*/lib/*.jar; do
  CLASSPATH="${CLASSPATH}:${jar}"
done
for jar in "$GHIDRA_HOME"/Ghidra/Features/*/lib/*.jar; do
  CLASSPATH="${CLASSPATH}:${jar}"
done
for jar in "$GHIDRA_HOME"/Ghidra/Processors/*/lib/*.jar; do
  CLASSPATH="${CLASSPATH}:${jar}"
done

GPR="$PROJECT_DIR/${PROJECT_NAME}.gpr"
ARGS=(--port "$PORT" --bind "$BIND")
if [[ "$LOAD_PROJECT" -eq 1 ]]; then
  if [[ ! -f "$GPR" ]]; then
    echo "error: project marker missing: $GPR" >&2
    exit 1
  fi
  # Pass the .gpr (or its parent dir). ProjectLocator wants parent + name.
  ARGS+=(--project "$GPR" --program "$PROGRAM_NAME")
fi

echo "GhidraMCPHeadlessServer"
echo "  GHIDRA_HOME=$GHIDRA_HOME"
echo "  JAR=$JAR"
echo "  bind=$BIND port=$PORT"
if [[ "$LOAD_PROJECT" -eq 1 ]]; then
  echo "  project=$GPR program=$PROGRAM_NAME"
fi

exec "$JAVA" \
  $JAVA_OPTS \
  -Duser.name="${GHIDRA_USER:-$(whoami)}" \
  -Dghidra.home="$GHIDRA_HOME" \
  -Dapplication.name=GhidraMCP \
  -classpath "$CLASSPATH" \
  com.xebyte.headless.GhidraMCPHeadlessServer \
  "${ARGS[@]}"
