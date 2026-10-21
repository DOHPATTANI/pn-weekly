-- v23 additive catalog projections. The workspace JSON remains the audited write owner.
begin;
alter table public.pn2_p301_records add column if not exists day_count_method text not null default '365' check(day_count_method in ('actual','365','366'));
create table if not exists public.pn2_work_catalog_nodes(
 workspace_id uuid not null references public.pn2_workspaces(workspace_id),node_id text not null,work_code text not null,
 title text not null,node_kind text not null check(node_kind in ('project','activity','group','work')),parent_id text,
 units jsonb not null default '[]'::jsonb check(jsonb_typeof(units)='array'),source_page integer not null check(source_page>0),appendix_page integer,
 edition text not null,source_sha256 text not null,primary key(workspace_id,node_id),
 foreign key(workspace_id,parent_id) references public.pn2_work_catalog_nodes(workspace_id,node_id) deferrable initially deferred
);
create index if not exists pn2_catalog_parent_idx on public.pn2_work_catalog_nodes(workspace_id,parent_id,work_code);
create index if not exists pn2_catalog_code_idx on public.pn2_work_catalog_nodes(workspace_id,work_code,node_kind);
create table if not exists public.pn2_work_catalog_budget_links(
 workspace_id uuid not null,work_code_id text not null,budget_account_id text not null,node_id text not null,
 provenance text not null check(provenance in ('registry','manual')),primary key(workspace_id,work_code_id,budget_account_id),
 foreign key(workspace_id,work_code_id) references public.pn2_work_codes(workspace_id,id) on delete cascade deferrable initially deferred,
 foreign key(workspace_id,budget_account_id) references public.pn2_budget_accounts(workspace_id,id) on delete cascade deferrable initially deferred,
 foreign key(workspace_id,node_id) references public.pn2_work_catalog_nodes(workspace_id,node_id) deferrable initially deferred
);
create index if not exists pn2_catalog_budget_idx on public.pn2_work_catalog_budget_links(workspace_id,budget_account_id,work_code_id);
create index if not exists pn2_catalog_link_node_idx on public.pn2_work_catalog_budget_links(workspace_id,node_id);
create table if not exists public.pn2_registry_work_classifications(
 workspace_id uuid not null,registry_id text not null,work_code_id text,node_id text not null,
 project_node_id text,activity_node_id text,budget_account_id text,p301_work_code text not null,
 primary key(workspace_id,registry_id),
 foreign key(workspace_id,registry_id) references public.pn2_contract_registry(workspace_id,id) on delete cascade deferrable initially deferred,
 foreign key(workspace_id,work_code_id) references public.pn2_work_codes(workspace_id,id) on delete cascade deferrable initially deferred,
 foreign key(workspace_id,budget_account_id) references public.pn2_budget_accounts(workspace_id,id) on delete cascade deferrable initially deferred,
 foreign key(workspace_id,node_id) references public.pn2_work_catalog_nodes(workspace_id,node_id) deferrable initially deferred,
 foreign key(workspace_id,project_node_id) references public.pn2_work_catalog_nodes(workspace_id,node_id) deferrable initially deferred,
 foreign key(workspace_id,activity_node_id) references public.pn2_work_catalog_nodes(workspace_id,node_id) deferrable initially deferred
);
create index if not exists pn2_registry_catalog_code_idx on public.pn2_registry_work_classifications(workspace_id,work_code_id);
create index if not exists pn2_registry_catalog_node_idx on public.pn2_registry_work_classifications(workspace_id,node_id);
create index if not exists pn2_registry_catalog_project_idx on public.pn2_registry_work_classifications(workspace_id,project_node_id,activity_node_id);
create index if not exists pn2_registry_catalog_activity_idx on public.pn2_registry_work_classifications(workspace_id,activity_node_id);
create index if not exists pn2_registry_catalog_budget_idx on public.pn2_registry_work_classifications(workspace_id,budget_account_id,project_node_id);
alter table public.pn2_work_catalog_nodes enable row level security;
alter table public.pn2_work_catalog_budget_links enable row level security;
alter table public.pn2_registry_work_classifications enable row level security;
-- Private projections: use existing workspace RPCs. No new direct API grants/policies.
revoke all on public.pn2_work_catalog_nodes,public.pn2_work_catalog_budget_links,public.pn2_registry_work_classifications from public,anon,authenticated;
create or replace function public.pn2_p301_depreciation_code(work_code text) returns text language sql immutable set search_path=public as $code$
 select coalesce($map${"10000":"10000","11000":"11000","11100":"11100","11110":"11100","11120":"11100","11200":"11200","11300":"11300","11400":"11400","11500":"11500","11600":"11600","11700":"11700","11710":"11710","11720":"11720","11730":"11730","11740":"11740","11750":"11750","11760":"11760","11770":"11770","11780":"11780","11790":"11790","11800":"11800","11810":"11810","11820":"11820","11830":"11830","11900":"11900","20000":"20000","20100":"20100","20200":"20200","20300":"20300","20400":"20400","20500":"20500","20510":"20510","20520":"20520","20530":"20530","20540":"20540","20550":"20550","20560":"20560","21000":"21000","21100":"21100","21110":"21100","21111":"21100","21112":"21100","21113":"21100","21114":"21100","21115":"21100","21116":"21100","21120":"21100","21121":"21100","21122":"21100","21123":"21100","21124":"21100","21130":"21100","21131":"21100","21132":"21100","21133":"21100","21200":"21200","21201":"21200","21300":"21300","21310":"21300","21311":"21300","21312":"21300","21320":"21300","21321":"21300","21322":"21300","21323":"21300","21324":"21300","21325":"21300","21400":"21400","21410":"21400","21411":"21400","21412":"21400","21420":"21400","21421":"21400","21422":"21400","21423":"21400","21430":"21400","21431":"21400","21432":"21400","21500":"21500","21510":"21500","21520":"21500","21521":"21500","21522":"21500","21530":"21500","21540":"21500","21550":"21500","21560":"21500","21570":"21500","21600":"21600","21610":"21600","21620":"21600","21630":"21600","21640":"21600","21650":"21600","21660":"21600","22000":"22000","22100":"22100","22200":"22200","22300":"22300","22400":"22400","22500":"22500","22600":"22600","23000":"23000","23100":"23100","23200":"23200","23300":"23300","23400":"23400","24000":"24000","24100":"24100","24200":"24200","25000":"25000","25100":"25100","25200":"25200","25300":"25300","25400":"25400","25500":"25500","25600":"25600","25700":"25700","25800":"25800","25900":"25900","26000":"26000","26100":"26100","26200":"26200","26300":"26300","26400":"26400","26500":"26500","27000":"27000","27100":"27100","27200":"27200","28000":"28000","28100":"28100","28200":"28200","28300":"28300","29000":"29000","29100":"29000","29200":"29000","30000":"30000","31000":"31000","31100":"31100","31200":"31200","31210":"31210","31220":"31220","31290":"31290","31300":"31300","31310":"31310","31320":"31320","31390":"31390","31400":"31400","31410":"31410","31411":"31410","31412":"31410","31413":"31410","31420":"31420","31421":"31420","31422":"31420","31430":"31400","31431":"31400","31432":"31400","31433":"31400","31434":"31400","31435":"31400","31500":"31500","31510":"31500","31520":"31500","31590":"31500","31600":"31600","31700":"31700","31710":"31700","31720":"31700","31800":"31800","31900":"31900","32000":"32000","32010":"32000","32020":"32000","33000":"33000","33100":"33100","33110":"33100","33120":"33100","33200":"33200","33210":"33200","33220":"33200","33230":"33200","33290":"33200","33300":"33300","33400":"33400","33500":"33500","33510":"33510","33520":"33520","33530":"33530","33700":"33700","33800":"33800","33810":"33800","33820":"33800"}$map$::jsonb->>trim(work_code),trim(work_code));
$code$;
create or replace function public.pn2_project_work_catalog(input_doc jsonb,uid uuid) returns void language plpgsql set search_path=public as $projection$
declare source jsonb:=input_doc->'settings'->'workCodeCatalog';
begin
 update public.pn2_p301_records p set day_count_method=coalesce(nullif(p.overrides->>'dayCountMethod',''),'365') where p.workspace_id=uid and p.day_count_method is distinct from coalesce(nullif(p.overrides->>'dayCountMethod',''),'365');
 if source is null or jsonb_typeof(source->'nodes') is distinct from 'array' then return;end if;
 if jsonb_array_length(source->'nodes')>2000 then raise exception 'Work catalog exceeds 2000 nodes';end if;
 insert into public.pn2_work_catalog_nodes(workspace_id,node_id,work_code,title,node_kind,parent_id,units,source_page,appendix_page,edition,source_sha256)
 select uid,n.value->>'id',n.value->>'code',n.value->>'name',n.value->>'kind',nullif(n.value->>'parentId',''),coalesce(n.value->'units','[]'::jsonb),(n.value->>'page')::integer,(n.value->>'appendixPage')::integer,source->>'version',source->>'sourceSha256'
 from jsonb_array_elements(source->'nodes') n(value)
 on conflict(workspace_id,node_id) do update set work_code=excluded.work_code,title=excluded.title,node_kind=excluded.node_kind,parent_id=excluded.parent_id,units=excluded.units,source_page=excluded.source_page,appendix_page=excluded.appendix_page,edition=excluded.edition,source_sha256=excluded.source_sha256
 where row(pn2_work_catalog_nodes.work_code,pn2_work_catalog_nodes.title,pn2_work_catalog_nodes.node_kind,pn2_work_catalog_nodes.parent_id,pn2_work_catalog_nodes.units,pn2_work_catalog_nodes.source_page,pn2_work_catalog_nodes.appendix_page,pn2_work_catalog_nodes.edition,pn2_work_catalog_nodes.source_sha256) is distinct from row(excluded.work_code,excluded.title,excluded.node_kind,excluded.parent_id,excluded.units,excluded.source_page,excluded.appendix_page,excluded.edition,excluded.source_sha256);
 delete from public.pn2_work_catalog_budget_links l where l.workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(input_doc->'settings'->'workCodeBudgetLinks','[]'::jsonb)) x(value) join public.pn2_work_codes c on c.workspace_id=uid and c.name=x.value->>'code' where c.id=l.work_code_id and x.value->>'budgetAccountId'=l.budget_account_id);
 insert into public.pn2_work_catalog_budget_links(workspace_id,work_code_id,budget_account_id,node_id,provenance)
 select distinct on(c.id,x.value->>'budgetAccountId') uid,c.id,x.value->>'budgetAccountId',n.node_id,x.value->>'source'
 from jsonb_array_elements(coalesce(input_doc->'settings'->'workCodeBudgetLinks','[]'::jsonb)) x(value)
 join public.pn2_work_codes c on c.workspace_id=uid and c.name=x.value->>'code'
 join public.pn2_work_catalog_nodes n on n.workspace_id=uid and n.work_code=c.name and n.node_id not like '%-admin'
 order by c.id,x.value->>'budgetAccountId',n.node_id
 on conflict(workspace_id,work_code_id,budget_account_id) do update set node_id=excluded.node_id,provenance=excluded.provenance where row(pn2_work_catalog_budget_links.node_id,pn2_work_catalog_budget_links.provenance) is distinct from row(excluded.node_id,excluded.provenance);
 with recursive paths(node_id,work_code,project_id,activity_id) as (
  select n.node_id,n.work_code,n.node_id,null::text from public.pn2_work_catalog_nodes n where n.workspace_id=uid and n.parent_id is null
  union all select n.node_id,n.work_code,p.project_id,case when n.node_kind='activity' then n.node_id else p.activity_id end from paths p join public.pn2_work_catalog_nodes n on n.workspace_id=uid and n.parent_id=p.node_id
 )
 insert into public.pn2_registry_work_classifications(workspace_id,registry_id,work_code_id,node_id,project_node_id,activity_node_id,budget_account_id,p301_work_code)
 select distinct on(r.id) uid,r.id,r.work_code_id,p.node_id,p.project_id,p.activity_id,r.budget_account_id,public.pn2_p301_depreciation_code(r.work_code)
 from public.pn2_contract_registry r join paths p on p.work_code=r.work_code and p.node_id not like '%-admin' where r.workspace_id=uid order by r.id,p.node_id
 on conflict(workspace_id,registry_id) do update set work_code_id=excluded.work_code_id,node_id=excluded.node_id,project_node_id=excluded.project_node_id,activity_node_id=excluded.activity_node_id,budget_account_id=excluded.budget_account_id,p301_work_code=excluded.p301_work_code
 where row(pn2_registry_work_classifications.work_code_id,pn2_registry_work_classifications.node_id,pn2_registry_work_classifications.project_node_id,pn2_registry_work_classifications.activity_node_id,pn2_registry_work_classifications.budget_account_id,pn2_registry_work_classifications.p301_work_code) is distinct from row(excluded.work_code_id,excluded.node_id,excluded.project_node_id,excluded.activity_node_id,excluded.budget_account_id,excluded.p301_work_code);
 delete from public.pn2_registry_work_classifications x where x.workspace_id=uid and not exists(select 1 from public.pn2_contract_registry r join public.pn2_work_catalog_nodes n on n.workspace_id=uid and n.work_code=r.work_code and n.node_id not like '%-admin' where r.workspace_id=uid and r.id=x.registry_id and n.node_id=x.node_id);
end $projection$;
revoke execute on function public.pn2_project_work_catalog(jsonb,uuid),public.pn2_p301_depreciation_code(text) from public,anon,authenticated;
-- Execute inside the established SECURITY DEFINER transaction, after native registry/master writes.
do $install$ declare definition text;anchor text:='return jsonb_build_object(''revision'',new_rev);';begin
 select pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure) into definition;
 if position('perform public.pn2_project_work_catalog(payload,uid)' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Unknown save contract: catalog projection was not installed';end if;
  execute replace(definition,anchor,'if old_doc->''contractRegistry'' is distinct from payload->''contractRegistry'' or old_doc->''workCodes'' is distinct from payload->''workCodes'' or old_doc->''budgetAccounts'' is distinct from payload->''budgetAccounts'' or old_doc->''settings''->''workCodeCatalog'' is distinct from payload->''settings''->''workCodeCatalog'' or old_doc->''settings''->''workCodeBudgetLinks'' is distinct from payload->''settings''->''workCodeBudgetLinks'' then perform public.pn2_project_work_catalog(payload,uid);end if; '||anchor);
 end if;
end $install$;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','23.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';
