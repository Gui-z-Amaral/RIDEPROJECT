#!/bin/sh
# Bloqueia acesso EXTERNO as portas do Kong (API do Supabase sem TLS).
#
# Por que aqui e nao no ufw: o Docker publica portas escrevendo DNAT direto no
# iptables, avaliado ANTES das regras do ufw — "ufw deny 8000" nao teria efeito
# nenhum. A chain DOCKER-USER e o ponto oficial para isso.
#
# Por que por interface (-i eth0) e nao por porta fechada: o container
# rideapp-push-worker vive em outra rede docker e alcanca o Kong por
# host.docker.internal:8000. Bloquear so o que entra pela placa publica mantem
# esse caminho vivo; fechar a porta mataria as notificacoes.
set -e
for p in 8000 8443; do
  iptables -C DOCKER-USER -i eth0 -p tcp --dport "$p" -j DROP 2>/dev/null \
    || iptables -I DOCKER-USER -i eth0 -p tcp --dport "$p" -j DROP
done
