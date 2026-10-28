# Inventário de Equipamentos · efaz

Cadastro de equipamentos por número, descrição e categoria (editáveis; Eletrônicos, Ferramentas e Mobiliário já vêm cadastradas), com registro de saídas (empréstimo, defeito, outro) e retornos. Itens descartados vão para uma lista separada com o número original, a data, o motivo e o destino; o número fica livre para outro equipamento. Os dados ficam no Supabase; a página é estática e pode ficar no GitHub Pages.

## Colocar no ar

1. **Supabase:** crie um projeto, abra o *SQL Editor*, cole o conteúdo de `supabase/schema.sql` e clique em *Run*.
2. **Usuários:** em *Authentication → Users → Add user*, crie um usuário (e-mail e senha) para cada pessoa que vai usar o sistema.
3. **Chaves:** em *Project Settings → API*, copie a *Project URL* e a chave *anon public* para `config.js`.
4. **GitHub Pages:** no repositório, *Settings → Pages → Deploy from a branch → main / (root)*.

## Instalar no celular

Depois de publicado, abra o endereço do GitHub Pages no celular:

- **Android (Chrome):** menu ⋮ → *Instalar app* (ou *Adicionar à tela inicial*).
- **iPhone (Safari):** botão Compartilhar → *Adicionar à Tela de Início*.

O ícone da efaz aparece na tela inicial e o sistema abre em tela cheia, como um aplicativo. É preciso internet para ver e registrar os dados.

## Arquivos

- `index.html` — o sistema inteiro (tela de login, cadastro, lista e histórico)
- `config.js` — endereço e chave pública do Supabase
- `supabase/schema.sql` — tabelas (categorias, equipamentos, histórico, descartados), funções e regras de acesso
- `manifest.webmanifest`, `sw.js`, `icon-*.png`, `apple-touch-icon.png` — o que permite instalar no celular
- `logo-efaz.png` — logo (provisório, recortado de um print do site; trocar pelo arquivo oficial)
