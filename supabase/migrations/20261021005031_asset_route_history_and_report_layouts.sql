-- Additive, idempotent migration; preserve existing data.
begin;
-- Fresh consolidated schema also needs this existing native segment relation.
create table if not exists public.pn2_registry_segments(workspace_id uuid not null,registry_id text not null,ordinal integer not null check(ordinal>0),road_no text,control_section text,section_name text,km_start text,km_end text,direction text,note text,primary key(workspace_id,registry_id,ordinal),foreign key(workspace_id,registry_id) references public.pn2_contract_registry(workspace_id,id) on delete cascade deferrable initially deferred);
alter table public.pn2_registry_segments enable row level security;
create table if not exists public.pn2_asset_locations(
 workspace_id uuid not null references public.pn2_workspaces(workspace_id) on delete cascade,id text not null,
 road_no text not null,control_section text not null,section_name text not null default '',
 primary key(workspace_id,id),unique(workspace_id,road_no,control_section),check(btrim(road_no)<>'' and btrim(control_section)<>'')
);
create table if not exists public.pn2_asset_project_links(
 workspace_id uuid not null,asset_id text not null,registry_id text not null,segment_ordinal integer not null,
 primary key(workspace_id,asset_id,registry_id,segment_ordinal),
 foreign key(workspace_id,asset_id) references public.pn2_asset_locations(workspace_id,id) on delete cascade,
 foreign key(workspace_id,registry_id,segment_ordinal) references public.pn2_registry_segments(workspace_id,registry_id,ordinal) on delete cascade deferrable initially deferred
);
alter table public.pn2_asset_locations enable row level security;
alter table public.pn2_asset_project_links enable row level security;
revoke all on public.pn2_asset_locations,public.pn2_asset_project_links from anon,authenticated;
create index if not exists pn2_asset_project_registry_idx on public.pn2_asset_project_links(workspace_id,registry_id,segment_ordinal);
create index if not exists pn2_asset_road_control_idx on public.pn2_asset_locations(workspace_id,road_no,control_section);
create or replace function public.pn2_project_asset_routes(input_doc jsonb,uid uuid) returns void language plpgsql set search_path='' as $projection$
begin
 if jsonb_typeof(input_doc) is distinct from 'object' then raise exception 'Asset projection requires a workspace document';end if;
 insert into public.pn2_asset_locations(workspace_id,id,road_no,control_section,section_name)
 select uid,'ROAD-'||md5(jsonb_build_array(btrim(s.road_no),btrim(s.control_section))::text),btrim(s.road_no),btrim(s.control_section),max(coalesce(s.section_name,''))
 from public.pn2_registry_segments s where s.workspace_id=uid and nullif(btrim(s.road_no),'') is not null and nullif(btrim(s.control_section),'') is not null
 group by btrim(s.road_no),btrim(s.control_section)
 on conflict(workspace_id,id) do update set section_name=excluded.section_name where pn2_asset_locations.section_name is distinct from excluded.section_name;
 insert into public.pn2_asset_project_links(workspace_id,asset_id,registry_id,segment_ordinal)
 select uid,a.id,s.registry_id,s.ordinal from public.pn2_registry_segments s join public.pn2_asset_locations a
 on a.workspace_id=s.workspace_id and a.road_no=btrim(s.road_no) and a.control_section=btrim(s.control_section) where s.workspace_id=uid
 on conflict(workspace_id,asset_id,registry_id,segment_ordinal) do nothing;
 delete from public.pn2_asset_project_links l where l.workspace_id=uid and not exists(select 1 from public.pn2_registry_segments s join public.pn2_asset_locations a on a.workspace_id=s.workspace_id and a.road_no=btrim(s.road_no) and a.control_section=btrim(s.control_section) where s.workspace_id=l.workspace_id and s.registry_id=l.registry_id and s.ordinal=l.segment_ordinal and a.id=l.asset_id);
 delete from public.pn2_asset_locations a where a.workspace_id=uid and not exists(select 1 from public.pn2_asset_project_links l where l.workspace_id=a.workspace_id and l.asset_id=a.id);
end $projection$;
revoke all on function public.pn2_project_asset_routes(jsonb,uuid) from public,anon,authenticated;
do $install$ declare definition text; begin
 select pg_get_functiondef('public.pn2_project_p301(jsonb,uuid)'::regprocedure) into definition;
 if position('perform public.pn2_project_asset_routes(input_doc,uid)' in definition)=0 then
  -- Function delimiter spelling is not stable in pg_get_functiondef. Insert before the last END in the body.
  select p.prosrc into definition from pg_proc p where p.oid='public.pn2_project_p301(jsonb,uuid)'::regprocedure;
  if definition !~* 'end\s*$' then raise exception 'Unknown P301 projection contract';end if;
  definition:=regexp_replace(definition,'end\s*$','perform public.pn2_project_asset_routes(input_doc,uid); end','i');
  execute 'create or replace function public.pn2_project_p301(input_doc jsonb,uid uuid) returns void language plpgsql set search_path=public as '||quote_literal(definition);
 end if;
end $install$;
select public.pn2_project_asset_routes(w.document,w.workspace_id) from public.pn2_workspaces w;
create or replace function public.pn2_load_asset_history(requested_route text default null,requested_control text default null,requested_year integer default null,requested_funding text default null)
returns jsonb language sql stable security definer set search_path='' set statement_timeout='15s' as $history$
 with scope as(select w.workspace_id,w.revision,w.document from public.pn2_workspaces w where w.workspace_id='00000000-0000-0000-0000-000000000001'::uuid),
 catalog as(select a.id,a.road_no,a.control_section,a.section_name,count(distinct c.id) as contract_count from scope w join public.pn2_asset_locations a on a.workspace_id=w.workspace_id join public.pn2_asset_project_links l on l.workspace_id=a.workspace_id and l.asset_id=a.id join public.pn2_contract_registry c on c.workspace_id=l.workspace_id and c.id=l.registry_id where (requested_year is null or c.fiscal_year=requested_year) and (requested_funding is null or c.funding_source=requested_funding) group by a.id,a.road_no,a.control_section,a.section_name),
 chosen as(select a.id,a.road_no,a.control_section,a.section_name from catalog a where (nullif(requested_route,'') is null or a.road_no=btrim(requested_route)) and (nullif(requested_control,'') is null or a.control_section=btrim(requested_control)) order by a.road_no,a.control_section limit 1),
 records as(select distinct c.id,c.fiscal_year,c.acceptance_date,c.signed_date,c.contract_no,c.payload from scope w join public.pn2_asset_project_links l on l.workspace_id=w.workspace_id join chosen a on a.id=l.asset_id join public.pn2_contract_registry c on c.workspace_id=l.workspace_id and c.id=l.registry_id where (requested_year is null or c.fiscal_year=requested_year) and (requested_funding is null or c.funding_source=requested_funding))
 select jsonb_build_object('revision',w.revision,'asset',(select jsonb_build_object('id',a.id,'routeNumber',a.road_no,'controlSection',a.control_section,'sectionName',a.section_name) from chosen a),'assets',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'routeNumber',a.road_no,'controlSection',a.control_section,'sectionName',a.section_name,'contractCount',a.contract_count) order by a.road_no,a.control_section) from catalog a),'[]'::jsonb),'contractRegistry',coalesce((select jsonb_agg(r.payload order by coalesce(r.acceptance_date,r.signed_date),r.fiscal_year,r.contract_no,r.id) from records r),'[]'::jsonb),'years',coalesce(w.document->'years','[]'::jsonb),'fundingSources',coalesce(w.document->'fundingSources','[]'::jsonb),'unlinkedContracts',(select count(1) from public.pn2_contract_registry c where c.workspace_id=w.workspace_id and (requested_year is null or c.fiscal_year=requested_year) and (requested_funding is null or c.funding_source=requested_funding) and not exists(select 1 from public.pn2_asset_project_links l where l.workspace_id=c.workspace_id and l.registry_id=c.id))) from scope w;
$history$;
revoke all on function public.pn2_load_asset_history(text,text,integer,text) from public;
grant execute on function public.pn2_load_asset_history(text,text,integer,text) to anon,authenticated;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','21.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null and position('perform public.pn2_project_asset_routes(input_doc,uid)' in pg_get_functiondef('public.pn2_project_p301(jsonb,uuid)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';
