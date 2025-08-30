#!/usr/bin/env bash

# Script de teste para detectar os diferentes estados do 1Password CLI
# Usado para debugging e verificação dos padrões de output

echo "=== Teste de Detecção de Estados do 1Password ==="
echo

# Teste 1: Verificar o output atual
echo "1. Output atual do 'op account list':"
echo "---"
op account list 2>&1 || true
echo "---"
echo "Exit code: $?"
echo

# Teste 2: Verificar se contém "No accounts configured"
echo "2. Testando padrão 'No accounts configured':"
output=$(op account list 2>&1)
if echo "$output" | grep -q "No accounts configured"; then
    echo "✓ Detectado: Nenhuma conta configurada"
else
    echo "✗ Padrão não encontrado"
fi
echo

# Teste 3: Verificar se contém headers de tabela
echo "3. Testando padrão de contas existentes (URL|Shorthand):"
if echo "$output" | grep -q "URL\|Shorthand"; then
    echo "✓ Detectado: Contas configuradas"
else
    echo "✗ Contas não detectadas"
fi
echo

# Teste 4: Verificar diferentes variações do output
echo "4. Análise completa do output:"
echo "Número de linhas: $(echo "$output" | wc -l)"
echo "Primeira linha: '$(echo "$output" | head -1)'"
echo "Última linha: '$(echo "$output" | tail -1)'"
echo

# Teste 5: Verificar se pode listar vaults (autenticado)
echo "5. Teste de autenticação (op vault list):"
if op vault list >/dev/null 2>&1; then
    echo "✓ Autenticado - pode listar vaults"
else
    echo "✗ Não autenticado ou sem contas"
fi
echo

# Teste 6: Testar format JSON
echo "6. Teste formato JSON:"
json_output=$(op account list --format=json 2>&1)
echo "JSON output: $json_output"
if [[ "$json_output" == "[]" ]]; then
    echo "✓ JSON vazio - sem contas"
elif echo "$json_output" | jq . >/dev/null 2>&1; then
    echo "✓ JSON válido com contas"
    echo "Número de contas: $(echo "$json_output" | jq length)"
else
    echo "✗ Não é JSON válido"
fi
echo

echo "=== Recomendação para detecção ==="
echo "Baseado nos testes acima, o melhor método é:"
echo
if echo "$output" | grep -q "No accounts configured"; then
    echo "→ Usar: grep 'No accounts configured'"
    echo "→ Status: SEM CONTAS"
elif echo "$output" | grep -q "URL\|Shorthand"; then
    echo "→ Usar: grep 'URL\|Shorthand'"
    echo "→ Status: COM CONTAS"
    if op vault list >/dev/null 2>&1; then
        echo "→ Autenticação: LOGADO"
    else
        echo "→ Autenticação: PRECISA LOGAR"
    fi
else
    echo "→ Caso não identificado - usar fallback"
    echo "→ Output completo para análise:"
    echo "$output"
fi