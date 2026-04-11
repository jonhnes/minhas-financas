# AGENTS.md

## Visao Geral
- Este repositorio e o backend de `Minhas Financas`, uma API Rails para contas, cartoes, categorias, transacoes, orcamentos, recorrencias, faturas e importacao de extratos em PDF.
- O projeto frontend está na pasta acima no repositorio `minhas-finanças-frontend`.
- O projeto mobile está na pasta acima no repositorio `minhas-financas-mobile`.
- O `README.md` ainda esta generico. Use este arquivo, o codigo fonte e os arquivos em `doc/` como contexto inicial.
- Se houver conflito entre documentacao e testes/codigo, siga o comportamento coberto pelos testes e implementado no app.

## Stack E Ambiente
- Ruby `3.4.2`
- Rails `8.0.2`
- PostgreSQL como banco principal
- Redis e Sidekiq disponiveis para filas, mas em `development` e `test` o default atual de `ActiveJob` e `inline`
- Devise para autenticacao por sessao
- Pundit para autorizacao
- Active Storage para upload de PDF
- RSpec + FactoryBot + Shoulda Matchers
- Locale default `pt-BR` e timezone default `America/Sao_Paulo`

## Setup Rapido
- Exporte as variaveis de ambiente usando os valores-base de `.env.example`
- Suba dependencias locais com `docker compose up -d postgres redis`
- Instale gems com `bundle install`
- Prepare banco com `bin/rails db:prepare`
- Popule categorias de sistema com `bin/rails db:seed`
- Rode o servidor com `bin/dev`
- Rode a suite inteira com `bundle exec rspec`
- Se voce trocar `ACTIVE_JOB_QUEUE_ADAPTER` para `sidekiq`, rode tambem `bundle exec sidekiq -C config/sidekiq.yml`

## Mapa Do Projeto
- `app/controllers/api/v1`: endpoints JSON da aplicacao
- `app/serializers/api/v1/serializers.rb`: shape das respostas da API
- `app/policies`: autorizacao e scoping por usuario
- `app/services/imports`: pipeline de importacao e confirmacao de faturas
- `app/services/recurring_rules`: materializacao de lancamentos recorrentes
- `app/queries/reports`: regras de agregacao e relatorios
- `lib/parsers/statements`: parsers de PDF por banco/emissor
- `doc/`: PDFs reais e documentos de produto/tecnico usados como referencia

## Regras Criticas Do Dominio
- Tudo e multi-tenant. Sempre use `policy_scope`, `current_user` e helpers de lookup antes de buscar registros sensiveis.
- Nao troque um lookup escopado por `Model.find(params[:id])` em recursos que pertencem ao usuario.
- Categorias podem ser do usuario ou categorias de sistema. Categorias de sistema usam `user_id: nil` e `system: true`.
- `Transaction` precisa ter `account` ou `credit_card`.
- `Transaction` que nao e transferencia nao pode usar `account` e `credit_card` ao mesmo tempo.
- `Transaction` de transferencia exige `account` e `transfer_account`, e nao pode usar `credit_card`.
- `Transaction` que nao e transferencia exige `category`.
- Compras no cartao nao entram diretamente no saldo consolidado de caixa.
- `impact_mode` com valor `third_party` ou `informational` costuma ser excluido dos relatorios por padrao.
- `RecurringRule` exige `account` ou `credit_card`, nunca ambos.
- O materializador de recorrencias nao deve gerar duas transacoes automaticas da mesma regra na mesma data.
- Um `Import` so pode ser confirmado quando esta em `review_pending`, ainda nao possui `statement`, e todos os itens nao ignorados possuem categoria.
- A confirmacao de importacao cria `Statement`, cria `Transaction` para cada item valido e atualiza o `Import` na mesma transacao de banco.
- Nao permita faturas duplicadas para o mesmo cartao e periodo.

## Fluxos Mais Sensiveis
- Autenticacao do frontend usa cookie de sessao + CSRF, nao JWT.
- O token CSRF vem de `GET /api/v1/auth/csrf` e deve seguir no header `X-CSRF-Token`.
- CORS permite `FRONTEND_ORIGIN` com `credentials: true`.
- `BaseController` forca `request.format = :json`; mantenha respostas consistentes com os serializers.
- O fluxo de importacao e: upload do PDF -> processamento em background -> revisao dos itens -> confirmacao da fatura.
- Os providers suportados hoje sao `inter_pdf` e `bradesco_pdf`.

## Como Testar Mudancas
- Prefira rodar specs focados antes da suite inteira.
- Para importacao/faturas:
  - `bundle exec rspec spec/requests/api/v1/imports_spec.rb`
  - `bundle exec rspec spec/services/imports/confirm_import_spec.rb`
  - `bundle exec rspec spec/lib/parsers/statements/inter_pdf_parser_spec.rb`
  - `bundle exec rspec spec/lib/parsers/statements/bradesco_pdf_parser_spec.rb`
- Para relatorios e semantica financeira:
  - `bundle exec rspec spec/queries/reports/overview_query_spec.rb`
  - `bundle exec rspec spec/requests/api/v1/transactions_spec.rb`
- Para recorrencias:
  - `bundle exec rspec spec/services/recurring_rules/materializer_spec.rb`
  - `bundle exec rspec spec/requests/api/v1/recurring_rules_spec.rb`
- Os request specs ja mostram o fluxo real de `sign_in`, CSRF e payloads JSON.
- Os parsers usam PDFs reais em `doc/inter.pdf` e `doc/Bradesco_*.pdf`.

## Heuristicas Para Mudancas
- Se adicionar campo novo em recurso da API, atualize controller, strong params, serializer, policy/lookup se necessario e request spec.
- Se alterar regras de saldo, fatura ou relatorios, valide explicitamente a diferenca entre conta, cartao, transferencia e `impact_mode`.
- Se adicionar um novo provider de importacao, atualize `Import.provider_key`, `Imports::ParserRegistry`, parser em `lib/parsers/statements` e cobertura de teste ponta a ponta.
- Se mexer em categorias de sistema ou seeds, preserve `user_id: nil` e `system: true`.
- Prefira manter controllers finos e colocar regras de negocio em service objects ou query objects.
- Ao mudar shape de resposta JSON, assuma impacto no frontend e mantenha compatibilidade quando possivel.

## Arquivos De Referencia
- `config/routes.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/api/v1/base_controller.rb`
- `app/controllers/concerns/api/v1/resource_lookup.rb`
- `app/models/transaction.rb`
- `app/models/recurring_rule.rb`
- `app/models/import.rb`
- `app/models/import_item.rb`
- `app/services/imports/process_import.rb`
- `app/services/imports/confirm_import.rb`
- `app/services/imports/parser_registry.rb`
- `app/services/recurring_rules/materializer.rb`
- `app/queries/reports/overview_query.rb`
- `spec/requests/api/v1/imports_spec.rb`
- `spec/queries/reports/overview_query_spec.rb`
