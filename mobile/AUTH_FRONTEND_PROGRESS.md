# Etapas de autenticação Flutter — 6/6

Implementadas: **6** · Restantes: **0** · Integradas ao backend: **6/6**

- [x] 1. Login — `POST /api/auth/login`
- [x] 2. Cadastro — `POST /api/auth/register`
- [x] 3. Termos de uso — tela estática (sem chamada de backend)
- [x] 4. Esqueci minha senha — `POST /api/auth/password/forgot`
- [x] 5. Redefinição de senha — `POST /api/auth/password/reset?code=...`
- [x] 6. Verificação de e-mail — `GET /api/auth/verify-email?code=...`

## Escopo e integração

As seis interfaces têm navegação, visual consistente, validação local e
indicadores de carregamento. Todas as telas que exigem comunicação com o
backend estão integradas via `AuthApiClient` (`auth_api_client.dart`), que
gerencia o cookie de sessão `portal_session` através do `CookieJarClient`.

O contrato HTTP segue exatamente o backend Node.js:
- **Login**: envia `{ email, password }`, recebe `Set-Cookie` com a sessão.
- **Cadastro**: envia `{ email, password }` para iniciar a verificação por e-mail.
- **Esqueci a senha**: envia `{ email }`; o backend responde 200 mesmo se o
  e-mail não existir (não revela cadastros).
- **Redefinição de senha**: envia o código como query param `?code=...` e a
  nova senha no corpo JSON `{ password }`.
- **Verificação de e-mail**: GET com o código como query param `?code=...`.

Deep links Android/iOS (abrir o app a partir do link no e-mail) exigem
configuração adicional de intent filters (Android) e universal links (iOS).
Atualmente as rotas `/reset-password?code=...` e `/verify-email?code=...`
funcionam via `onGenerateRoute` no `main.dart`.

## Histórico Git reutilizável

As branches `auth/flutter-01-login` até `auth/flutter-06-verificacao` formam uma sequência de 6 commits, cada um incluindo todas as etapas anteriores; a `main` permanece sem alteração.

Para transferir os commits **individualmente** para outro repositório já compatível com a mesma base de arquivos, adicione este repositório como remoto e aplique, em ordem:

```bash
git remote add auth-source https://github.com/luigicollesi/Luigi-copia-essa-merda.git
git fetch auth-source main auth/flutter-06-verificacao
git cherry-pick $(git rev-list --reverse auth-source/main..auth-source/auth/flutter-06-verificacao)
```

Personalize as mensagens de cada commit usando `git rebase -i HEAD~6` com a opção `reword`, antes de publicar a nova branch. Se o repositório futuro tiver uma base diferente, resolva eventuais conflitos de patches antes de publicar.
