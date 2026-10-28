-- Inventário de equipamentos efaz.
-- Tudo fica no schema "inventario", separado dos outros sistemas do mesmo projeto Supabase.
-- O login é compartilhado com esses sistemas, por isso o acesso é liberado só para quem
-- estiver na tabela inventario.usuarios.

create schema if not exists inventario;

-- Quem pode usar o inventário (e-mail do login do Supabase).
create table inventario.usuarios (
  email      text primary key check (email = lower(email)),
  criado_em  timestamptz not null default now()
);

create function inventario.autorizado() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from inventario.usuarios where email = lower(auth.jwt() ->> 'email'));
$$;

-- Categorias editáveis pela página. As três primeiras já vêm cadastradas.
create table inventario.categorias (
  id         bigint generated always as identity primary key,
  nome       text not null check (trim(nome) <> ''),
  criado_em  timestamptz not null default now()
);
create unique index categorias_nome_unico on inventario.categorias (lower(nome));
insert into inventario.categorias (nome) values ('Eletrônicos'), ('Ferramentas'), ('Mobiliário');

create table inventario.equipamentos (
  id            bigint generated always as identity primary key,
  numero        text not null,
  descricao     text not null,
  categoria_id  bigint references inventario.categorias (id) on delete set null,
  situacao      text not null default 'no-lugar'
                check (situacao in ('no-lugar', 'emprestado', 'defeito', 'outro')),
  destino       text not null default '',
  desde         date not null default current_date,
  criado_em     timestamptz not null default now()
);
create unique index equipamentos_numero_unico on inventario.equipamentos (lower(numero));
create index equipamentos_categoria on inventario.equipamentos (categoria_id);

create table inventario.movimentacoes (
  id              bigint generated always as identity primary key,
  equipamento_id  bigint not null references inventario.equipamentos (id) on delete cascade,
  tipo            text not null check (tipo in ('cadastro', 'saida', 'retorno')),
  motivo          text,
  destino         text,
  obs             text,
  data            date not null default current_date,
  registrado_por  text default (auth.jwt() ->> 'email'),
  criado_em       timestamptz not null default now()
);
create index movimentacoes_equipamento on inventario.movimentacoes (equipamento_id, criado_em desc);

-- Equipamentos descartados saem da tabela principal (o número fica livre) e ficam guardados aqui,
-- com o número original, a data, o motivo, o destino e todo o histórico que tinham.
create table inventario.descartados (
  id              bigint generated always as identity primary key,
  numero          text not null,
  descricao       text not null,
  categoria       text,
  data            date not null,
  porque          text not null,
  oque            text not null,
  obs             text,
  historico       jsonb not null default '[]',
  registrado_por  text default (auth.jwt() ->> 'email'),
  criado_em       timestamptz not null default now()
);

-- Todo cadastro novo entra no histórico automaticamente.
create function inventario.registrar_cadastro() returns trigger
language plpgsql set search_path = '' as $$
begin
  insert into inventario.movimentacoes (equipamento_id, tipo, data) values (new.id, 'cadastro', new.desde);
  return new;
end $$;
create trigger equipamentos_cadastro after insert on inventario.equipamentos
  for each row execute function inventario.registrar_cadastro();

-- Saída ou retorno: muda a situação e grava no histórico numa única operação.
create function inventario.registrar_movimento(
  p_equipamento_id bigint, p_tipo text, p_motivo text, p_destino text, p_obs text, p_data date
) returns void language plpgsql security invoker set search_path = '' as $$
begin
  if p_tipo = 'saida' then
    if p_motivo not in ('emprestado', 'defeito', 'outro') then
      raise exception 'Motivo inválido: %', p_motivo;
    end if;
    update inventario.equipamentos set situacao = p_motivo, destino = coalesce(p_destino, ''), desde = p_data
      where id = p_equipamento_id;
  elsif p_tipo = 'retorno' then
    update inventario.equipamentos set situacao = 'no-lugar', destino = '', desde = p_data
      where id = p_equipamento_id;
  else
    raise exception 'Tipo inválido: %', p_tipo;
  end if;
  if not found then raise exception 'Equipamento não encontrado.'; end if;
  insert into inventario.movimentacoes (equipamento_id, tipo, motivo, destino, obs, data)
    values (p_equipamento_id, p_tipo, p_motivo, nullif(p_destino, ''), nullif(p_obs, ''), p_data);
end $$;

-- Descarte: copia o equipamento e o histórico para "descartados" e apaga da tabela principal.
create function inventario.descartar(
  p_equipamento_id bigint, p_porque text, p_oque text, p_obs text, p_data date
) returns void language plpgsql security definer set search_path = '' as $$
declare
  eq inventario.equipamentos;
  quem text := auth.jwt() ->> 'email';
begin
  if not inventario.autorizado() then raise exception 'Você não tem acesso ao inventário.'; end if;
  if coalesce(trim(p_porque), '') = '' or coalesce(trim(p_oque), '') = '' then
    raise exception 'Informe por que foi descartado e o que foi feito com ele.';
  end if;
  select * into eq from inventario.equipamentos where id = p_equipamento_id for update;
  if not found then raise exception 'Equipamento não encontrado.'; end if;
  insert into inventario.descartados (numero, descricao, categoria, data, porque, oque, obs, historico, registrado_por)
  select eq.numero, eq.descricao, (select c.nome from inventario.categorias c where c.id = eq.categoria_id),
    p_data, p_porque, p_oque, nullif(p_obs, ''),
    jsonb_build_array(jsonb_build_object('tipo', 'descarte', 'porque', p_porque, 'data', p_data,
                                         'obs', nullif(p_obs, ''), 'registrado_por', quem))
      || coalesce((select jsonb_agg(to_jsonb(m) - 'id' - 'equipamento_id' order by m.criado_em desc)
                   from inventario.movimentacoes m where m.equipamento_id = eq.id), '[]'),
    quem;
  delete from inventario.equipamentos where id = eq.id;
end $$;

-- Permissões: só usuários logados chegam ao schema; as regras abaixo filtram quem está autorizado.
grant usage on schema inventario to authenticated;
grant select, insert, update, delete on all tables in schema inventario to authenticated;
grant usage on all sequences in schema inventario to authenticated;
revoke all on inventario.usuarios from authenticated;
revoke execute on all functions in schema inventario from public, anon;
grant execute on function inventario.autorizado(), inventario.registrar_movimento(bigint, text, text, text, text, date),
  inventario.descartar(bigint, text, text, text, date) to authenticated;

alter table inventario.usuarios      enable row level security;
alter table inventario.categorias    enable row level security;
alter table inventario.equipamentos  enable row level security;
alter table inventario.movimentacoes enable row level security;
alter table inventario.descartados   enable row level security;

create policy "autorizados veem categorias"        on inventario.categorias    for select to authenticated using (inventario.autorizado());
create policy "autorizados criam categorias"       on inventario.categorias    for insert to authenticated with check (inventario.autorizado());
create policy "autorizados renomeiam categorias"   on inventario.categorias    for update to authenticated using (inventario.autorizado()) with check (inventario.autorizado());
create policy "autorizados excluem categorias"     on inventario.categorias    for delete to authenticated using (inventario.autorizado());
create policy "autorizados veem equipamentos"      on inventario.equipamentos  for select to authenticated using (inventario.autorizado());
create policy "autorizados cadastram equipamentos" on inventario.equipamentos  for insert to authenticated with check (inventario.autorizado());
create policy "autorizados alteram equipamentos"   on inventario.equipamentos  for update to authenticated using (inventario.autorizado()) with check (inventario.autorizado());
create policy "autorizados veem historico"         on inventario.movimentacoes for select to authenticated using (inventario.autorizado());
create policy "autorizados registram historico"    on inventario.movimentacoes for insert to authenticated with check (inventario.autorizado());
create policy "autorizados veem descartados"       on inventario.descartados   for select to authenticated using (inventario.autorizado());
-- Sem regras em inventario.usuarios: a lista de acesso só muda pelo painel/SQL do Supabase.
-- Descartados só recebem dados pela função descartar(); histórico e descartados não são editados nem apagados pela página.
