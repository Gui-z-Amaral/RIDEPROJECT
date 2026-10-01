# RideApp — pausado em 01/10/2026

O app foi pausado depois do Programa Nascer 2026. Este arquivo diz onde está
cada coisa e como subir tudo de novo.

**Prazo de guarda dos dados pessoais: até 01/04/2027.** Se o app não voltar
até lá, os dados dos usuários precisam ser apagados (ver "Apagar de vez").
Contato informado aos usuários: comercial@rideapp.cloud

---

## Onde está cada coisa

| O quê | Onde |
|---|---|
| Código | este repositório, tag `v1-pausado` |
| Backup do banco, fotos e configs | fora do Git, guardado pelo Guilherme em dois lugares (ver abaixo) |
| Configs do Nginx, systemd e scripts da VPS | `infra/` neste repositório |
| Migrations | `ride_app/supabase/migrations/` (001 a 046, e `_BUNDLE.sql`) |
| Edge Functions | `ride_app/supabase/functions/` (`gmaps`, `share`, `quarentena`) |

### O backup (fora do Git, de propósito)

Contém dados pessoais de usuários reais e a chave do chat. **Nunca** colocar
em repositório, drive compartilhado ou qualquer lugar público.

| Arquivo | O que é | Se perder |
|---|---|---|
| `banco.sql.gz` | o Postgres inteiro (`pg_dumpall`) | perde-se todo o dado |
| `pgsodium_root.key` | chave-mestra do Vault | **o chat fica ilegível para sempre** |
| `storage.tar.gz` | fotos (avatares, viagens, chat, quarentena) | perdem-se as fotos |
| `supabase-env` | o `.env` do Supabase (JWT secret, service_role, senhas) | dá para gerar outro, mas toda sessão e chave muda |
| `docker-compose.yml` | como os containers sobem | dá para pegar o padrão do Supabase de novo |
| `SHA256SUMS` | impressões digitais de tudo acima | — |

Conferir que o backup está íntegro:

```
sha256sum -c SHA256SUMS
```

---

## Como retomar

1. VPS nova (Ubuntu + Docker). Instalar o Supabase self-hosted
   (`supabase/docker` do repositório oficial).
2. Copiar `supabase-env` para `.env` e `docker-compose.yml` para o lugar.
3. **Antes de subir o banco**, pôr a `pgsodium_root.key` no volume
   `supabase_db-config` (`/etc/postgresql-custom/pgsodium_root.key` dentro do
   container). Sem ela, o Vault cria uma chave nova e o chat antigo não abre.
4. `docker compose up -d`, depois restaurar o banco:
   `gunzip -c banco.sql.gz | docker exec -i supabase-db psql -U supabase_admin -d postgres`
5. Restaurar as fotos: extrair `storage.tar.gz` em `volumes/storage`.
6. Copiar `ride_app/supabase/functions/*` para `volumes/functions/`.
7. Nginx e firewall: seguir `infra/README.md`.
8. Chaves do Google Maps: foram apagadas na pausa. Criar novas e seguir o
   arquivo "RideApp - Keystore e publicacao.md".
9. Apontar o DNS de `api.ride.dev.br` e `app.ride.dev.br` para a VPS nova.

---

## Apagar de vez (se não retomar até 01/04/2027)

Apagar **todas** as cópias do backup, inclusive as duas guardadas fora do
computador. O dado dos usuários deixa de existir quando a última cópia some.
