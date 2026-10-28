-- Inventário de equipamentos — rode este arquivo uma vez no SQL Editor do Supabase.

-- Categorias editáveis pela página. As três primeiras já vêm cadastradas.
create table categorias (
  id         bigint generated always as identity primary key,
  nome       text not null check (trim(nome) <> ''),
  criado_em  timestamptz not null default now()
);
create unique index categorias_nome_unico on categorias (lower(nome));
insert into categorias (nome) values ('Eletrônicos'), ('Ferramentas'), ('Mobiliário');

create table equipamentos (
  id         bigint generated always as identity primary key,
  numero     text not null,
  descricao  text not null,
  categoria_id bigint references categorias (id) on delete set null,
  situacao   text not null default 'no-lugar'
             check (situacao in ('no-lugar', 'emprestado', 'defeito', 'outro')),
  destino    text not null default '',
  desde      date not null default current_date,
  criado_em  timestamptz not null default now()
);
create unique index equipamentos_numero_unico on equipamentos (lower(numero));

create table movimentacoes (
  id              bigint generated always as identity primary key,
  equipamento_id  bigint not null references equipamentos (id) on delete cascade,
  tipo            text not null check (tipo in ('cadastro', 'saida', 'retorno')),
  motivo          text,
  destino         text,
  obs             text,
  data            date not null default current_date,
  registrado_por  text default (auth.jwt() ->> 'email'),
  criado_em       timestamptz not null default now()
);
create index movimentacoes_equipamento on movimentacoes (equipamento_id, criado_em desc);

-- Equipamentos descartados saem da tabela principal (o número fica livre) e ficam guardados aqui,
-- com o número original, a data, o motivo, o destino e todo o histórico que tinham.
create table descartados (
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
create function registrar_cadastro() returns trigger language plpgsql as $$
begin
  insert into movimentacoes (equipamento_id, tipo, data) values (new.id, 'cadastro', new.desde);
  return new;
end $$;
create trigger equipamentos_cadastro after insert on equipamentos
  for each row execute function registrar_cadastro();

-- Saída ou retorno: muda a situação e grava no histórico numa única operação.
create function registrar_movimento(
  p_equipamento_id bigint, p_tipo text, p_motivo text, p_destino text, p_obs text, p_data date
) returns void language plpgsql security invoker as $$
begin
  if p_tipo = 'saida' then
    if p_motivo not in ('emprestado', 'defeito', 'outro') then
      raise exception 'Motivo inválido: %', p_motivo;
    end if;
    update equipamentos set situacao = p_motivo, destino = coalesce(p_destino, ''), desde = p_data
      where id = p_equipamento_id;
  elsif p_tipo = 'retorno' then
    update equipamentos set situacao = 'no-lugar', destino = '', desde = p_data
      where id = p_equipamento_id;
  else
    raise exception 'Tipo inválido: %', p_tipo;
  end if;
  insert into movimentacoes (equipamento_id, tipo, motivo, destino, obs, data)
    values (p_equipamento_id, p_tipo, p_motivo, nullif(p_destino, ''), nullif(p_obs, ''), p_data);
end $$;

-- Descarte: copia o equipamento e o histórico para "descartados" e apaga da tabela principal.
create function descartar(
  p_equipamento_id bigint, p_porque text, p_oque text, p_obs text, p_data date
) returns void language plpgsql security definer set search_path = public as $$
declare
  eq equipamentos;
  quem text := auth.jwt() ->> 'email';
begin
  if auth.uid() is null then raise exception 'Faça login para descartar.'; end if;
  if coalesce(trim(p_porque), '') = '' or coalesce(trim(p_oque), '') = '' then
    raise exception 'Informe por que foi descartado e o que foi feito com ele.';
  end if;
  select * into eq from equipamentos where id = p_equipamento_id for update;
  if not found then raise exception 'Equipamento não encontrado.'; end if;
  insert into descartados (numero, descricao, categoria, data, porque, oque, obs, historico, registrado_por)
  select eq.numero, eq.descricao, (select nome from categorias where id = eq.categoria_id), p_data, p_porque, p_oque, nullif(p_obs, ''),
    jsonb_build_array(jsonb_build_object('tipo', 'descarte', 'porque', p_porque, 'data', p_data,
                                         'obs', nullif(p_obs, ''), 'registrado_por', quem))
      || coalesce((select jsonb_agg(to_jsonb(m) - 'id' - 'equipamento_id' order by m.criado_em desc)
                   from movimentacoes m where m.equipamento_id = eq.id), '[]'),
    quem;
  delete from equipamentos where id = eq.id;
end $$;
revoke execute on function descartar from anon, public;
grant execute on function descartar to authenticated;

-- Acesso: só quem faz login (usuários criados em Authentication > Users).
-- O histórico não pode ser editado nem apagado pela página.
alter table categorias    enable row level security;
alter table equipamentos  enable row level security;
alter table movimentacoes enable row level security;
alter table descartados   enable row level security;

create policy "logados veem categorias"        on categorias    for select to authenticated using (true);
create policy "logados criam categorias"       on categorias    for insert to authenticated with check (true);
create policy "logados renomeiam categorias"   on categorias    for update to authenticated using (true) with check (true);
create policy "logados excluem categorias"     on categorias    for delete to authenticated using (true);
create policy "logados veem equipamentos"     on equipamentos  for select to authenticated using (true);
create policy "logados cadastram equipamentos" on equipamentos  for insert to authenticated with check (true);
create policy "logados alteram equipamentos"   on equipamentos  for update to authenticated using (true) with check (true);
create policy "logados veem historico"         on movimentacoes for select to authenticated using (true);
create policy "logados registram historico"    on movimentacoes for insert to authenticated with check (true);
create policy "logados veem descartados"       on descartados   for select to authenticated using (true);
-- Descartados só recebem dados pela função descartar(); ninguém edita ou apaga pela página.
