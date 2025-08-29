#!/usr/bin/env bash
set -euo pipefail

# Teste do problema de paralelização
echo "Testando verificação de pacotes..."

# Simular a verificação que está no script
if ! yay -Q teams-for-linux &>/dev/null 2>&1; then
    echo "teams-for-linux não está instalado - deveria instalar"
else
    echo "teams-for-linux está instalado - deveria pular"
fi

if ! yay -Q visual-studio-code-bin &>/dev/null 2>&1; then
    echo "visual-studio-code-bin não está instalado - deveria instalar"
else
    echo "visual-studio-code-bin está instalado - deveria pular"
fi

if ! yay -Q windsurf-bin &>/dev/null 2>&1; then
    echo "windsurf-bin não está instalado - deveria instalar"
else
    echo "windsurf-bin está instalado - deveria pular"
fi

echo "Teste concluído"
