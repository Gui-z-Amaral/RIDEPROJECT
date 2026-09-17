# Infra da VPS

Configurações que rodam na VPS (`2.24.114.7`) e que até agora só existiam lá.
Um reset da máquina levaria junto o limite de tentativas de login, a restauração
do IP real e o roteamento dos robôs de link — sem deixar rastro de como estavam.

**Isto é uma cópia para consulta e restauração, não um deploy automático.** Não
existe pipeline: alterar um arquivo aqui não muda nada no servidor. Ao mexer na
VPS, traga a alteração para cá no mesmo dia, senão a cópia vira ficção.

O que **não** está aqui, de propósito: `/root/supabase/docker/.env` (segredos) e
a chave-mestra do Vault. Ver o documento "RideApp — segredos que não podem ser
perdidos".

---

## O que é cada coisa

### `nginx/sites/`

| Arquivo | Serve | Observação |
|---|---|---|
| `app-ride` | `app.ride.dev.br` — o PWA | gzip, cache por tipo de arquivo, desvio dos robôs de link |
| `api-ride` | `api.ride.dev.br` — a API do Supabase | proxy para o Kong em `127.0.0.1:8000`, com limite nos endpoints de login |
| `supabase` | `srv1689008.hstgr.cloud` — **aposentado** | mantido só porque o certbot ainda renova o certificado; o hostname não passa pela Cloudflare e a porta 443 está fechada para ele |

Dois detalhes do `app-ride` que não são óbvios:

- **Cache longo sem `always`.** Com `always`, um 404 ficaria cacheado por 30
  dias. Já aconteceu de um favicon errado ficar preso por horas.
- **Desvio dos robôs.** WhatsApp e Telegram não executam JavaScript, então um
  app Flutter não consegue mostrar prévia de link. O `map $http_user_agent` os
  manda para a Edge Function `share`, que devolve HTML com as tags Open Graph.
  Pessoas recebem o `index.html` normal — se a função cair, perde-se a
  miniatura, não o app.

### `nginx/conf.d/`

**`cloudflare-realip.conf`** — a porta 443 só aceita a Cloudflare, então toda
conexão chega com o IP dela. Sem este arquivo, o log registraria a Cloudflare e
qualquer bloqueio por IP barraria todos os usuários de uma vez. As 22 faixas
saem de `cloudflare.com/ips-v4` e `ips-v6`; **elas mudam de vez em quando** e
precisam ser atualizadas.

**`auth-ratelimit.conf`** — limite de tentativas em login, cadastro,
recuperação de senha e conferência de código.

A parte que parece um detalhe e é o ponto todo:

```nginx
map $arg_grant_type $auth_login_key {
    default   "";
    password  $binary_remote_addr;
}
```

`/auth/v1/token` faz **duas** coisas: entrar com senha e renovar a sessão de
quem já está usando o app. Limitar o caminho inteiro derrubaria a renovação, e
o sintoma seria "o app desloga sozinho" — difícil de ligar ao firewall. A chave
vazia faz o `limit_req` **ignorar** a requisição, então renovação não é contada.

Isto está aqui e não na Cloudflare porque filtrar por query string exige o plano
Advanced Rate Limiting. Testado: 58 de 75 tentativas de login bloqueadas pelo
Nginx, e 75 de 75 passando pela borda da Cloudflare no plano gratuito.

### `systemd/` e `bin/`

**`docker-firewall`** — bloqueia acesso externo às portas do Kong (8000/8443).

Não dá para fazer isso com `ufw`: o Docker publica portas escrevendo DNAT direto
no iptables, avaliado **antes** das regras do ufw. `ufw deny 8000` não teria
efeito nenhum. A chain `DOCKER-USER` é o ponto oficial.

O bloqueio é por interface (`-i eth0`), não fechando a porta: o container
`rideapp-push-worker` vive em outra rede Docker e alcança o Kong por
`host.docker.internal:8000`. Fechar a porta mataria as notificações.

**`purge-contas`** — apaga em definitivo as contas desativadas há mais de 6
meses (migration 034). Roda uma vez por dia. Não usa `pg_cron` porque ele não
está instalado e instalá-lo exigiria reiniciar o Postgres.

---

## Restaurar numa máquina nova

```bash
# 1. Nginx
cp nginx/sites/*      /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/app-ride /etc/nginx/sites-enabled/app-ride
ln -sf /etc/nginx/sites-available/api-ride /etc/nginx/sites-enabled/api-ride
cp nginx/conf.d/*     /etc/nginx/conf.d/
nginx -t && systemctl reload nginx

# 2. Scripts e agendamentos
cp bin/*.sh /usr/local/bin/ && chmod +x /usr/local/bin/*.sh
cp systemd/* /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now docker-firewall.service purge-contas.timer
```

Os certificados **não** estão aqui. Emitir de novo:

```bash
certbot certonly --webroot -w /var/www/certbot -d api.ride.dev.br
```

O `app-ride` usa um Origin Certificate da Cloudflare em `/etc/ssl/cloudflare/`,
que é gerado no painel da Cloudflare e não pelo certbot.

---

## Estado das portas (para conferir depois de mexer)

| Porta | Deve estar |
|---|---|
| 22, 80 | aberta |
| 443 | aberta **só para as faixas da Cloudflare** |
| 5432, 6543 | fechada (Postgres escuta só em `127.0.0.1`) |
| 8000, 8443 | fechada na `eth0` pela chain `DOCKER-USER` |

Testar de fora, da sua máquina:

```bash
for p in 22 80 443 5432 6543 8000 8443; do
  timeout 5 bash -c "</dev/tcp/2.24.114.7/$p" 2>/dev/null \
    && echo "$p aberta" || echo "$p fechada"
done
```
