-- Solo para una base de pruebas con la migración email_login aplicada.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000101'), ('00000000-0000-4000-8000-000000000102');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);
set local role authenticated;
do $$ declare result jsonb; begin
  result := public.enter_participant(' NUEVO@example.com ');
  if result->>'needs_name' <> 'true' then raise exception 'Un correo nuevo debe pedir nombre'; end if;
  begin
    perform public.get_my_ratings(); raise exception 'No debe acceder antes de registrarse';
  exception when raise_exception then if sqlerrm <> 'Introduce tu correo para entrar' then raise; end if; end;
  result := public.enter_participant('nuevo@example.com', 'Persona Nueva');
  if result->>'name' <> 'Persona Nueva' or result->>'email' <> 'nuevo@example.com' then raise exception 'Registro incorrecto'; end if;
end $$;
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":5}]', 'No debe sustituir el nombre', 'nuevo@example.com');
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);
do $$ declare result jsonb; begin
  result := public.enter_participant('NUEVO@example.com');
  if result->>'needs_name' <> 'false' or result->>'name' <> 'Persona Nueva' then raise exception 'Usuario conocido no reconocido'; end if;
  if not exists (select 1 from public.get_my_ratings() where house_id = '20270122-0000-4000-8000-000000000001' and score = 5) then raise exception 'No recupera notas en otro navegador'; end if;
  if has_table_privilege(current_user, 'public.participants', 'SELECT') or has_table_privilege(current_user, 'public.participant_ratings', 'SELECT') then raise exception 'Tablas expuestas'; end if;
end $$;
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":2}]', 'Persona Nueva', 'nuevo@example.com');
do $$ begin
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000001' and rating_count = 1 and average_rating = 2) then raise exception 'Ha duplicado la participación'; end if;
end $$;
-- Otro correo no debe heredar las puntuaciones.
select public.enter_participant('segundo@example.com', 'Otra Persona');
do $$ begin
  if exists (select 1 from public.get_my_ratings()) then raise exception 'Se han mezclado los usuarios'; end if;
  begin
    perform public.save_ratings('[]', 'Otra Persona', 'nuevo@example.com'); raise exception 'Se permite guardar con el correo equivocado';
  exception when raise_exception then if sqlerrm <> 'Vuelve a entrar con tu correo' then raise; end if; end;
end $$;
select public.save_ratings('[{"house_id":"20270122-0000-4000-8000-000000000001","score":4}]', 'Otra Persona', 'segundo@example.com');
do $$ begin
  if not exists (select 1 from public.get_rating_results() where house_id = '20270122-0000-4000-8000-000000000001' and rating_count = 2 and average_rating = 3) then raise exception 'Media incorrecta'; end if;
end $$;
select public.enter_participant('nuevo@example.com', 'Intento de cambiar nombre');
do $$ begin
  if not exists (select 1 from public.get_my_ratings() where score = 2) then raise exception 'No se recupera el primer usuario'; end if;
end $$;
reset role;
do $$ begin
  if (select name from public.participants where email = 'nuevo@example.com') <> 'Persona Nueva' then raise exception 'El nombre conocido se ha sobrescrito'; end if;
end $$;
-- Permite retirar todas las notas y no resucitarlas al volver.
set local role authenticated;
select public.save_ratings('[]', 'Persona Nueva', 'nuevo@example.com');
select public.enter_participant('nuevo@example.com');
do $$ begin if exists (select 1 from public.get_my_ratings()) then raise exception 'Reaparecen notas retiradas'; end if; end $$;
rollback;
