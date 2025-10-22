# pedido
# Pedido

Aplicativo Flutter para gerenciamento de pedidos em restaurante, com:

- Login (via funções RPC no Supabase)
- Painel de pedidos ativos (lista) com ação de marcar como atendido
- Visualização opcional por Mapa do salão (mesas posicionadas sobre uma imagem)
- Editor de Mapa (upload de imagem do salão, adicionar/arrastar/excluir mesas e salvar)
- Tela de leitura de QR Code para criar pedidos rapidamente

## Visão geral

- `lib/main.dart` configura locale pt_BR, inicializa o Supabase e injeta o tema e o roteador (`go_router`).
- `lib/core/` contém:
	- `app_env.dart`: URL e anon key do Supabase (atualmente hardcoded).
	- `supabase_client.dart`: inicialização e acesso ao `SupabaseClient`.
	- `theme.dart`: tema Material 3 com esquema por seed color.
- `lib/routes/app_router.dart` define as rotas: `/login`, `/painel`, `/scan`, `/map-editor`.
- Telas principais em `lib/screens/`:
	- `login_screen.dart`: formulário usuário/senha chamando `AuthService.login` (RPC `login_usuario`).
	- `painel_screen.dart`: lista pedidos ativos via `OrdersService.getActiveOrders` (RPC `get_active_orders`), ação para atualizar status (RPC `update_order_status`). Alterna para visualização em mapa caso haja planta e mesas.
	- `scan_screen.dart`: usa `mobile_scanner` para ler QR e cria pedido com `OrdersService.placeOrder` (RPC `place_order`).
	- `map_editor_screen.dart`: permite fazer upload da imagem da planta (Storage bucket `floorplans` com fallback para data URL base64), adicionar/arrastar/excluir mesas localmente e salvar planta e mesas em tabelas `floorplans` e `tables` do Supabase.
- Serviços em `lib/features/`:
	- `auth/auth_service.dart`
	- `orders/orders_service.dart`
	- `map/map_service.dart`

## Backend esperado (Supabase)

Funções RPC (Postgres) usadas pelo app:

- `login_usuario(p_username text, p_password text) -> json` (retorna `{ success: bool, message?: string, ... }`)
- `place_order(p_token text, p_customer_name text, p_items jsonb) -> text` (retorna `order_id`)
- `get_active_orders() -> jsonb[]` (cada item deve conter `order_id`, `table_label`, `status`, `items` etc.)
- `update_order_status(p_order_id text, p_status text) -> void`

Tabelas utilizadas pelo editor de mapa:

- `floorplans(id uuid/text, name text, image_path text, created_at timestamptz)`
- `tables(id uuid/text, floorplan_id, label text, description text?, x int, y int, width int, height int, is_active bool)`

Storage:

- Bucket: `floorplans` (público para leitura ao menos; o app gera URL pública). Se o upload falhar por RLS ou configuração, o app usa fallback: armazena `image_path` como `data:image/png;base64,...`.

Observação: as regras RLS e permissões devem permitir as operações acima conforme seu modelo de segurança.

## Como rodar (Windows PowerShell)

Pré-requisitos: Flutter SDK instalado e `flutter doctor` ok.

1) Instalar dependências:

```powershell
flutter pub get
```

2) (Opcional, recomendado) Configure as chaves do Supabase via arquivo `.env`:

- Copie `.env.example` para `.env` e preencha suas chaves.
- O código atual lê de `lib/core/app_env.dart`. Para migração futura ao `.env`, veja a seção "Melhorias rápidas".

3) Executar o app:

```powershell
flutter run
```

## Fluxo do usuário

1) Acessa `/login` e autentica.
2) É redirecionado ao `/painel` para ver pedidos ativos, marcar atendidos, alternar para o mapa, abrir editor de mapa ou leitor de QR.
3) Em `/scan`, ao ler um QR contendo um token (ou URL com `?t=<token>`), cria um novo pedido.
4) Em `/map-editor`, faz upload da imagem, adiciona/organiza mesas e salva no Supabase.

## Melhorias rápidas sugeridas

- Segurança das chaves: mover `supabaseUrl` e `supabaseAnonKey` para `.env` usando `flutter_dotenv` (já está no `pubspec`).
- Storage: validar se o bucket `floorplans` existe e se as regras permitem upload; caso contrário o fallback base64 será usado (pode aumentar tamanho da `image_path`).
- UX do mapa: ajustar cálculo de posição ao arrastar quando houver zoom/scroll (o app já utiliza `globalToLocal`, mas pode exigir refinamentos considerando `InteractiveViewer`).
- Consistência: hoje o editor manipula mesas localmente e salva tudo ao final; considerar persistência incremental (criar/atualizar ao soltar drag) para evitar perda de dados.
- Validações: reforçar validação de formulário e estados de carregamento/erro nos serviços.

## Stack

- Flutter (Material 3)
- go_router
- supabase_flutter
- mobile_scanner
- image_picker
- intl (pt_BR)

---

Recursos Flutter:

- [Documentação Flutter](https://docs.flutter.dev/)
- [go_router](https://pub.dev/packages/go_router)
- [supabase_flutter](https://pub.dev/packages/supabase_flutter)
