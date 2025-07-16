#!/bin/bash

PEM="./wallet.pem"
PROXY="https://devnet-api.multiversx.com"
CHAIN="D"
CONTRATOS_FILE="contratos.txt"

hex_to_decimal() {
  python3 -c "print(int('$1', 16))"
}

timestamp_to_date() {
  date -d "@$1" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$1"
}

crear_contrato() {
  read -p "Introduce el número de días en los que se permite votar este trabajo: " dias
  if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
    echo "Entrada inválida."
    return
  fi
  deadline=$(($(date +%s) + dias*24*3600))

  OUTPUT=$(mxpy contract deploy \
    --bytecode ./output/evaluacion-estrellas.wasm \
    #--project . \
    --pem "$PEM" \
    #--recall-nonce \
    --gas-limit=60000000 \
    --arguments $deadline \
    --proxy "$PROXY" \
    --chain "$CHAIN" \
    --send \
    --outfile="deploy.json")

  direccion=$(cat deploy.json | grep contractAddress | cut -d '"' -f4)
  autor=$(mxpy wallet pem-address "$PEM")
  echo "$direccion;$autor;$deadline" >> "$CONTRATOS_FILE"
  echo "Contrato desplegado: $direccion"
}

listar_disponibles() {
  echo "=== Contratos disponibles ==="
  mi_address=$(mxpy wallet pem-address "$PEM")
  ahora=$(date +%s)

  while IFS=";" read -r direccion autor fin; do
    if [[ "$mi_address" == "$autor" ]]; then
      continue
    fi
    if (( ahora > fin )); then
      continue
    fi
    ya_votado=$(mxpy contract query "$direccion" --function votantes --arguments "$mi_address" --proxy "$PROXY" 2>/dev/null)
    if [[ "$ya_votado" == *"01"* ]]; then
      continue
    fi
    media=$(mxpy contract query "$direccion" --function getMedia --proxy "$PROXY" 2>/dev/null)
    total=$(mxpy contract query "$direccion" --function getTotal --proxy "$PROXY" 2>/dev/null)
    media_val=$(hex_to_decimal $(echo $media | grep -o '"[^"]*"' | tr -d '"'))
    total_val=$(hex_to_decimal $(echo $total | grep -o '"[^"]*"' | tr -d '"'))
    echo "Contrato: $direccion | Media: $media_val | Votos: $total_val | Expira: $(timestamp_to_date "$fin")"
  done < "$CONTRATOS_FILE"
}

votar() {
  read -p "Dirección del contrato al que deseas votar: " direccion
  read -p "Introduce tu voto (1 a 5): " voto
  if ! [[ "$voto" =~ ^[1-5]$ ]]; then
    echo "Voto inválido."
    return
  fi
  mxpy contract call "$direccion" --function votar --arguments "$voto" --pem "$PEM" \
    --proxy "$PROXY" --chain "$CHAIN" --gas-limit=5000000 --send
}

ranking() {
  echo "=== Ranking de contratos ==="
  while IFS=";" read -r direccion autor fin; do
    media=$(mxpy contract query "$direccion" --function getMedia --proxy "$PROXY" 2>/dev/null)
    total=$(mxpy contract query "$direccion" --function getTotal --proxy "$PROXY" 2>/dev/null)
    media_val=$(hex_to_decimal $(echo $media | grep -o '"[^"]*"' | tr -d '"'))
    total_val=$(hex_to_decimal $(echo $total | grep -o '"[^"]*"' | tr -d '"'))
    echo "$media_val estrellas | $total_val votos | $direccion"
  done < "$CONTRATOS_FILE" | sort -r
}

while true; do
  echo ""
  echo "===== Menú de Evaluación Blockchain ====="
  echo "1) Crear nuevo contrato evaluable"
  echo "2) Votar un contrato pendiente"
  echo "3) Ver contratos disponibles para votar"
  echo "4) Ver ranking de contratos"
  echo "0) Salir"
  echo "========================================="
  read -p "Elige una opción: " opcion

  case $opcion in
    1) crear_contrato ;;
    2) votar ;;
    3) listar_disponibles ;;
    4) ranking ;;
    0) echo "¡Hasta luego!"; break ;;
    *) echo "Opción no válida." ;;
  esac
done
