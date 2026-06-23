# Minhas Financas MCP

O MCP local foi extraido para um repositorio proprio:

`/Users/jonhnes/Documents/minhas-financas-mcp`

Este backend Rails continua sendo a fonte de verdade. O MCP deve consumir somente a API HTTP existente, especialmente:

- `/api/v1/mobile/auth/sign_in`
- `/api/v1/mobile/auth/refresh`
- `/api/v1/accounts`
- `/api/v1/credit_cards`
- `/api/v1/categories`
- `/api/v1/tags`
- `/api/v1/transactions`
- `/api/v1/reports/*`
- `/api/v1/category_suggestion_rules`
- `/api/v1/category_suggestions`
- `/api/v1/imports`
- `/api/v1/import_items/:id`
- `/api/v1/imports/:id/confirm`

O MCP nao deve usar ActiveRecord, SQL direto ou acesso ao banco. Mutacoes continuam passando pela API Rails e exigem confirmacao explicita no MCP.
