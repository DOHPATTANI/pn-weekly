-- PN Weekly v7.1: shared single-user workspace, NO Auth dependency. Safe to rerun.
-- Leaves all v1 tables and data untouched; uses pn2_* tables and RPCs; upgrades v2 in place.
begin;
grant usage on schema public to anon, authenticated;
create table if not exists public.pn2_workspaces (
 workspace_id uuid primary key ,
 revision bigint not null default 0,
 document jsonb not null,
 updated_at timestamptz not null default now()
);
create table if not exists public.pn2_fiscal_years(workspace_id uuid not null references public.pn2_workspaces(workspace_id) on delete cascade, year integer not null check(year between 2500 and 2700),primary key(workspace_id,year));
create table if not exists public.pn2_categories(workspace_id uuid not null references public.pn2_workspaces(workspace_id) on delete cascade,id text not null,name text not null,primary key(workspace_id,id),unique(workspace_id,name));
create table if not exists public.pn2_contracts(
 workspace_id uuid not null references public.pn2_workspaces(workspace_id) on delete cascade,id text not null,contract_no text not null,fiscal_year integer not null,category_id text not null,title text not null,
 start_date date not null,end_date date not null,base_days integer not null check(base_days>0),contractor text not null,supervisor text not null default '',archived boolean not null default false,payload jsonb not null,
 primary key(workspace_id,id),unique(workspace_id,fiscal_year,contract_no),foreign key(workspace_id,fiscal_year) references public.pn2_fiscal_years(workspace_id,year),foreign key(workspace_id,category_id) references public.pn2_categories(workspace_id,id),check(end_date>=start_date)
);
create table if not exists public.pn2_extensions(workspace_id uuid not null, id text not null,contract_id text not null,days integer not null check(days>0),approval_reference text not null,approved boolean not null,payload jsonb not null,primary key(workspace_id,id),foreign key(workspace_id,contract_id) references public.pn2_contracts(workspace_id,id) on delete cascade);
create table if not exists public.pn2_reports(workspace_id uuid not null references public.pn2_workspaces(workspace_id) on delete cascade,id text not null,fiscal_year integer,start_date date,end_date date,reference_date date,locked boolean not null,imported boolean not null,title text not null,payload jsonb not null,primary key(workspace_id,id),check(imported or (end_date-start_date=6 and reference_date=end_date and extract(isodow from end_date)=1)));
create unique index if not exists pn2_report_period_unique on public.pn2_reports(workspace_id,fiscal_year,start_date) where not imported;
create table if not exists public.pn2_entries(workspace_id uuid not null,report_id text not null,contract_id text not null,plan_percent numeric(5,2) not null check(plan_percent between 0 and 100),weekly_percent numeric(5,2) not null check(weekly_percent between 0 and 100),actual_percent numeric(5,2) not null check(actual_percent between 0 and 100),note text not null default '',payment_status text not null check(payment_status in ('รอส่งมอบงาน','รอเบิกจ่าย','เบิกจ่ายแล้ว')),confirmed boolean not null default false,contract_snapshot jsonb,primary key(workspace_id,report_id,contract_id),foreign key(workspace_id,report_id) references public.pn2_reports(workspace_id,id) on delete cascade,foreign key(workspace_id,contract_id) references public.pn2_contracts(workspace_id,id),check(payment_status<>'เบิกจ่ายแล้ว' or actual_percent=100));
create table if not exists public.pn2_audit(id bigint generated always as identity primary key,workspace_id uuid not null ,revision bigint not null,action text not null,created_at timestamptz not null default now());

-- v3 master registers, synchronized with the workspace in the same transaction.
create table if not exists public.pn2_contractors(workspace_id uuid not null references public.pn2_workspaces on delete cascade,id text not null,name text not null,archived boolean not null default false,primary key(workspace_id,id),unique(workspace_id,name));
create table if not exists public.pn2_supervisors(like public.pn2_contractors including all);
create table if not exists public.pn2_work_types(like public.pn2_contractors including all);
create table if not exists public.pn2_work_names(workspace_id uuid not null references public.pn2_workspaces on delete cascade,id text not null,name text not null,type_id text,archived boolean not null default false,primary key(workspace_id,id),unique(workspace_id,name));
create table if not exists public.pn2_funding_sources(workspace_id uuid not null references public.pn2_workspaces on delete cascade,id text not null,name text not null,primary key(workspace_id,id));
alter table public.pn2_contracts add column if not exists contractor_id text;
alter table public.pn2_contracts add column if not exists supervisor_id text;
alter table public.pn2_contracts add column if not exists work_name_id text;
alter table public.pn2_contracts add column if not exists work_type_id text;
alter table public.pn2_contracts add column if not exists funding_source text not null default 'DOH';
alter table public.pn2_reports add column if not exists funding_source text not null default 'DOH';
alter table public.pn2_entries add column if not exists payment_date date;
alter table public.pn2_entries add column if not exists delivery_date date;
alter table public.pn2_entries add column if not exists acceptance_date date;
alter table public.pn2_contracts drop constraint if exists pn2_contracts_workspace_id_fiscal_year_contract_no_key;
create unique index if not exists pn2_contract_no_funding_unique on public.pn2_contracts(workspace_id,fiscal_year,funding_source,contract_no);
drop index if exists public.pn2_report_period_unique;
create unique index if not exists pn2_report_period_funding_unique on public.pn2_reports(workspace_id,fiscal_year,funding_source,start_date) where not imported;


do $$begin
 if not exists(select 1 from pg_constraint where conname='pn2_contract_contractor_fk') then alter table public.pn2_contracts add constraint pn2_contract_contractor_fk foreign key(workspace_id,contractor_id) references public.pn2_contractors(workspace_id,id) deferrable initially deferred;end if;
 if not exists(select 1 from pg_constraint where conname='pn2_contract_supervisor_fk') then alter table public.pn2_contracts add constraint pn2_contract_supervisor_fk foreign key(workspace_id,supervisor_id) references public.pn2_supervisors(workspace_id,id) deferrable initially deferred;end if;
 if not exists(select 1 from pg_constraint where conname='pn2_contract_workname_fk') then alter table public.pn2_contracts add constraint pn2_contract_workname_fk foreign key(workspace_id,work_name_id) references public.pn2_work_names(workspace_id,id) deferrable initially deferred;end if;
 if not exists(select 1 from pg_constraint where conname='pn2_contract_worktype_fk') then alter table public.pn2_contracts add constraint pn2_contract_worktype_fk foreign key(workspace_id,work_type_id) references public.pn2_work_types(workspace_id,id) deferrable initially deferred;end if;
end $$;


-- หมวดทะเบียนสัญญาแบบ ก-3: แยกจาก pn2_contracts ที่รายงานรายสัปดาห์ใช้อ้างอิง
create table if not exists public.pn2_contract_registry(
 workspace_id uuid not null references public.pn2_workspaces(workspace_id),id text not null,
 contract_no text not null,fiscal_year integer not null,funding_source text not null,
 title text not null,work_code text,budget_account text,signed_date date,
 start_date date not null,end_date date not null,base_days integer not null check(base_days>0),
 contractor_raw text,contractor_id text,contractor_needs_review boolean not null default true,
 contract_value numeric(18,2),actual_cost numeric(18,2),quantity numeric(18,4),unit text,
 final_payment_date date,delivery_date date,acceptance_date date,work_type_id text,project_id text,payload jsonb not null,
 primary key(workspace_id,id),foreign key(workspace_id,contractor_id) references public.pn2_contractors(workspace_id,id) deferrable initially deferred,
 foreign key(workspace_id,work_type_id) references public.pn2_work_types(workspace_id,id) deferrable initially deferred,
 check(end_date>=start_date),check(contract_value>=0),check(actual_cost>=0),check(quantity>=0)
);
create unique index if not exists pn2_registry_contract_unique on public.pn2_contract_registry(workspace_id,fiscal_year,funding_source,regexp_replace(regexp_replace(contract_no,'^ป\s*\.?\s*น\s*\.?\s*',''),'\s','','g'));
create table if not exists public.pn2_registry_work_links(workspace_id uuid not null,work_code text not null,title text not null,work_type_id text,primary key(workspace_id,work_code,title));


-- v6: หลัก/รองของทะเบียนกลาง และความเชื่อมโยงกับรายสัปดาห์
create table if not exists public.pn2_budget_accounts(workspace_id uuid not null references public.pn2_workspaces(workspace_id),id text not null,name text not null,archived boolean not null default false,primary key(workspace_id,id),unique(workspace_id,name));
create table if not exists public.pn2_work_codes(workspace_id uuid not null references public.pn2_workspaces(workspace_id),id text not null,name text not null,archived boolean not null default false,primary key(workspace_id,id),unique(workspace_id,name));
create table if not exists public.pn2_work_name_codes(workspace_id uuid not null,work_name_id text not null,work_code_id text not null,primary key(workspace_id,work_name_id,work_code_id),foreign key(workspace_id,work_name_id) references public.pn2_work_names(workspace_id,id) deferrable initially deferred,foreign key(workspace_id,work_code_id) references public.pn2_work_codes(workspace_id,id) deferrable initially deferred);
alter table public.pn2_contract_registry add column if not exists budget_account_id text;
alter table public.pn2_contract_registry add column if not exists work_code_id text;
alter table public.pn2_contract_registry add column if not exists work_name_id text;
alter table public.pn2_contract_registry add column if not exists supervisor_id text;
alter table public.pn2_contract_registry add column if not exists archived boolean not null default false;
alter table public.pn2_contracts add column if not exists registry_id text;
do $$declare spec record;begin
 for spec in select * from (values
 ('pn2_registry_year_fk','pn2_contract_registry','fiscal_year','pn2_fiscal_years','year'),
 ('pn2_registry_funding_fk','pn2_contract_registry','funding_source','pn2_funding_sources','id'),
 ('pn2_registry_budget_fk','pn2_contract_registry','budget_account_id','pn2_budget_accounts','id'),
 ('pn2_registry_code_fk','pn2_contract_registry','work_code_id','pn2_work_codes','id'),
 ('pn2_registry_job_fk','pn2_contract_registry','work_name_id','pn2_work_names','id'),
 ('pn2_registry_supervisor_fk','pn2_contract_registry','supervisor_id','pn2_supervisors','id'),
 ('pn2_registry_project_fk','pn2_contract_registry','project_id','pn2_contracts','id'),
 ('pn2_contract_registry_fk','pn2_contracts','registry_id','pn2_contract_registry','id'),
 ('pn2_work_name_type_fk','pn2_work_names','type_id','pn2_work_types','id'),
 ('pn2_contract_year_fk','pn2_contracts','fiscal_year','pn2_fiscal_years','year'),
 ('pn2_contract_funding_fk','pn2_contracts','funding_source','pn2_funding_sources','id'),
 ('pn2_report_year_fk','pn2_reports','fiscal_year','pn2_fiscal_years','year'),
 ('pn2_report_funding_fk','pn2_reports','funding_source','pn2_funding_sources','id')
 ) as x(c,t,col,ref,refcol) loop
 if not exists(select 1 from pg_constraint where conname=spec.c and conrelid=('public.'||spec.t)::regclass) then
 execute format('alter table public.%I add constraint %I foreign key(workspace_id,%I) references public.%I(workspace_id,%I) deferrable initially deferred',spec.t,spec.c,spec.col,spec.ref,spec.refcol);end if;
 end loop;
end $$;
create index if not exists pn2_registry_filter_idx on public.pn2_contract_registry(workspace_id,funding_source,fiscal_year,archived,budget_account_id);
create index if not exists pn2_registry_project_idx on public.pn2_contract_registry(workspace_id,project_id);
create index if not exists pn2_entries_contract_idx on public.pn2_entries(workspace_id,contract_id,report_id);

-- v7: six-character master codes; legacy primary/foreign keys stay valid.
do $$declare t text;begin foreach t in array array['pn2_contractors','pn2_supervisors','pn2_work_types','pn2_work_names','pn2_work_codes','pn2_budget_accounts','pn2_fiscal_years'] loop
 execute format('alter table public.%I add column if not exists code text',t);
 execute format('create unique index if not exists %I on public.%I(workspace_id,code) where code is not null',t||'_code_unique',t);
end loop;end $$;

-- All public table writes go through the validating transactional RPC.
do $$declare t text;begin foreach t in array array['pn2_workspaces','pn2_fiscal_years','pn2_categories','pn2_contracts','pn2_extensions','pn2_reports','pn2_entries','pn2_audit','pn2_contractors','pn2_supervisors','pn2_work_types','pn2_work_names','pn2_funding_sources','pn2_contract_registry','pn2_registry_work_links','pn2_budget_accounts','pn2_work_codes','pn2_work_name_codes'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('drop policy if exists shared_read on public.%I',t);
 execute format('create policy shared_read on public.%I for select to anon, authenticated using (true)',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to anon, authenticated',t);
end loop;end $$;
create or replace function public.pn2_load_workspace() returns jsonb language sql security invoker set search_path='' as $$select document || jsonb_build_object('revision',revision) from public.pn2_workspaces where workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
create or replace function public.pn2_save_workspace(payload jsonb,expected_revision bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_array_elements(old_doc->'reports') where (value->>'locked')::boolean loop
   select value into existing from jsonb_array_elements(payload->'reports') where value->>'id'=v->>'id';
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(payload->'reports') loop
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'=r->>'id' and x->>'imported'='true') then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(payload->'projects') where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null and not exists(select 1 from jsonb_array_elements(coalesce(old_doc->'reports','[]')) x where x->>'id'=r->>'id' and x->>'locked'='true') then raise exception 'กรุณาระบุวันที่เบิกจ่าย';end if;
    select x->'entries'->e.key into prev from jsonb_array_elements(payload->'reports') x where (x->>'end')::date<(r->>'start')::date and x->'entries' ? e.key order by (x->>'end')::date desc limit 1;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and not exists(select 1 from jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where x->>'id'=r->>'id' and x->>'locked'='true') then
     select value into p from jsonb_array_elements(payload->'projects') where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();
 delete from public.pn2_work_name_codes where workspace_id=uid;delete from public.pn2_contract_registry where workspace_id=uid;delete from public.pn2_registry_work_links where workspace_id=uid;
 -- Materialized relational records are refreshed in the SAME transaction.
 delete from public.pn2_entries where workspace_id=uid;delete from public.pn2_reports where workspace_id=uid;delete from public.pn2_extensions where workspace_id=uid;delete from public.pn2_contracts where workspace_id=uid;delete from public.pn2_categories where workspace_id=uid;delete from public.pn2_fiscal_years where workspace_id=uid;if old_doc->'contractors' is distinct from payload->'contractors' then delete from public.pn2_contractors existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'contractors','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;if old_doc->'supervisors' is distinct from payload->'supervisors' then delete from public.pn2_supervisors existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'supervisors','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;delete from public.pn2_work_names where workspace_id=uid;if old_doc->'workTypes' is distinct from payload->'workTypes' then delete from public.pn2_work_types existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'workTypes','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;delete from public.pn2_funding_sources where workspace_id=uid;if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then delete from public.pn2_budget_accounts existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;if old_doc->'workCodes' is distinct from payload->'workCodes' then delete from public.pn2_work_codes existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'workCodes','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}'));end loop;
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name');end loop;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code',''));end loop;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name');end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}');end loop;
 end loop;
 for p in select value from jsonb_array_elements(payload->'projects')loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(payload->'reports')loop
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots',coalesce(r->>'funding','DOH'));
  update public.pn2_reports set funding_source=coalesce(r->>'funding','DOH') where workspace_id=uid and id=r->>'id';
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,r->'snapshots'->entry_row.key,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row;
 end loop;

 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false));
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=coalesce(excluded.work_type_id,public.pn2_registry_work_links.work_type_id);end if;
 end loop;

 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $$;
revoke all on function public.pn2_load_workspace() from public;revoke all on function public.pn2_save_workspace(jsonb,bigint) from public;
grant execute on function public.pn2_load_workspace() to anon, authenticated;grant execute on function public.pn2_save_workspace(jsonb,bigint) to anon, authenticated;
create or replace view public.pn2_live_status with(security_invoker=true) as
select c.workspace_id,c.id,c.contract_no,c.fiscal_year,c.title,c.end_date,
case when (now() at time zone 'Asia/Bangkok')::date>c.end_date then 'หมดอายุสัญญา' else 'อยู่ในอายุสัญญา' end contract_status,
c.base_days+coalesce((select sum(x.days) from public.pn2_extensions x where x.workspace_id=c.workspace_id and x.contract_id=c.id and x.approved),0) effective_days
from public.pn2_contracts c;
grant select on public.pn2_live_status to anon, authenticated;
create or replace view public.pn2_report_summary with(security_invoker=true) as
select workspace_id,report_id,count(*) total_contracts,count(*)filter(where actual_percent=100) completed,count(*)filter(where actual_percent<100) ongoing,count(*)filter(where payment_status='เบิกจ่ายแล้ว') paid,count(*)filter(where actual_percent=100 and payment_status='รอเบิกจ่าย') awaiting_payment,count(*)filter(where actual_percent=100 and payment_status='รอส่งมอบงาน') awaiting_delivery,round(avg(plan_percent),2) mean_plan_percent,round(avg(actual_percent),2) mean_actual_percent from public.pn2_entries group by workspace_id,report_id;
grant select on public.pn2_report_summary to anon, authenticated;
-- v4 controlled historical editing, no reason or extra confirmation required.
create table if not exists public.pn2_report_amendments(
 id bigint generated always as identity primary key,
 workspace_id uuid not null references public.pn2_workspaces(workspace_id),
 report_id text not null,changed_at timestamptz not null default now(),
 before_report jsonb not null,after_report jsonb not null,affected_reports jsonb not null
);
alter table public.pn2_report_amendments enable row level security;
drop policy if exists shared_read on public.pn2_report_amendments;
create policy shared_read on public.pn2_report_amendments for select to anon,authenticated using(true);
revoke all on public.pn2_report_amendments from anon,authenticated;
grant select on public.pn2_report_amendments to anon,authenticated;
create index if not exists pn2_amendment_report_idx on public.pn2_report_amendments(workspace_id,report_id,changed_at desc);
create or replace function public.pn2_amend_report(report_id text,entries_patch jsonb,expected_revision bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;before_r jsonb;change record;e jsonb;old_e jsonb;prior numeric;changed_actual boolean;changed_weekly boolean;later jsonb;later_e jsonb;new_weekly numeric;affected jsonb:='[]';result jsonb;ts text:=now()::text;previous_flag text;has_changes boolean:=false;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into doc,rev from public.pn2_workspaces where workspace_id=uid for update;
 if doc is null then raise exception 'ไม่พบพื้นที่ข้อมูล';end if;
 if expected_revision<>rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 select value into r from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id;
 if r is null then raise exception 'ไม่พบรายงาน';end if;before_r:=r;
 if jsonb_typeof(entries_patch)<>'object' or entries_patch='{}' then raise exception 'ไม่มีข้อมูลเปลี่ยนแปลง';end if;
 for change in select * from jsonb_each(entries_patch) loop
  if not (r->'entries' ? change.key) then raise exception 'ไม่พบสัญญาในรายงาน';end if;
  if jsonb_typeof(change.value)<>'object' or exists(select 1 from jsonb_object_keys(change.value) k where k not in ('plan','weekly','actual','note','payment','paymentDate','deliveryDate','acceptanceDate')) then raise exception 'ช่องแก้ไขไม่ถูกต้อง';end if;
  old_e:=r->'entries'->change.key;e:=old_e||change.value;
  changed_actual:=(e->>'actual')::numeric<>(old_e->>'actual')::numeric;
  changed_weekly:=(e->>'weekly')::numeric<>(old_e->>'weekly')::numeric;
  if changed_actual or changed_weekly then
   if nullif(r->>'start','') is null or nullif(r->>'end','') is null then raise exception 'รายงานไม่มีช่วงวันที่ จึงยังแก้เปอร์เซ็นต์ย้อนหลังไม่ได้';end if;
   select coalesce((x->'entries'->change.key->>'actual')::numeric,0) into prior from jsonb_array_elements(doc->'reports') x where x->>'id'<>report_id and (x->>'end')::date<(r->>'start')::date and x->'entries' ? change.key order by (x->>'end')::date desc limit 1;
   prior:=coalesce(prior,0);
   if changed_actual then e:=jsonb_set(e,'{weekly}',to_jsonb(round((e->>'actual')::numeric-prior,2)));else e:=jsonb_set(e,'{actual}',to_jsonb(round(prior+(e->>'weekly')::numeric,2)));end if;
  end if;
  if nullif(e->>'deliveryDate','')::date>nullif(e->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
  if e->>'payment'='เบิกจ่ายแล้ว' and nullif(e->>'acceptanceDate','')::date>nullif(e->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
  if e->>'payment'='เบิกจ่ายแล้ว' and nullif(e->>'paymentDate','') is not null then
   e:=jsonb_set(e,'{note}',to_jsonb(format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from (e->>'paymentDate')::date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from (e->>'paymentDate')::date)::integer],extract(year from (e->>'paymentDate')::date)::integer+543)));
  elsif old_e->>'payment'='เบิกจ่ายแล้ว' and e->>'payment'<>'เบิกจ่ายแล้ว' and e->>'note' like 'เบิกจ่ายแล้ว วันที่ %' then e:=jsonb_set(e,'{note}','""');end if;
  if e<>old_e then has_changes:=true;end if;
  r:=jsonb_set(r,array['entries',change.key],e);
  if (e->>'actual')::numeric<>(old_e->>'actual')::numeric then
   prior:=(e->>'actual')::numeric;
   for later in select value from jsonb_array_elements(doc->'reports') x where (x->>'end')::date>(r->>'end')::date and x->'entries' ? change.key order by (x->>'end')::date loop
    later_e:=later->'entries'->change.key;new_weekly:=round((later_e->>'actual')::numeric-prior,2);
    if new_weekly<0 or new_weekly>100 then raise exception 'ผลงานสะสมใหม่มากกว่าสัปดาห์ถัดไป กรุณาตรวจผลงานสะสมให้สอดคล้องกัน';end if;
    if new_weekly<>(later_e->>'weekly')::numeric then
     later:=jsonb_set(later,array['entries',change.key,'weekly'],to_jsonb(new_weekly));
     later:=later||jsonb_build_object('modifiedAt',ts,'amendedVersion',coalesce((later->>'amendedVersion')::integer,0)+1);
     affected:=affected||jsonb_build_array(later->>'id');
     doc:=jsonb_set(doc,'{reports}',(select jsonb_agg(case when x->>'id'=later->>'id' then later else x end order by ord) from jsonb_array_elements(doc->'reports') with ordinality as v(x,ord)));
    end if;prior:=(later_e->>'actual')::numeric;
   end loop;
  end if;
 end loop;
 if not has_changes then raise exception 'ยังไม่มีข้อมูลเปลี่ยนแปลง';end if;
 r:=r||jsonb_build_object('modifiedAt',ts,'amendedVersion',coalesce((r->>'amendedVersion')::integer,0)+1);
 doc:=jsonb_set(doc,'{reports}',(select jsonb_agg(case when x->>'id'=report_id then r else x end order by ord) from jsonb_array_elements(doc->'reports') with ordinality as v(x,ord)));
 doc:=jsonb_set(doc,'{amendments}',(select jsonb_agg(x order by ord) from (select x,ord from jsonb_array_elements(jsonb_build_array(jsonb_build_object('reportId',report_id,'at',ts,'beforeEntries',before_r->'entries','afterEntries',r->'entries','affectedReports',affected))||coalesce(doc->'amendments','[]')) with ordinality as v(x,ord) limit 100) kept));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',md5(random()::text||ts),'at',ts,'action','แก้ไขรายงานย้อนหลัง '||(r->>'title')))||coalesce(doc->'audit','[]'));
 previous_flag:=current_setting('pn2.amending',true);perform set_config('pn2.amending','yes',true);
 -- v6: update only the lifecycle dates actually amended, never old snapshots or other dates.
 if doc ? 'contractRegistry' then
  for change in select * from jsonb_each(entries_patch) loop
   e:=r->'entries'->change.key;
   doc:=jsonb_set(doc,'{contractRegistry}',coalesce((select jsonb_agg(case when x->>'projectId'=change.key then x
    || case when change.value ? 'deliveryDate' then jsonb_build_object('deliveryDate',coalesce(e->>'deliveryDate','')) else '{}'::jsonb end
    || case when change.value ? 'acceptanceDate' then jsonb_build_object('acceptanceDate',coalesce(e->>'acceptanceDate','')) else '{}'::jsonb end
    || case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    else x end) from jsonb_array_elements(doc->'contractRegistry') x),'[]'));
  end loop;
 end if;
 result:=public.pn2_save_workspace(doc,expected_revision);
 perform set_config('pn2.amending',coalesce(previous_flag,''),true);
 insert into public.pn2_report_amendments(workspace_id,report_id,before_report,after_report,affected_reports) values(uid,report_id,before_r,r,affected);
 select document into doc from public.pn2_workspaces where workspace_id=uid;
 return result||jsonb_build_object('document',doc);
end $$;
revoke all on function public.pn2_amend_report(text,jsonb,bigint) from public;
grant execute on function public.pn2_amend_report(text,jsonb,bigint) to anon,authenticated;

notify pgrst, 'reload schema';
commit;

-- หมวดตรวจสอบหลังติดตั้ง/อัปเกรด: ไม่เปลี่ยนข้อมูล
select 'สัญญา' item,count(*) total from public.pn2_contracts
union all select 'รายงาน',count(*) from public.pn2_reports
union all select 'ผลงานรายสัปดาห์',count(*) from public.pn2_entries
union all select 'ผู้รับจ้าง',count(*) from public.pn2_contractors
union all select 'ผู้ควบคุมงาน',count(*) from public.pn2_supervisors
union all select 'ชื่องาน',count(*) from public.pn2_work_names;

BEGIN;
-- Audited imports. Existing ordinary saves retain their historical-report guard.
CREATE TABLE IF NOT EXISTS public.pn2_import_archives(
 id uuid PRIMARY KEY,workspace_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 file_name text NOT NULL,format text NOT NULL,before_document jsonb NOT NULL,after_document jsonb NOT NULL,changes jsonb NOT NULL
);
ALTER TABLE public.pn2_import_archives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pn2_import_archives FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_import_diff(old_value jsonb,new_value jsonb,field_path text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb:='[]';k text;left_obj jsonb;right_obj jsonb;
BEGIN
 IF old_value IS NOT DISTINCT FROM new_value THEN RETURN result;END IF;
 IF (old_value IS NULL OR jsonb_typeof(old_value)='array') AND (new_value IS NULL OR jsonb_typeof(new_value)='array') AND
 NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(old_value,'[]')||coalesce(new_value,'[]')) x WHERE jsonb_typeof(x)<>'object' OR NOT x ? 'id') THEN
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO left_obj FROM jsonb_array_elements(coalesce(old_value,'[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO right_obj FROM jsonb_array_elements(coalesce(new_value,'[]')) x;
  RETURN public.pn2_import_diff(left_obj,right_obj,field_path);
 END IF;
 IF (old_value IS NULL OR jsonb_typeof(old_value)='object') AND (new_value IS NULL OR jsonb_typeof(new_value)='object') THEN
  old_value:=coalesce(old_value,'{}');new_value:=coalesce(new_value,'{}');
  FOR k IN SELECT key FROM (SELECT jsonb_object_keys(old_value) AS key UNION SELECT jsonb_object_keys(new_value)) keys ORDER BY key LOOP
   IF k=ANY(ARRAY['revision','audit','importHistory','sourceArchive','masterSequences','yearCodes','updatedAt','sourceImported','sourceFile','sourceSheet','sourceRow','createdAt']) THEN CONTINUE;END IF;
   result:=result||public.pn2_import_diff(old_value->k,new_value->k,CASE WHEN field_path='' THEN k ELSE field_path||' / '||k END);
  END LOOP;
  RETURN result;
 END IF;
 RETURN jsonb_build_array(jsonb_build_object('path',field_path,'before',old_value,'after',new_value,'kind',CASE WHEN old_value IS NULL THEN 'added' WHEN new_value IS NULL THEN 'removed' ELSE 'updated' END));
END $$;
REVOKE ALL ON FUNCTION public.pn2_import_diff(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_import_workspace(payload jsonb,expected_revision bigint,source jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';old_doc jsonb;old_rev bigint;diff jsonb;run jsonb;labels jsonb;run_id uuid:=gen_random_uuid();result jsonb;prior_mode text;file_name text;format_name text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO old_doc,old_rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 old_rev:=coalesce(old_rev,0);old_doc:=coalesce(old_doc,'{}');
 IF expected_revision<>old_rev THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนนำเข้า';END IF;
 IF jsonb_typeof(payload)<>'object' OR payload->>'version'<>'1' OR octet_length(payload::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบหรือขนาดข้อมูลนำเข้าไม่ถูกต้อง';END IF;
 file_name:=left(coalesce(nullif(source->>'fileName',''),'ไฟล์นำเข้า'),250);format_name:=source->>'format';
 IF format_name NOT IN ('JSON','CSV','XLSX') OR format_name IS NULL THEN RAISE EXCEPTION 'รูปแบบไฟล์นำเข้าไม่ถูกต้อง';END IF;
 payload:=payload-'sourceArchive';diff:=public.pn2_import_diff(old_doc,payload);
 IF jsonb_array_length(diff)=0 THEN RETURN jsonb_build_object('revision',old_rev,'document',old_doc);END IF;
 SELECT coalesce(jsonb_object_agg(x->>'id',coalesce(x->>'contract',x->>'title',x->>'name',x->>'id')),'{}') INTO labels FROM (SELECT x FROM jsonb_each(old_doc) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id' UNION ALL SELECT x FROM jsonb_each(payload) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id') names;
 run:=jsonb_build_object('labels',labels,'id',run_id,'at',now(),'fileName',file_name,'format',format_name,'changes',diff);
 payload:=payload||jsonb_build_object('importHistory',jsonb_build_array(run)||coalesce(old_doc->'importHistory','[]'::jsonb));
 INSERT INTO public.pn2_import_archives(id,workspace_id,file_name,format,before_document,after_document,changes) VALUES(run_id,uid,file_name,format_name,old_doc,payload,diff);
 prior_mode:=current_setting('pn2.importing',true);PERFORM set_config('pn2.importing','yes',true);
 result:=public.pn2_save_workspace(payload,expected_revision);
 PERFORM set_config('pn2.importing',coalesce(prior_mode,''),true);
 RETURN result||jsonb_build_object('document',payload||result);
END $$;
REVOKE ALL ON FUNCTION public.pn2_import_workspace(jsonb,bigint,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_import_workspace(jsonb,bigint,jsonb) TO anon,authenticated;

COMMIT;
