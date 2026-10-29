# Inventário de Equipamentos · efaz

Cadastro de equipamentos por número, descrição, categoria e local (as duas são listas editáveis pela página; Eletrônicos, Ferramentas e Mobiliário já vêm cadastradas), com registro de saídas (empréstimo, defeito, outro) e retornos. Itens descartados vão para uma lista separada com o número original, a data, o motivo e o destino; o número fica livre para outro equipamento. Os dados ficam no Supabase; a página é estática e pode ficar no GitHub Pages.

## Onde está

- **Banco:** projeto Supabase `financeiroluisejulia`, no schema `inventario` (separado dos outros sistemas desse projeto). O schema precisa estar em *Project Settings → Data API → Exposed schemas*.
- **Página:** GitHub Pages deste repositório (*Settings → Pages → Deploy from a branch → main / (root)*).

## Quem pode usar

O login do Supabase é compartilhado com os outros sistemas do projeto, então só entra no inventário quem estiver na tabela `inventario.usuarios`.

**Uma vez só:** em *Authentication → URL Configuration → Redirect URLs*, adicione `https://lfelipe1989.github.io/inventario-efaz/` (é para onde o link de criar senha leva; não muda nada nos outros sistemas).

**Para dar acesso a alguém:**

1. Em *Authentication → Users → Add user → Create new user*, crie o login com o e-mail da pessoa, qualquer senha (ninguém precisa saber) e *Auto Confirm User* marcado. Se a pessoa já usa outro sistema do projeto, pule este passo.
2. No *SQL Editor*: `insert into inventario.usuarios (email) values ('email.da.pessoa@exemplo.com');`
3. Avise a pessoa: abrir o inventário, clicar em **Primeiro acesso ou esqueci minha senha**, digitar o e-mail e seguir o link que chega para criar a própria senha.

Não use *Send invitation* do painel: o link do convite leva para o *Site URL* do projeto, que é de outro sistema.

Para tirar o acesso: `delete from inventario.usuarios where email = 'email.da.pessoa@exemplo.com';`

## Instalar no celular

Depois de publicado, abra o endereço do GitHub Pages no celular:

- **Android (Chrome):** menu ⋮ → *Instalar app* (ou *Adicionar à tela inicial*).
- **iPhone (Safari):** botão Compartilhar → *Adicionar à Tela de Início*.

O ícone da efaz aparece na tela inicial e o sistema abre em tela cheia, como um aplicativo. É preciso internet para ver e registrar os dados.

## Arquivos

- `index.html` — o sistema inteiro (tela de login, cadastro, lista e histórico)
- `config.js` — endereço e chave pública do Supabase
- `supabase/schema.sql` — schema `inventario`: tabelas (usuários autorizados, categorias, locais, equipamentos, histórico, descartados), funções e regras de acesso
- `manifest.webmanifest`, `sw.js`, `icon-*.png`, `apple-touch-icon.png` — o que permite instalar no celular
- `logo-efaz.png` — logo (provisório, recortado de um print do site; trocar pelo arquivo oficial)
