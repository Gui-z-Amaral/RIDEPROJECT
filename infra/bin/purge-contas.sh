#!/bin/sh
# Limpeza diária de dados que passaram do prazo.
#
# 1. Contas desativadas há mais de 6 meses: "excluir perfil" no app só DESLIGA
#    a conta (migration 034) e manda as fotos para o bucket privado
#    `quarentena` (migration 043). Aqui o ciclo fecha. Passa pela Edge Function
#    `quarentena`, e não direto pelo banco, porque os ARQUIVOS precisam ser
#    apagados pela API do Storage antes da conta — apagar só a linha do banco
#    deixaria a foto órfã no disco.
# 2. Posição de GPS parada há mais de 12 h (rolê que nunca foi encerrado).
#
# A chave service_role é lida do .env do Supabase NA VPS: ela nunca sai do
# servidor. Kong escuta só em 127.0.0.1 (ver docker-firewall), então a chamada
# não passa pela internet.
#
# Nao usa pg_cron porque ele nao esta instalado e exigiria reiniciar o Postgres.
LOG=/var/log/purge-contas.log
ENV=/root/supabase/docker/.env
KEY=$(grep '^SERVICE_ROLE_KEY=' "$ENV" | cut -d= -f2-)

if [ -z "$KEY" ]; then
  echo "$(date -Is) ERRO: SERVICE_ROLE_KEY nao encontrada em $ENV" >> "$LOG"
  exit 1
fi

CONTAS=$(curl -s -m 600 -X POST http://127.0.0.1:8000/functions/v1/quarentena \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"acao":"apagar"}' 2>&1)

GPS=$(docker exec supabase-db psql -U supabase_admin -d postgres -t -A \
      -c "SELECT public.purge_gps_antigo();" 2>&1)

echo "$(date -Is) contas: $CONTAS | gps apagados: $GPS" >> "$LOG"
