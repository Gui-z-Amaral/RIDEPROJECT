#!/bin/sh
# Bloqueia acesso EXTERNO as portas do Kong (API do Supabase sem TLS).
#
# Por que aqui e nao no ufw: o Docker publica portas escrevendo DNAT direto no
# iptables, avaliado ANTES das regras do ufw — "ufw deny 8000" nao teria efeito
# nenhum. A chain DOCKER-USER e o ponto oficial para isso.
#
# Por que por interface (-i eth0) e nao fechando a porta: o container
# rideapp-push-worker vive em outra rede docker e alcanca o Kong por
# host.docker.internal:8000. Fechar a porta mataria as notificacoes.
#
# A ESPERA ABAIXO E ESSENCIAL. O systemd so garante que o docker INICIOU, nao
# que ele ja criou a chain DOCKER-USER. Sem esperar, o script falhava no boot e
# as portas ficavam ABERTAS para a internet ate alguem perceber.
set -e

i=0
while ! iptables -L DOCKER-USER -n >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "DOCKER-USER nao apareceu em 60s — regras NAO aplicadas" >&2
    exit 1
  fi
  sleep 1
done

for p in 8000 8443; do
  iptables -C DOCKER-USER -i eth0 -p tcp --dport "$p" -j DROP 2>/dev/null \
    || iptables -I DOCKER-USER -i eth0 -p tcp --dport "$p" -j DROP
done
echo "regras aplicadas apos ${i}s de espera"
