# Inventário de Equipamentos · efaz

Cadastro de equipamentos por número, descrição e categoria (editáveis; Eletrônicos, Ferramentas e Mobiliário já vêm cadastradas), com registro de saídas (empréstimo, defeito, outro) e retornos. Itens descartados vão para uma lista separada com o número original, a data, o motivo e o destino; o número fica livre para outro equipamento. Os dados ficam no Supabase; a página é estática e pode ficar no GitHub Pages.

## Onde está

- **Banco:** projeto Supabase `financeiroluisejulia`, no schema `inventario` (separado dos outros sistemas desse projeto). O schema precisa estar em *Project Settings → Data API → Exposed schemas*.
- **Página:** GitHub Pages deste repositório (*Settings → Pages → Deploy from a branch → main / (root)*).

## Quem pode usar

O login do Supabase é compartilhado com os outros sistemas do projeto, então só entra no inventário quem estiver na tabela `inventario.usuarios`. Para dar acesso a alguém:

1. Crie o login da pessoa em *Authentication → Users → Add user* (se ela ainda não tiver).
2. No *SQL Editor*: `insert into inventario.usuarios (email) values ('email.da.pessoa@exemplo.com');`

Para tirar o acesso: `delete from inventario.usuarios where email = 'email.da.pessoa@exemplo.com';`

## Instalar no celular

Depois de publicado, abra o endereço do GitHub Pages no celular:

- **Android (Chrome):** menu ⋮ → *Instalar app* (ou *Adicionar à tela inicial*).
- **iPhone (Safari):** botão Compartilhar → *Adicionar à Tela de Início*.

O ícone da efaz aparece na tela inicial e o sistema abre em tela cheia, como um aplicativo. É preciso internet para ver e registrar os dados.

## Arquivos

- `index.html` — o sistema inteiro (tela de login, cadastro, lista e histórico)
- `config.js` — endereço e chave pública do Supabase
- `supabase/schema.sql` — schema `inventario`: tabelas (usuários autorizados, categorias, equipamentos, histórico, descartados), funções e regras de acesso
- `manifest.webmanifest`, `sw.js`, `icon-*.png`, `apple-touch-icon.png` — o que permite instalar no celular
- `logo-efaz.png` — logo (provisório, recortado de um print do site; trocar pelo arquivo oficial)
