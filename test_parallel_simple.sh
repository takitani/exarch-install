#!/usr/bin/env bash
# set -euo pipefail  # Comentado para teste

# Teste simples da lógica de paralelização
echo "Teste da lógica de paralelização..."

# Simular as variáveis de configuração
INSTALL_JB_TOOLBOX=false
INSTALL_SLACK=true
INSTALL_TEAMS=true
INSTALL_CURSOR=true
INSTALL_VSCODE=true
INSTALL_WINDSURF=true
INSTALL_GOOGLE_CHROME=true
INSTALL_DROPBOX=true

# Simular arrays de controle
declare -A BACKGROUND_JOBS
declare -A JOB_NAMES
JOB_COUNTER=0

# Função simplificada para testar
start_background_job() {
  local job_name="$1"
  local pkg_name="$2"
  local install_type="$3"
  
  ((JOB_COUNTER++))
  local job_id="job_${JOB_COUNTER}"
  
  echo "🔄 Iniciando instalação em background: $job_name"
  
  # Simular job em background
  (
    sleep 3
    echo "SUCCESS:$job_name:$pkg_name:$install_type" > "/tmp/${job_id}.result"
  ) &
  
  local pid=$!
  BACKGROUND_JOBS["$job_id"]=$pid
  JOB_NAMES["$job_id"]="$job_name"
  
  echo "Job $job_id ($job_name) iniciado com PID $pid"
}

# Testar as verificações
echo "=== Testando verificações de pacotes ==="

# JetBrains Toolbox
if [[ "$INSTALL_JB_TOOLBOX" == true ]]; then
  echo "[DEBUG] Verificando JetBrains Toolbox..."
  if ! yay -Q jetbrains-toolbox &>/dev/null 2>&1; then
    echo "[DEBUG] JetBrains Toolbox não encontrado, iniciando instalação..."
    start_background_job "JetBrains Toolbox" "jetbrains-toolbox" "aur"
  else
    echo "[DEBUG] JetBrains Toolbox já instalado, pulando..."
  fi
else
  echo "[DEBUG] JetBrains Toolbox não selecionado para instalação"
fi

# Slack
if [[ "$INSTALL_SLACK" == true ]]; then
  echo "[DEBUG] Verificando Slack..."
  if ! yay -Q slack-desktop &>/dev/null 2>&1; then
    echo "[DEBUG] Slack não encontrado, iniciando instalação..."
    start_background_job "Slack" "slack-desktop" "aur"
  else
    echo "[DEBUG] Slack já instalado, pulando..."
  fi
else
  echo "[DEBUG] Slack não selecionado para instalação"
fi

# Teams
if [[ "$INSTALL_TEAMS" == true ]]; then
  echo "[DEBUG] Verificando Teams..."
  if ! yay -Q teams-for-linux &>/dev/null 2>&1; then
    echo "[DEBUG] Teams não encontrado, iniciando instalação..."
    start_background_job "Microsoft Teams" "teams-for-linux" "aur"
  else
    echo "[DEBUG] Teams já instalado, pulando..."
  fi
else
  echo "[DEBUG] Teams não selecionado para instalação"
fi

echo "=== Jobs iniciados: ${#BACKGROUND_JOBS[@]} ==="
for job_id in "${!BACKGROUND_JOBS[@]}"; do
  echo "  - ${JOB_NAMES[$job_id]} (PID: ${BACKGROUND_JOBS[$job_id]})"
done

echo "=== Aguardando conclusão ==="
wait

echo "=== Verificando resultados ==="
for job_id in "${!JOB_NAMES[@]}"; do
  if [[ -f "/tmp/${job_id}.result" ]]; then
    result=$(cat "/tmp/${job_id}.result")
    echo "✅ ${JOB_NAMES[$job_id]}: $result"
    rm -f "/tmp/${job_id}.result"
  fi
done

echo "Teste concluído!"
