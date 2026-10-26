# Etapas de autenticação Flutter — 6/6

Implementadas: **6** · Restantes: **0**

- [x] 1. Login
- [x] 2. Cadastro
- [x] 3. Termos de uso
- [x] 4. Esqueci minha senha
- [x] 5. Redefinição de senha
- [x] 6. Verificação de e-mail

## Escopo e limitações

As seis interfaces têm navegação, visual consistente, validação local e indicadores de progresso para debug. Cadastro, autenticação, envio de links, redefinição de senha e verificação de tokens **não executam chamadas de backend**. Links de prévia aparecem apenas em modo debug. Deep links Android/iOS exigirão configuração adicional quando houver integração real.

## Histórico Git reutilizável

As branches `auth/flutter-01-login` até `auth/flutter-06-verificacao` formam uma sequência de 6 commits, cada um incluindo todas as etapas anteriores; a `main` permanece sem alteração.

Para transferir os commits **individualmente** para outro repositório já compatível com a mesma base de arquivos, adicione este repositório como remoto e aplique, em ordem:

```bash
git remote add auth-source https://github.com/luigicollesi/Luigi-copia-essa-merda.git
git fetch auth-source main auth/flutter-06-verificacao
git cherry-pick $(git rev-list --reverse auth-source/main..auth-source/auth/flutter-06-verificacao)
```

Personalize as mensagens de cada commit usando `git rebase -i HEAD~6` com a opção `reword`, antes de publicar a nova branch. Se o repositório futuro tiver uma base diferente, resolva eventuais conflitos de patches antes de publicar.
