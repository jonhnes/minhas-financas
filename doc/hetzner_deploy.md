# Deploy na Hetzner

## DNS
- Crie um registro `A` para `financas.jonhnes.com.br` apontando para o IPv4 da VM.
- Crie um registro `AAAA` para `financas.jonhnes.com.br` apontando para o IPv6 da VM.

## Bootstrap da VM
- Execute `script/bootstrap_hetzner.sh` na VM. Se estiver logado com um usuario nao-root, passe o usuario como argumento para adiciona-lo ao grupo `docker`.
- Crie o arquivo `/opt/minhas-financas/env/backend.env` usando `deploy/backend.env.example` como base.
- Abra apenas `22/tcp`, `80/tcp` e `443/tcp` no firewall da Hetzner.

## Variaveis obrigatorias
- `APP_HOST=financas.jonhnes.com.br`
- `FRONTEND_ORIGIN=https://financas.jonhnes.com.br`
- `RAILS_MASTER_KEY=<valor de config/master.key>`
- `SECRET_KEY_BASE=<valor seguro gerado para producao>`
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- `REDIS_URL=redis://redis:6379/0`

## Segredos do GitHub
- `SSH_HOST`
- `SSH_PORT`
- `SSH_USER`
- `SSH_PRIVATE_KEY`

## Fluxo
- O deploy do backend sincroniza o repositorio para `/opt/minhas-financas/backend`.
- O script `script/deploy_production.sh` sobe `db` e `redis`, roda `db:prepare`, roda `db:seed` e sobe `web`, `worker` e `caddy`.
- O deploy do frontend sincroniza `dist/` para `/opt/minhas-financas/frontend-dist`.
