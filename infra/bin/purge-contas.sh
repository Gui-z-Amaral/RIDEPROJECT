#!/bin/sh
# Apaga em definitivo as contas desativadas ha mais de 6 meses.
#
# A lei brasileira exige guardar os dados por pelo menos esse periodo, entao
# "excluir perfil" no app so DESLIGA a conta (migration 034). Este script fecha
# o ciclo. Roda como service_role via psql — a funcao e negada para anon e
# authenticated de proposito, justamente para nao poder ser disparada de fora.
#
# Nao usa pg_cron porque ele nao esta instalado e exigiria reiniciar o Postgres.
LOG=/var/log/purge-contas.log
N=$(docker exec supabase-db psql -U supabase_admin -d postgres -t -A \
      -c "SELECT public.purge_deactivated_accounts();" 2>&1)
echo "$(date -Is) apagadas: $N" >> "$LOG"
