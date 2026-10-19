-- Ejecutar solo en una base de pruebas con el esquema y las seis candidatas.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000001'), ('00000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":5},{"house_id":"20270122-0000-4000-8000-000000000002","score":2}]', 'Ana', 'ANA@example.com');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":2}]', 'José', 'jose@example.com');
do $$
begin
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000001' and rating_count = 2 and average_rating = 3.5) then raise exception 'Media o número de notas incorrecto'; end if;
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000003' and rating_count = 0 and average_rating is null) then raise exception 'Sin valorar debe ser NULL'; end if;
  begin
    perform public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":6}]', 'José', 'jose@example.com');
    raise exception 'Se ha permitido una nota fuera de rango';
  exception when raise_exception then if sqlerrm <> 'Cada nota debe ser un entero de 1 a 5' then raise; end if; end;
  begin
    perform public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":4},{"house_id":"20270122-0000-4000-8000-000000000001","score":3}]', 'José', 'jose@example.com');
    raise exception 'Se han permitido duplicados';
  exception when raise_exception then if sqlerrm <> 'Hay casas duplicadas' then raise; end if; end;
  begin
    perform public.save_ratings('[]', '', 'invalid');
    raise exception 'Se han permitido datos incompletos';
  exception when raise_exception then if sqlerrm <> 'Introduce tu nombre' then raise; end if; end;
  if (select score from public.ratings where user_id = auth.uid()) <> 2 then raise exception 'Un fallo ha modificado las notas'; end if;
end;
$$;
-- Actualizar reemplaza en lugar de acumular.
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":4}]', 'José', 'jose@example.com');
do $$ begin
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000001' and rating_count = 2 and average_rating = 4.5) then raise exception 'Reemplazo incorrecto'; end if;
end $$;
set local role authenticated;
do $$ begin
  if (select count(*) from public.ratings) <> 1 then raise exception 'RLS no oculta notas ajenas'; end if;
  if has_table_privilege(current_user, 'public.rating_details', 'SELECT') then raise exception 'Datos privados expuestos'; end if;
  if has_table_privilege(current_user, 'public.ratings', 'INSERT') then raise exception 'Escrituras directas permitidas'; end if;
  if to_regprocedure('public.save_votes(uuid[],text,text)') is not null then raise exception 'Sigue activa la función antigua'; end if;
end $$;
select public.save_ratings('[]', 'José', 'jose@example.com');
do $$ begin
  if exists (select 1 from public.ratings) then raise exception 'Retirada incompleta'; end if;
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000001' and rating_count = 1 and average_rating = 5) then raise exception 'Media incorrecta al retirar'; end if;
end $$;
rollback;
