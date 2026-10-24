-- PLANNET DOH v7.1: shared single-user workspace, NO Auth dependency. Safe to rerun.
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
create index if not exists pn2_reports_scope_end_idx on public.pn2_reports(workspace_id,funding_source,fiscal_year,end_date desc);
create index if not exists pn2_contracts_scope_idx on public.pn2_contracts(workspace_id,funding_source,fiscal_year);
create index if not exists pn2_audit_workspace_rev_idx on public.pn2_audit(workspace_id,revision desc);

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

-- Preserve current scoped writes and native personnel/route data; repair legacy view writes.
begin;
DO $repair$
DECLARE f record; body text;
BEGIN
 FOR f IN SELECT p.oid,pg_get_functiondef(p.oid) definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='pn2_delete_removed_projection'
 LOOP
  body:=regexp_replace(f.definition,'DELETE FROM public\.pn2_registry_work_links[^;]*;','PERFORM 1;','gi');
  EXECUTE body;
 END LOOP;
END $repair$;
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;existing jsonb;ext jsonb;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select CASE WHEN nullif(current_setting('pn2.delta_report_ids',true),'') IS NULL THEN public.pn2_hydrate_document(document,false) ELSE public.pn2_hydrate_changed(document,current_setting('pn2.delta_report_ids')::jsonb) END,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select key,value from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=coalesce(previous_entries->e.key,payload->'settings'->'reportBaselines'->(r->>'id')->e.key);
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 insert into public.pn2_fiscal_years(workspace_id,year,code) select uid,(x.value#>>'{}')::integer,payload->'yearCodes'->>(x.value#>>'{}') from jsonb_array_elements(payload->'years') x(value) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 insert into public.pn2_categories(workspace_id,id,name) select uid,x.value->>'id',x.value->>'name' from jsonb_array_elements(payload->'categories') x(value) on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_personnel(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_personnel existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_personnel is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 if exists(select 1 from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) where nullif(x.value->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types t where t.workspace_id=uid and t.id=x.value->>'typeId')) then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
 insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) select uid,x.value->>'id',x.value->>'name',nullif(x.value->>'typeId',''),coalesce((x.value->>'archived')::boolean,false),nullif(x.value->>'code','') from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;
 end if;
 insert into public.pn2_funding_sources(workspace_id,id,name) select uid,x.value->>'id',x.value->>'name' from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]')) x(value) on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 insert into public.pn2_work_name_codes(workspace_id,work_name_id,work_code_id) select uid,x.value->>'id',c.value#>>'{}' from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) cross join lateral jsonb_array_elements(coalesce(x.value->'codeIds','[]')) c(value) on conflict do nothing;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'projects'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  insert into public.pn2_extensions(workspace_id,id,contract_id,days,approval_reference,approved,payload) select uid,x.value->>'id',p->>'id',(x.value->>'days')::integer,x.value->>'reference',(x.value->>'approved')::boolean,x.value from jsonb_array_elements(coalesce(p->'extensions','[]')) x(value) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then UPDATE public.pn2_personnel n SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM jsonb_array_elements(payload->'supervisors') x WHERE n.workspace_id=uid AND n.id=x->>'id' AND row(n.position_name,n.person_roles) IS DISTINCT FROM row(coalesce(x->>'position',''),coalesce(x->'personRoles','[]'));end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;
CREATE OR REPLACE FUNCTION public.pn2_amend_report(report_id text, entries_patch jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;before_r jsonb;change record;e jsonb;old_e jsonb;prior numeric;changed_actual boolean;changed_weekly boolean;later jsonb;later_e jsonb;new_weekly numeric;affected jsonb:='[]';result jsonb;ts text:=now()::text;previous_flag text;has_changes boolean:=false;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into doc,rev from public.pn2_workspaces where workspace_id=uid for update;
 doc:=public.pn2_hydrate_changed(doc,coalesce((select jsonb_agg(x->>'id') from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id or (exists(select 1 from jsonb_each(entries_patch) e where e.value ?| array['actual','weekly']) and exists(select 1 from jsonb_array_elements(doc->'reports') target where target->>'id'=report_id and coalesce(x->>'funding','DOH')=coalesce(target->>'funding','DOH') and x->>'year'=target->>'year' and x->>'end'>target->>'end'))),'[]'));
 if doc is null then raise exception 'ไม่พบพื้นที่ข้อมูล';end if;
 if expected_revision<>rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 select value into r from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id;
 if r is null then raise exception 'ไม่พบรายงาน';end if;before_r:=r;
 if jsonb_typeof(entries_patch)<>'object' or entries_patch='{}' then raise exception 'ไม่มีข้อมูลเปลี่ยนแปลง';end if;
 for change in select key, value from jsonb_each(entries_patch) loop
  if not (r->'entries' ? change.key) then raise exception 'ไม่พบสัญญาในรายงาน';end if;
  if jsonb_typeof(change.value)<>'object' or exists(select 1 from jsonb_object_keys(change.value) k where k not in ('plan','weekly','actual','note','payment','paymentDate','deliveryDate','acceptanceDate')) then raise exception 'ช่องแก้ไขไม่ถูกต้อง';end if;
  old_e:=r->'entries'->change.key;e:=old_e||change.value;
  changed_actual:=(e->>'actual')::numeric<>(old_e->>'actual')::numeric;
  changed_weekly:=(e->>'weekly')::numeric<>(old_e->>'weekly')::numeric;
  if changed_actual or changed_weekly then
   if nullif(r->>'start','') is null or nullif(r->>'end','') is null then raise exception 'รายงานไม่มีช่วงวันที่ จึงยังแก้เปอร์เซ็นต์ย้อนหลังไม่ได้';end if;
   select coalesce((x->'entries'->change.key->>'actual')::numeric,0) into prior from jsonb_array_elements(doc->'reports') x where x->>'id'<>report_id and (x->>'end')::date<(r->>'start')::date and x->'entries' ? change.key order by (x->>'end')::date desc limit 1;
   prior:=coalesce(prior,(doc->'settings'->'reportBaselines'->report_id->change.key->>'actual')::numeric,0);
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
 if doc ? 'contractRegistry' then
  for change in select key, value from jsonb_each(entries_patch) loop
   e:=r->'entries'->change.key;
   doc:=jsonb_set(doc,'{contractRegistry}',coalesce((select jsonb_agg(case when x->>'projectId'=change.key then x
    || case when change.value ? 'deliveryDate' then jsonb_build_object('deliveryDate',coalesce(e->>'deliveryDate','')) else '{}'::jsonb end
    || case when change.value ? 'acceptanceDate' then jsonb_build_object('acceptanceDate',coalesce(e->>'acceptanceDate','')) else '{}'::jsonb end
    || case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    else x end) from jsonb_array_elements(doc->'contractRegistry') x),'[]'));
  end loop;
 end if;
 perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 perform set_config('pn2.delta_report_ids','',true);
 perform set_config('pn2.amending',coalesce(previous_flag,''),true);
 insert into public.pn2_report_amendments(workspace_id,report_id,before_report,after_report,affected_reports) values(uid,report_id,before_r,r,affected);
 select public.pn2_hydrate_document(document,false) into doc from public.pn2_workspaces where workspace_id=uid;
 return result||jsonb_build_object('document',doc);
end $function$;
CREATE OR REPLACE FUNCTION public.pn2_release_compatibility() RETURNS jsonb
LANGUAGE sql STABLE SET search_path='' AS $check$
 SELECT jsonb_build_object('version','19.0.0','coldSnapshotsSafe',EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pn2_amend_report' AND position('pn2_hydrate_changed(doc' in p.prosrc)>0),'viewWritesSafe',NOT EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'));
$check$;
GRANT EXECUTE ON FUNCTION public.pn2_release_compatibility() TO anon,authenticated;
notify pgrst, 'reload schema';
commit;
-- P.3-01 asset register (same additive SQL as the ordered migration).
-- Additive, idempotent migration; preserve existing data.
begin;
alter table public.pn2_contractors add column if not exists address text not null default '';
alter table public.pn2_contractors add column if not exists phone text not null default '';
alter table public.pn2_work_codes add column if not exists recognition_type text not null default 'asset' check(recognition_type in ('asset','expense'));
alter table public.pn2_work_codes add column if not exists asset_category text not null default '';
alter table public.pn2_work_codes add column if not exists gl_account text not null default '';
alter table public.pn2_work_codes add column if not exists useful_life_years integer not null default 0 check(useful_life_years between 0 and 100);
alter table public.pn2_work_codes add column if not exists depreciation_rate numeric(7,2) not null default 0 check(depreciation_rate between 0 and 100);
alter table public.pn2_work_codes add column if not exists default_feature text not null default '-';
alter table public.pn2_work_codes add column if not exists variants jsonb not null default '[]'::jsonb check(jsonb_typeof(variants)='array');
create table if not exists public.pn2_p301_records(
 workspace_id uuid not null, registry_id text not null, overrides jsonb not null default '{}'::jsonb check(jsonb_typeof(overrides)='object'),
 updated_at timestamptz not null default now(),primary key(workspace_id,registry_id),
 foreign key(workspace_id,registry_id) references public.pn2_contract_registry(workspace_id,id) on delete cascade deferrable initially deferred
);
alter table public.pn2_p301_records enable row level security;
do $policy$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='pn2_p301_records' and policyname='pn2_p301_shared_read') then
  create policy pn2_p301_shared_read on public.pn2_p301_records for select to anon,authenticated using(true);
 end if;
end $policy$;
grant select on public.pn2_p301_records to anon,authenticated;
create index if not exists pn2_work_codes_asset_class_idx on public.pn2_work_codes(workspace_id,recognition_type,asset_category);
-- Generated from p301WorkRule; tests compare native rules with the frontend defaults.
create or replace function public.pn2_p301_work_rule(work_code text) returns jsonb language sql immutable set search_path=public as $rules$
 select coalesce($map${"11100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"11600":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"13000":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"14110":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"20510":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"อาคารหลัก","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}]},"20520":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"อาคารหลัก","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}]},"20530":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"ปรับปรุงอาคารหลัก","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":10,"rate":10},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":5,"rate":20},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}]},"20540":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"ปรับปรุงอาคารหลัก","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":10,"rate":10},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":5,"rate":20},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}]},"21100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21900":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22000":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"23100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"24100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"31200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31310":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31320":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31410":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31420":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31500":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31510":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"32100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"32300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]}}$map$::jsonb->work_code,'{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]}'::jsonb);
$rules$;
revoke execute on function public.pn2_p301_work_rule(text) from public,anon,authenticated;
create or replace function public.pn2_project_p301(input_doc jsonb,uid uuid) returns void language plpgsql set search_path=public as $projection$
begin
 insert into public.pn2_p301_records(workspace_id,registry_id,overrides)
 select uid,r.value->>'id',r.value->'p301' from jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]'::jsonb)) r(value)
 join public.pn2_contract_registry c on c.workspace_id=uid and c.id=r.value->>'id'
 where jsonb_typeof(r.value->'p301')='object' and r.value->'p301'<>'{}'::jsonb
 on conflict(workspace_id,registry_id) do update set overrides=excluded.overrides,updated_at=now()
 where pn2_p301_records.overrides is distinct from excluded.overrides;
 delete from public.pn2_p301_records p where p.workspace_id=uid and not exists(
 select 1 from jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]'::jsonb)) r(value)
 where r.value->>'id'=p.registry_id and jsonb_typeof(r.value->'p301')='object' and r.value->'p301'<>'{}'::jsonb);
 insert into public.pn2_work_codes(workspace_id,id,name,recognition_type,asset_category,gl_account,useful_life_years,depreciation_rate,default_feature,variants)
 select uid,rule.payload->>'id',rule.payload->>'name',coalesce(rule.payload->>'recognitionType','asset'),coalesce(rule.payload->>'assetCategory',''),coalesce(rule.payload->>'glAccount',''),coalesce(nullif(rule.payload->>'usefulLifeYears','')::integer,0),coalesce(nullif(rule.payload->>'depreciationRate','')::numeric,0),coalesce(rule.payload->>'defaultFeature','-'),coalesce(rule.payload->'variants','[]'::jsonb)
 from jsonb_array_elements(coalesce(input_doc->'workCodes','[]'::jsonb)) w(value)
 cross join lateral (select public.pn2_p301_work_rule(w.value->>'name')||w.value as payload) rule
 on conflict(workspace_id,id) do update set recognition_type=excluded.recognition_type,asset_category=excluded.asset_category,gl_account=excluded.gl_account,useful_life_years=excluded.useful_life_years,depreciation_rate=excluded.depreciation_rate,default_feature=excluded.default_feature,variants=excluded.variants
 where row(pn2_work_codes.recognition_type,pn2_work_codes.asset_category,pn2_work_codes.gl_account,pn2_work_codes.useful_life_years,pn2_work_codes.depreciation_rate,pn2_work_codes.default_feature,pn2_work_codes.variants)
 is distinct from row(excluded.recognition_type,excluded.asset_category,excluded.gl_account,excluded.useful_life_years,excluded.depreciation_rate,excluded.default_feature,excluded.variants);
end $projection$;
revoke execute on function public.pn2_project_p301(jsonb,uuid) from public,anon,authenticated;
create or replace function public.pn2_p301_projection_trigger() returns trigger language plpgsql set search_path=public as $trigger$
declare current_doc jsonb;
begin
 if old.document->'contractRegistry' is not distinct from new.document->'contractRegistry' and old.document->'workCodes' is not distinct from new.document->'workCodes' then return new;end if;
 select w.document into current_doc from public.pn2_workspaces w where w.workspace_id=new.workspace_id;
 perform public.pn2_project_p301(current_doc,new.workspace_id);
 return new;
end $trigger$;
revoke execute on function public.pn2_p301_projection_trigger() from public,anon,authenticated;
do $trigger_install$ begin
 if not exists(select 1 from pg_trigger where tgname='pn2_p301_project_at_commit' and tgrelid='public.pn2_workspaces'::regclass) then
  create constraint trigger pn2_p301_project_at_commit after update on public.pn2_workspaces deferrable initially deferred for each row execute function public.pn2_p301_projection_trigger();
 end if;
end $trigger_install$;
select public.pn2_project_p301(w.document,w.workspace_id) from public.pn2_workspaces w;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','20.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';

-- Additive, idempotent migration; preserve existing data.
begin;
-- Projection must run before the existing SECURITY DEFINER save returns.
-- A deferred invoker trigger fires as anon after that boundary on PostgreSQL.
-- Keep helpers private; do not grant public projection writes or add new elevated RPCs.
drop trigger if exists pn2_p301_project_at_commit on public.pn2_workspaces;
drop function if exists public.pn2_p301_projection_trigger();
do $install$ declare definition text;anchor text:='return jsonb_build_object(''revision'',new_rev);'; begin
 select pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure) into definition;
 if position('perform public.pn2_project_p301(payload,uid)' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Unknown save contract: cannot safely attach P301 projection';end if;
  execute replace(definition,anchor,'if old_doc->''contractRegistry'' is distinct from payload->''contractRegistry'' or old_doc->''workCodes'' is distinct from payload->''workCodes'' then perform public.pn2_project_p301(payload,uid);end if; '||anchor);
 end if;
end $install$;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','20.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0 and not exists(select 1 from pg_trigger where tgname='pn2_p301_project_at_commit' and tgrelid='public.pn2_workspaces'::regclass));
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';
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

-- v22 authoritative sheet rules; business data is seeded through the audited import owner.
begin;
create or replace function public.pn2_p301_work_rule(work_code text) returns jsonb language sql immutable set search_path=public as $rules$
 select coalesce($map${"11100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[2,3]},"11200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":10,"rate":10}],"sourceRows":[4]},"11600":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[5,6]},"12100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[7,8]},"12200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"13000":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[9,10]},"14110":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"20500":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"20510":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205010101","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"-","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}],"sourceRows":[12,13]},"20520":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205020101","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"-","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}],"sourceRows":[15,16]},"20530":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205010101","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":20,"rate":5},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":8,"rate":12.5},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}],"sourceRows":[17,18,19]},"20540":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205020101","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":20,"rate":5},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":8,"rate":12.5},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}],"sourceRows":[20,21,22]},"21000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[24]},"21200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[25]},"21300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[26]},"21400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[27]},"21500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[28]},"21600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[29]},"21700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21900":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22000":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[31]},"22150":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[32]},"22200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[33]},"22250":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[34]},"22300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[35]},"22350":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[36]},"22400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[37]},"22500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[38]},"22600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[39]},"23000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"23100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[41]},"23200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[42]},"23300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[43]},"23400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[44]},"24000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"24100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[46]},"24200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[47]},"25000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"25100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[49]},"25200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[50]},"25300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[51]},"25400":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[52]},"25500":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[53]},"25600":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[54]},"25700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[55]},"25800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[56]},"25900":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[57]},"26000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"26100":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[59]},"26200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[60]},"26300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[61]},"26400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[62]},"26500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[63]},"27000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"27100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[65]},"27200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[66]},"28000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"28100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[68]},"28200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":15,"rate":6.67}],"sourceRows":[69]},"28300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[70]},"29000":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[72]},"31200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31310":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31320":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31400":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[73]},"31410":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[74]},"31420":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[75]},"31500":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[76]},"31510":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31700":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":15,"rate":6.67}],"sourceRows":[77]},"31800":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[78]},"32000":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[79]},"32100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"32300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"33100":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[80]},"33200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[81]},"33300":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[82]},"33400":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[83]},"33700":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[84]},"33800":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[85]}}$map$::jsonb->btrim(work_code),$fallback${"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]}$fallback$::jsonb);
$rules$;
revoke execute on function public.pn2_p301_work_rule(text) from public,anon,authenticated;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','22.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null and position('perform public.pn2_project_asset_routes(input_doc,uid)' in pg_get_functiondef('public.pn2_project_p301(jsonb,uuid)'::regprocedure))>0,'depreciationSourceReady',position('"20530"' in pg_get_functiondef('public.pn2_p301_work_rule(text)'::regprocedure))>0 and position('"sourceRows"' in pg_get_functiondef('public.pn2_p301_work_rule(text)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';

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

-- v26 audit correction: paged search uses actual change rows, never downloads cold history into the page.
-- Read-only surface follows the existing shared-workspace access contract. No business data rewrite.
begin;
CREATE OR REPLACE FUNCTION public.pn2_search_history(requested_page integer DEFAULT 1,requested_query text DEFAULT '',requested_kind text DEFAULT 'all') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $history$
BEGIN
 RETURN (WITH matching AS MATERIALIZED(
  SELECT r.id,r.ordinal,r.payload,c.value,c.ord
  FROM public.pn2_import_runs r
  CROSS JOIN LATERAL jsonb_array_elements(coalesce(r.payload->'changes','[]'::jsonb)) WITH ORDINALITY c(value,ord)
  WHERE r.workspace_id='00000000-0000-0000-0000-000000000001'::uuid
   AND (coalesce(requested_kind,'all')='all' OR c.value->>'kind'=CASE requested_kind WHEN 'new' THEN 'added' WHEN 'updated' THEN 'updated' WHEN 'removed' THEN 'removed' ELSE '' END)
   AND (coalesce(btrim(requested_query),'')='' OR strpos(lower(concat_ws(' ',r.payload->>'fileName',r.payload->>'format',r.payload->>'source',c.value->>'path')),lower(btrim(requested_query)))>0)
 ), totals AS(SELECT count(*)::integer n FROM matching),
 paging AS(SELECT greatest(1,least(coalesce(requested_page,1),greatest(1,(n+24)/25))) p,n FROM totals),
 page_rows AS(SELECT id,ordinal,payload,value,ord FROM matching ORDER BY ordinal,ord LIMIT 25 OFFSET (SELECT (p-1)*25 FROM paging))
 SELECT jsonb_build_object('revision',(SELECT revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'page',(SELECT p FROM paging),'total',(SELECT n FROM paging),'pages',greatest(1,((SELECT n FROM paging)+24)/25),
 'rows',coalesce((SELECT jsonb_agg(jsonb_build_object('run',payload-'changes','changeIndex',ord-1,'change',value||jsonb_build_object('before',public.pn2_history_preview(value->'before'),'after',public.pn2_history_preview(value->'after'))) ORDER BY ordinal,ord) FROM page_rows),'[]'::jsonb),
 'audit',coalesce((SELECT jsonb_agg(row_to_json(t)) FROM (SELECT action,created_at AS at FROM public.pn2_audit WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid ORDER BY id DESC LIMIT 20) t),'[]'::jsonb)));
END;
$history$;
REVOKE ALL ON FUNCTION public.pn2_search_history(integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_search_history(integer,text,text) TO anon,authenticated;
-- This index duplicates the primary key exactly. Keep the primary key and reverse lookup index.
DROP INDEX IF EXISTS public.pn2_entries_report_contract_idx;
-- Existing readiness flags stay backward compatible; the new client requires paged audit search too.
CREATE OR REPLACE FUNCTION public.pn2_release_compatibility() RETURNS jsonb LANGUAGE sql STABLE SET search_path=public AS $check$
 SELECT jsonb_build_object('version','23.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'auditSearchReady',to_regprocedure('public.pn2_search_history(integer,text,text)') is not null);
$check$;
commit;
notify pgrst, 'reload schema';
-- PN-COMPLETE-ORDERED-MIGRATIONS: generated by node tools.mjs schema
-- Source: 20261015070325_optimize_workspace_timeouts.sql
-- PLANNET DOH: bounded RPC timeouts and cached report validation.
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;
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
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 report_list:=payload->'reports';project_list:=payload->'projects';
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then raise exception 'กรุณาระบุวันที่เบิกจ่าย';end if;
    select x->'entries'->e.key into prev from jsonb_array_elements(report_list) x where nullif(x->>'end','')::date<(r->>'start')::date and x->'entries' ? e.key order by nullif(x->>'end','')::date desc limit 1;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
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
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
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
end $function$
;
CREATE OR REPLACE FUNCTION public.pn2_load_workspace()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $load$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 IF doc->>'revision'=rev::text THEN RETURN doc;END IF;
 RETURN doc||jsonb_build_object('revision',rev);
END $load$;

-- PostgREST reads these per-RPC limits after schema reload; other endpoints retain default limits.
ALTER FUNCTION public.pn2_load_workspace() SET statement_timeout='15s';
ALTER FUNCTION public.pn2_save_workspace(jsonb,bigint) SET statement_timeout='25s';
ALTER FUNCTION public.pn2_import_workspace(jsonb,bigint,jsonb) SET statement_timeout='25s';
ALTER FUNCTION public.pn2_amend_report(text,jsonb,bigint) SET statement_timeout='25s';
NOTIFY pgrst,'reload schema';

-- Source: 20261015073328_fix_weekly_report_creation.sql
-- Paid legacy draft compatibility and operational workspace performance.
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 report_list:=payload->'reports';project_list:=payload->'projects';
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(report_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=previous_entries->e.key;
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
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
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
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
end $function$
;

-- Keep the compatible full backup RPC; the operational screen does not need multi-MB audit diffs.
CREATE OR REPLACE FUNCTION public.pn2_load_active_workspace()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='15s' AS $active$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 RETURN (doc-'importHistory')||jsonb_build_object('revision',rev);
END $active$;
CREATE OR REPLACE FUNCTION public.pn2_load_import_history()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' SET statement_timeout='15s' AS $history$
 SELECT jsonb_build_object('revision',revision,'importHistory',coalesce(document->'importHistory','[]'::jsonb)) FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid
$history$;
REVOKE ALL ON FUNCTION public.pn2_load_active_workspace() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pn2_load_import_history() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_load_active_workspace(),public.pn2_load_import_history() TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Source: 20261015083628_scoped_workspace_patch.sql
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 report_list:=payload->'reports';project_list:=payload->'projects';
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(report_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=previous_entries->e.key;
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 -- Weekly and settings edits do not rebuild unchanged contracts, masters or historical entries.
 if old_doc is not null and not exists (
  select 1 from unnest(array['projects','contractRegistry','categories','years','yearCodes','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) k where old_doc->k is distinct from payload->k
 ) then
  delete from public.pn2_entries where workspace_id=uid and report_id in (select key from jsonb_each(old_reports) where not new_reports ? key);
  delete from public.pn2_reports where workspace_id=uid and not new_reports ? id;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  delete from public.pn2_entries where workspace_id=uid and report_id=r->>'id';
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source;
  update public.pn2_reports set funding_source=coalesce(r->>'funding','DOH') where workspace_id=uid and id=r->>'id';
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,r->'snapshots'->entry_row.key,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row;
 end loop;
  insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','บันทึกข้อมูล'));
  return jsonb_build_object('revision',new_rev);
 end if;
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
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
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
end $function$
;


CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL,requested_year integer DEFAULT NULL,requested_report text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='15s' AS $scope$
DECLARE doc jsonb;rev bigint;yr integer;fund text;report_rows jsonb;chosen text;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 yr:=requested_year;
 IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max((x->>'year')::integer) INTO yr FROM jsonb_array_elements(doc->'projects') x;END IF;
 yr:=coalesce(yr,(SELECT max(value::integer) FROM jsonb_array_elements_text(doc->'years')),2569);
 fund:=requested_funding;
 IF fund IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'fundingSources') x WHERE x->>'id'=fund) THEN
  SELECT coalesce(x->>'funding','DOH') INTO fund FROM jsonb_array_elements(doc->'projects') x WHERE (x->>'year')::integer=yr ORDER BY (coalesce(x->>'funding','DOH')='DOH') DESC LIMIT 1;
 END IF;fund:=coalesce(fund,'DOH');
 SELECT x->>'id' INTO chosen FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(x,ord)
 WHERE coalesce(x->>'funding','DOH')=fund AND coalesce((x->>'year')::integer,(SELECT (value->>'year')::integer FROM jsonb_each(coalesce(x->'snapshots','{}')) LIMIT 1))=yr
 ORDER BY (x->>'id'=requested_report) DESC NULLS LAST,nullif(x->>'end','') DESC,ord LIMIT 1;
 SELECT coalesce(jsonb_agg(CASE WHEN x->>'id'=chosen THEN x ELSE
 (x-'entries'-'snapshots')||jsonb_build_object('entries',CASE WHEN report_year=yr AND report_funding=fund THEN x->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'year',report_year,'funding',report_funding,'_unloaded',true,'_entryCount',jsonb_object_length_compat) END ORDER BY ord),'[]'::jsonb) INTO report_rows
 FROM (SELECT x,ord,coalesce((x->>'year')::integer,(SELECT (value->>'year')::integer FROM jsonb_each(coalesce(x->'snapshots','{}')) LIMIT 1)) AS report_year,
 coalesce(x->>'funding','DOH') AS report_funding,(SELECT count(*) FROM jsonb_object_keys(coalesce(x->'entries','{}'))) AS jsonb_object_length_compat
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(x,ord)) rows;
 RETURN (doc-'importHistory')||jsonb_build_object('reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen));
END $scope$;

CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb,expected_revision bigint,action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 RETURN public.pn2_save_workspace(doc,expected_revision);
END $patch$;
REVOKE ALL ON FUNCTION public.pn2_load_scope(text,integer,text),public.pn2_patch_workspace(jsonb,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_load_scope(text,integer,text),public.pn2_patch_workspace(jsonb,bigint,text) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Source: 20261015085440_optimize_patch_validation.sql
-- Restrict validation to server-merged delta reports; full saves retain full validation.
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=previous_entries->e.key;
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 -- Weekly and settings edits do not rebuild unchanged contracts, masters or historical entries.
 if old_doc is not null and not exists (
  select 1 from unnest(array['projects','contractRegistry','categories','years','yearCodes','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) k where old_doc->k is distinct from payload->k
 ) then
  delete from public.pn2_entries where workspace_id=uid and report_id in (select key from jsonb_each(old_reports) where not new_reports ? key);
  delete from public.pn2_reports where workspace_id=uid and id in (select key from jsonb_each(old_reports)) and not new_reports ? id;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  delete from public.pn2_entries where workspace_id=uid and report_id=r->>'id';
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source;
  update public.pn2_reports set funding_source=coalesce(r->>'funding','DOH') where workspace_id=uid and id=r->>'id';
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,r->'snapshots'->entry_row.key,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row;
 end loop;
  insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','บันทึกข้อมูล'));
  return jsonb_build_object('revision',new_rev);
 end if;
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
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
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
end $function$
;



CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb,expected_revision bigint,action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;prior_delta text;delta_ids jsonb;result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 prior_delta:=current_setting('pn2.delta_report_ids',true);
 IF NOT EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) key WHERE key<>'reports')
 AND NOT EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'values','{}')) key WHERE key<>ALL(ARRAY['settings','issues','masterSequences'])) THEN
  SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' AS id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) ids;
  PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 END IF;
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result;
END $patch$;

NOTIFY pgrst,'reload schema';

-- Source: 20261015124953_compact_csv_import.sql
-- Compact audited CSV/XLSX import. Merge against authoritative full document inside the transaction; never transmit unloaded reports.
CREATE OR REPLACE FUNCTION public.pn2_import_changes(changes jsonb,expected_revision bigint,source jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;result jsonb;audit_entry jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 IF source->>'format' NOT IN ('CSV','XLSX') OR source->>'format' IS NULL THEN RAISE EXCEPTION 'ใช้สำหรับ CSV หรือ XLSX เท่านั้น';END IF;
 audit_entry:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action','นำเข้าไฟล์ '||left(coalesce(source->>'fileName','CSV'),250));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(audit_entry)||coalesce(doc->'audit','[]'));
 result:=public.pn2_import_workspace(doc,expected_revision,source);
 IF (result->>'revision')::bigint>rev THEN RETURN (result-'document')||jsonb_build_object('importRun',result->'document'->'importHistory'->0,'auditEntry',audit_entry);END IF;
 RETURN result-'document';
END $patch$;
REVOKE ALL ON FUNCTION public.pn2_import_changes(jsonb,bigint,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_import_changes(jsonb,bigint,jsonb) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Source: 20261015171321_v8_storage_and_incremental_projection.sql
-- Incremental projections: keep primary/foreign keys, validate with the existing domain rules.
ALTER TABLE public.pn2_contractors ADD COLUMN IF NOT EXISTS address text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_contractors ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_fiscal_years ALTER CONSTRAINT pn2_fiscal_years_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_categories ALTER CONSTRAINT pn2_categories_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_fiscal_year_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_category_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_extensions ALTER CONSTRAINT pn2_extensions_workspace_id_contract_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_reports_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_entries ALTER CONSTRAINT pn2_entries_workspace_id_report_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_entries ALTER CONSTRAINT pn2_entries_workspace_id_contract_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contractors ALTER CONSTRAINT pn2_contractors_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_names ALTER CONSTRAINT pn2_work_names_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_funding_sources ALTER CONSTRAINT pn2_funding_sources_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_contractor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_supervisor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_workname_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_worktype_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_contractor_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_work_type_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_budget_accounts ALTER CONSTRAINT pn2_budget_accounts_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_codes ALTER CONSTRAINT pn2_work_codes_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_name_codes ALTER CONSTRAINT pn2_work_name_codes_workspace_id_work_name_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_name_codes ALTER CONSTRAINT pn2_work_name_codes_workspace_id_work_code_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_budget_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_code_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_job_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_supervisor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_project_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_registry_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_names ALTER CONSTRAINT pn2_work_name_type_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_report_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_report_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_report_amendments ALTER CONSTRAINT pn2_report_amendments_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
CREATE OR REPLACE FUNCTION public.pn2_delete_removed_projection(input_doc jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $del$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';
BEGIN
DELETE FROM public.pn2_contractors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractors','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_supervisors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'supervisors','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_types t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workTypes','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_names t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workNames','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workCodes','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_budget_accounts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'budgetAccounts','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_categories t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'categories','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_funding_sources t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'fundingSources','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_contracts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'projects','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_reports t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'reports','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_contract_registry t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_fiscal_years t WHERE workspace_id=uid AND NOT input_doc->'years' @> to_jsonb(ARRAY[t.year]);
DELETE FROM public.pn2_entries t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'reports') r WHERE r->>'id'=t.report_id AND r->'entries' ? t.contract_id);
DELETE FROM public.pn2_extensions t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'projects') p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p->'extensions','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_name_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'workNames') w WHERE w->>'id'=t.work_name_id AND w->'codeIds' @> to_jsonb(ARRAY[t.work_code_id]));
DELETE FROM public.pn2_registry_work_links t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'contractRegistry') r WHERE r->>'workCode'=t.work_code AND r->>'title'=t.title);
END $del$;
REVOKE ALL ON FUNCTION public.pn2_delete_removed_projection(jsonb) FROM PUBLIC;
-- Restrict validation to server-merged delta reports; full saves retain full validation.
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=previous_entries->e.key;
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload);
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_supervisors is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=excluded.work_type_id where pn2_registry_work_links is distinct from excluded;end if;
 end loop;

 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;



-- Cold immutable snapshots and append-only import history are kept outside the hot document.
CREATE TABLE IF NOT EXISTS public.pn2_import_runs(workspace_id uuid NOT NULL,id text NOT NULL,ordinal bigint NOT NULL,payload jsonb NOT NULL,PRIMARY KEY(workspace_id,id));
CREATE TABLE IF NOT EXISTS public.pn2_report_snapshots(workspace_id uuid NOT NULL,report_id text NOT NULL,payload jsonb NOT NULL,PRIMARY KEY(workspace_id,report_id));
ALTER TABLE public.pn2_import_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pn2_report_snapshots ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_hydrate_document(doc jsonb,with_history boolean DEFAULT false) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $hydrate$
 SELECT CASE WHEN doc IS NULL THEN NULL ELSE
 (doc-'importHistory')||jsonb_build_object('reports',(SELECT coalesce(jsonb_agg((r-'_storedSnapshot')||coalesce(s.payload,'{}') ORDER BY ord),'[]') FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id'))
 ||CASE WHEN with_history THEN jsonb_build_object('importHistory',coalesce(doc->'importHistory',(SELECT jsonb_agg(payload ORDER BY ordinal) FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'[]')) ELSE '{}'::jsonb END END
$hydrate$;
REVOKE ALL ON FUNCTION public.pn2_hydrate_document(jsonb,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_hydrate_document(jsonb,boolean) TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_compact_document() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $compact$
DECLARE reports jsonb;r jsonb;ord bigint;bits jsonb;
BEGIN
 IF NEW.document ? 'importHistory' THEN
  INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload)
  SELECT NEW.workspace_id,x->>'id',pos,x FROM jsonb_array_elements(NEW.document->'importHistory') WITH ORDINALITY v(x,pos) WHERE nullif(x->>'id','') IS NOT NULL
  ON CONFLICT(workspace_id,id) DO UPDATE SET ordinal=excluded.ordinal,payload=excluded.payload WHERE row(pn2_import_runs.ordinal,pn2_import_runs.payload) IS DISTINCT FROM row(excluded.ordinal,excluded.payload);
 END IF;
 reports:='[]';
 FOR r,ord IN SELECT x,pos FROM jsonb_array_elements(NEW.document->'reports') WITH ORDINALITY v(x,pos) LOOP
  bits:='{}';IF r ? 'snapshots' THEN bits:=bits||jsonb_build_object('snapshots',r->'snapshots');END IF;IF r ? 'settingsSnapshot' THEN bits:=bits||jsonb_build_object('settingsSnapshot',r->'settingsSnapshot');END IF;
  IF bits<>'{}' THEN INSERT INTO public.pn2_report_snapshots VALUES(NEW.workspace_id,r->>'id',bits) ON CONFLICT(workspace_id,report_id) DO UPDATE SET payload=excluded.payload WHERE pn2_report_snapshots.payload IS DISTINCT FROM excluded.payload;END IF;
  reports:=reports||jsonb_build_array((r-'snapshots'-'settingsSnapshot')||jsonb_build_object('_storedSnapshot',true));
 END LOOP;
 DELETE FROM public.pn2_report_snapshots s WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(reports) z WHERE z->>'id'=s.report_id);
 NEW.document:=(NEW.document-'importHistory')||jsonb_build_object('reports',reports);RETURN NEW;
END $compact$;
REVOKE ALL ON FUNCTION public.pn2_compact_document() FROM PUBLIC;
CREATE TRIGGER pn2_compact_workspace BEFORE INSERT OR UPDATE OF document ON public.pn2_workspaces FOR EACH ROW EXECUTE FUNCTION public.pn2_compact_document();
-- Migrate the existing document without changing its revision or any user data.
UPDATE public.pn2_workspaces SET document=document;
-- Keep established validation and amendment logic; hydrate only inside RPCs that need it.
DO $adapt$
DECLARE sig text;body text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['pn2_save_workspace(jsonb,bigint)','pn2_patch_workspace(jsonb,bigint,text)','pn2_import_changes(jsonb,bigint,jsonb)','pn2_amend_report(text,jsonb,bigint)','pn2_import_workspace(jsonb,bigint,jsonb)'] LOOP
  body:=pg_get_functiondef(('public.'||sig)::regprocedure);
  body:=regexp_replace(body,'select document,revision','select public.pn2_hydrate_document(document,false),revision','gi');
  -- JSON replacement remains fully audited; CSV records only the changed data, never repeated full history.
  IF sig='pn2_import_workspace(jsonb,bigint,jsonb)' THEN
   body:=replace(body,$old$old_doc,payload,diff);$old$,$new$jsonb_build_object('storageFormat','delta-v1','changes',diff),jsonb_build_object('storageFormat','delta-v1','run',run),diff);$new$);
   body:=replace(body,$old$coalesce(old_doc->'importHistory','[]'::jsonb)$old$,$new$coalesce((select jsonb_agg(ir.payload order by ir.ordinal) from public.pn2_import_runs ir where ir.workspace_id=uid),'[]'::jsonb)$new$);
  END IF;
  EXECUTE body;
 END LOOP;
END $adapt$;
CREATE OR REPLACE FUNCTION public.pn2_load_workspace() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$SELECT public.pn2_hydrate_document(document,true)||jsonb_build_object('revision',revision) FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
CREATE OR REPLACE FUNCTION public.pn2_load_active_workspace() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$SELECT public.pn2_hydrate_document(document,false)||jsonb_build_object('revision',revision) FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
CREATE OR REPLACE FUNCTION public.pn2_load_import_history() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$SELECT jsonb_build_object('revision',revision,'importHistory',coalesce((SELECT jsonb_agg(payload ORDER BY ordinal) FROM public.pn2_import_runs WHERE workspace_id=w.workspace_id),'[]')) FROM public.pn2_workspaces w WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
-- Scope reads only one frozen snapshot; older metadata does not carry logo copies.
DO $scope$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 body:=replace(body,$old$WHEN x->>'id'=chosen THEN x ELSE$old$,$new$WHEN x->>'id'=chosen THEN (x-'_storedSnapshot')||coalesce((select payload from public.pn2_report_snapshots where workspace_id='00000000-0000-0000-0000-000000000001'::uuid and report_id=chosen),'{}'::jsonb) ELSE$new$);
 body:=replace(body,'SECURITY INVOKER','SECURITY DEFINER');EXECUTE body;
END $scope$;
NOTIFY pgrst,'reload schema';
-- Compact scope with the selected report, six recent entry sets and explicit prior carry context.
CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL,requested_year integer DEFAULT NULL,requested_report text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $scope8$
DECLARE doc jsonb;rev bigint;yr integer;fund text;chosen text;selected_start text;recent jsonb;report_rows jsonb;prior jsonb;latest jsonb;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 yr:=requested_year;IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max((p->>'year')::integer) INTO yr FROM jsonb_array_elements(doc->'projects') p;END IF;
 yr:=coalesce(yr,2569);fund:=requested_funding;
 IF fund IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'fundingSources') p WHERE p->>'id'=fund) THEN SELECT coalesce(p->>'funding','DOH') INTO fund FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr ORDER BY (coalesce(p->>'funding','DOH')='DOH') DESC LIMIT 1;END IF;fund:=coalesce(fund,'DOH');
 SELECT r->>'id',r->>'start' INTO chosen,selected_start FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY (r->>'id'=requested_report) DESC NULLS LAST,nullif(r->>'end','') DESC NULLS LAST,ord LIMIT 1;
 SELECT coalesce(jsonb_agg(id),'[]') INTO recent FROM (SELECT r->>'id' id FROM jsonb_array_elements(doc->'reports') r WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY nullif(r->>'end','') DESC NULLS LAST LIMIT 6) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO prior FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND r->>'end'<selected_start ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO latest FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND nullif(r->>'end','') IS NOT NULL ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_agg(CASE WHEN r->>'id'=chosen THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE
 (r-'entries'-'snapshots'-'settingsSnapshot'-'_storedSnapshot')||jsonb_build_object('entries',CASE WHEN recent @> jsonb_build_array(r->>'id') THEN r->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'_unloaded',true,'_entryCount',(SELECT count(*) FROM jsonb_object_keys(r->'entries')),'_missingPaymentDates',(SELECT coalesce(jsonb_agg(jsonb_build_array(e.key,e.value)),'[]') FROM jsonb_each(r->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND coalesce(e.value->>'paymentDate','')='')) END ORDER BY ord),'[]') INTO report_rows
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 RETURN (doc-'importHistory')||jsonb_build_object('reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen,'previousEntries',prior,'latestEntries',latest));
END $scope8$;
CREATE OR REPLACE FUNCTION public.pn2_load_report_detail(requested_report text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $detail$
 SELECT jsonb_build_object('revision',w.revision,'report',(r-'_storedSnapshot')||coalesce(s.payload,'{}')) FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'reports') r LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id=w.workspace_id AND s.report_id=r->>'id' WHERE w.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND r->>'id'=requested_report
$detail$;
REVOKE ALL ON FUNCTION public.pn2_load_report_detail(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_load_report_detail(text) TO anon,authenticated;
CREATE UNIQUE INDEX IF NOT EXISTS pn2_one_name_per_work_code ON public.pn2_work_name_codes(workspace_id,work_code_id);
NOTIFY pgrst,'reload schema';
CREATE OR REPLACE FUNCTION public.pn2_save_entry(report_id text,contract_id text,entry jsonb,changes jsonb,expected_revision bigint,action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $entry8$
DECLARE selected_report jsonb;patch jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-000000000001',0));
 IF jsonb_typeof(entry)<>'object' OR octet_length(entry::text)>100000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลผลงานไม่ถูกต้อง';END IF;
 SELECT (public.pn2_load_report_detail(report_id))->'report' INTO selected_report;
 IF selected_report IS NULL OR NOT selected_report->'entries' ? contract_id THEN RAISE EXCEPTION 'ไม่พบสัญญาในรายงาน';END IF;
 IF coalesce((selected_report->>'locked')::boolean,false) THEN RAISE EXCEPTION 'รายงานถูกปิดแล้ว ใช้แก้ไขรายงานย้อนหลัง';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) k WHERE k<>ALL(ARRAY['projects','contractRegistry'])) OR coalesce(changes->'values','{}')<>'{}' THEN RAISE EXCEPTION 'ชุดข้อมูลแก้ไขผลงานไม่ถูกต้อง';END IF;
 selected_report:=jsonb_set(selected_report,ARRAY['entries',contract_id],entry);
 patch:=coalesce(changes,'{}')||jsonb_build_object('collections',coalesce(changes->'collections','{}')||jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(selected_report),'remove','[]'::jsonb)));
 RETURN public.pn2_patch_workspace(patch,expected_revision,action);
END $entry8$;
REVOKE ALL ON FUNCTION public.pn2_save_entry(text,text,jsonb,jsonb,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_save_entry(text,text,jsonb,jsonb,bigint,text) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
DO $amend8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 body:=replace(body,'result:=public.pn2_save_workspace(doc,expected_revision);',$new$perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);result:=public.pn2_save_workspace(doc,expected_revision);perform set_config('pn2.delta_report_ids','',true);$new$);
 body:=replace(body,'select document into doc','select public.pn2_hydrate_document(document,false) into doc');EXECUTE body;
END $amend8$;
CREATE OR REPLACE FUNCTION public.pn2_amend_report_delta(report_id text,entries_patch jsonb,expected_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $amenddelta$
DECLARE before_doc jsonb;after_doc jsonb;result jsonb;updates jsonb;registry_updates jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-000000000001',0));
 SELECT document INTO before_doc FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 result:=public.pn2_amend_report(report_id,entries_patch,expected_revision);after_doc:=result->'document';
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',n->>'id','metadata',n-'entries'-'snapshots'-'settingsSnapshot','entries',(SELECT coalesce(jsonb_object_agg(e.key,e.value),'{}') FROM jsonb_each(n->'entries') e WHERE e.value IS DISTINCT FROM o->'entries'->e.key))),'[]') INTO updates FROM jsonb_array_elements(after_doc->'reports') n JOIN jsonb_array_elements(before_doc->'reports') o ON n->>'id'=o->>'id' WHERE (n-'snapshots'-'settingsSnapshot'-'_storedSnapshot') IS DISTINCT FROM (o-'_storedSnapshot');
 SELECT coalesce(jsonb_agg(n),'[]') INTO registry_updates FROM jsonb_array_elements(after_doc->'contractRegistry') n LEFT JOIN jsonb_array_elements(before_doc->'contractRegistry') o ON n->>'id'=o->>'id' WHERE n IS DISTINCT FROM o;
 RETURN jsonb_build_object('revision',result->'revision','reports',updates,'registry',registry_updates,'amendment',after_doc->'amendments'->0,'auditEntry',after_doc->'audit'->0);
END $amenddelta$;
REVOKE ALL ON FUNCTION public.pn2_amend_report_delta(text,jsonb,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_amend_report_delta(text,jsonb,bigint) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Snapshot source has been preserved in pn2_report_snapshots; avoid a second mutable copy in entry projections.
UPDATE public.pn2_entries SET contract_snapshot=NULL WHERE contract_snapshot IS NOT NULL;
ALTER TABLE public.pn2_contractors ADD CONSTRAINT pn2_contractor_contact_lengths CHECK(length(address)<=2000 AND length(phone)<=80);

DO $labels8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'run:=jsonb_build_object(',$new$labels:=(select coalesce(jsonb_object_agg(e.key,e.value),'{}') from jsonb_each(labels) e where exists(select 1 from jsonb_array_elements(diff) d where e.key=ANY(string_to_array(d->>'path',' / '))));run:=jsonb_build_object($new$);EXECUTE body;
END $labels8$;
ALTER TABLE public.pn2_import_runs ADD CONSTRAINT pn2_import_runs_workspace_fk FOREIGN KEY(workspace_id) REFERENCES public.pn2_workspaces(workspace_id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE public.pn2_report_snapshots ADD CONSTRAINT pn2_report_snapshots_workspace_fk FOREIGN KEY(workspace_id) REFERENCES public.pn2_workspaces(workspace_id) DEFERRABLE INITIALLY DEFERRED;
CREATE OR REPLACE FUNCTION public.pn2_load_report_detail(requested_report text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $detail8$
 SELECT jsonb_build_object('revision',w.revision,'report',(r-'_storedSnapshot')||coalesce(s.payload,'{}'),'previousEntries',(SELECT coalesce(jsonb_object_agg(key,value),'{}') FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(w.document->'reports') p CROSS JOIN LATERAL jsonb_each(p->'entries') e WHERE coalesce(p->>'funding','DOH')=coalesce(r->>'funding','DOH') AND p->>'year'=r->>'year' AND p->>'end'<r->>'start' ORDER BY e.key,p->>'end' DESC) prior)) FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'reports') r LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id=w.workspace_id AND s.report_id=r->>'id' WHERE w.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND r->>'id'=requested_report
$detail8$;
ALTER TABLE public.pn2_report_snapshots ADD CONSTRAINT pn2_report_snapshots_report_fk FOREIGN KEY(workspace_id,report_id) REFERENCES public.pn2_reports(workspace_id,id) DEFERRABLE INITIALLY DEFERRED;
NOTIFY pgrst,'reload schema';

-- Source: 20261015174440_optimize_hydrated_backup_loading.sql
-- Materialize each cold collection once and insert revision before attaching the large history.
CREATE OR REPLACE FUNCTION public.pn2_hydrate_document(doc jsonb,with_history boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $hydrate8$
DECLARE hydrated_reports jsonb;history_rows jsonb;result jsonb;
BEGIN
 IF doc IS NULL THEN RETURN NULL;END IF;
 SELECT coalesce(jsonb_agg((r-'_storedSnapshot')||coalesce(s.payload,'{}') ORDER BY ord),'[]') INTO hydrated_reports
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 result:=jsonb_set(doc-'importHistory','{reports}',hydrated_reports);
 IF with_history THEN
  history_rows:=doc->'importHistory';
  IF history_rows IS NULL THEN SELECT coalesce(jsonb_agg(ir.payload ORDER BY ir.ordinal),'[]') INTO history_rows FROM public.pn2_import_runs ir WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;END IF;
  result:=jsonb_set(result,'{importHistory}',history_rows);
 END IF;
 RETURN result;
END $hydrate8$;
CREATE OR REPLACE FUNCTION public.pn2_load_workspace() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='25s' AS $load8$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 RETURN public.pn2_hydrate_document(jsonb_set(doc,'{revision}',to_jsonb(rev)),true);
END $load8$;
CREATE OR REPLACE FUNCTION public.pn2_load_active_workspace() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='15s' AS $active8$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 RETURN public.pn2_hydrate_document(jsonb_set(doc,'{revision}',to_jsonb(rev)),false);
END $active8$;
ALTER FUNCTION public.pn2_load_import_history() SET statement_timeout='25s';
-- The frozen snapshot has one authoritative source; clear obsolete relational copies.
UPDATE public.pn2_reports SET payload=payload-'settingsSnapshot' WHERE payload ? 'settingsSnapshot';
NOTIFY pgrst,'reload schema';

-- Source: 20261015174753_minimize_scope_quality_metadata.sql
-- Quality counts need the contract identity, not every old note and percentage.
DO $quality8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 body:=replace(body,'jsonb_build_array(e.key,e.value)',$new$jsonb_build_array(e.key,'{}'::jsonb)$new$);
 EXECUTE body;
END $quality8$;
NOTIFY pgrst,'reload schema';

-- Source: 20261015175551_skip_unchanged_projection_collections.sql
-- Skip unchanged collections and find deleted entry keys once rather than scanning every stored entry.
CREATE OR REPLACE FUNCTION public.pn2_delete_removed_projection(input_doc jsonb,previous_doc jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $delete8$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';
BEGIN
IF previous_doc->'contractors' IS DISTINCT FROM input_doc->'contractors' THEN DELETE FROM public.pn2_contractors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractors','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'supervisors' IS DISTINCT FROM input_doc->'supervisors' THEN DELETE FROM public.pn2_supervisors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'supervisors','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workTypes' IS DISTINCT FROM input_doc->'workTypes' THEN DELETE FROM public.pn2_work_types t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workTypes','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workNames' IS DISTINCT FROM input_doc->'workNames' THEN DELETE FROM public.pn2_work_names t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workNames','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workCodes' IS DISTINCT FROM input_doc->'workCodes' THEN DELETE FROM public.pn2_work_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workCodes','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'budgetAccounts' IS DISTINCT FROM input_doc->'budgetAccounts' THEN DELETE FROM public.pn2_budget_accounts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'budgetAccounts','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'categories' IS DISTINCT FROM input_doc->'categories' THEN DELETE FROM public.pn2_categories t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'categories','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'fundingSources' IS DISTINCT FROM input_doc->'fundingSources' THEN DELETE FROM public.pn2_funding_sources t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'fundingSources','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'projects' IS DISTINCT FROM input_doc->'projects' THEN DELETE FROM public.pn2_contracts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'projects','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'reports' IS DISTINCT FROM input_doc->'reports' THEN DELETE FROM public.pn2_reports t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'reports','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'contractRegistry' IS DISTINCT FROM input_doc->'contractRegistry' THEN DELETE FROM public.pn2_contract_registry t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'years' IS DISTINCT FROM input_doc->'years' THEN DELETE FROM public.pn2_fiscal_years t WHERE workspace_id=uid AND NOT input_doc->'years' @> to_jsonb(ARRAY[t.year]);END IF;
IF previous_doc->'reports' IS DISTINCT FROM input_doc->'reports' THEN
 WITH old_rows AS MATERIALIZED(SELECT r->>'id' id,r->'entries' entries FROM jsonb_array_elements(coalesce(previous_doc->'reports','[]')) r),
 new_rows AS MATERIALIZED(SELECT r->>'id' id,r->'entries' entries FROM jsonb_array_elements(input_doc->'reports') r),
 changed AS MATERIALIZED(SELECT o.id,o.entries AS old_entries,coalesce(n.entries,'{}') AS new_entries FROM old_rows o LEFT JOIN new_rows n ON o.id=n.id WHERE o.entries IS DISTINCT FROM n.entries),
 removed AS(SELECT c.id,k FROM changed c CROSS JOIN LATERAL jsonb_object_keys(c.old_entries) k WHERE NOT c.new_entries ? k)
 DELETE FROM public.pn2_entries t USING removed WHERE t.workspace_id=uid AND t.report_id=removed.id AND t.contract_id=removed.k;
END IF;
IF previous_doc->'projects' IS DISTINCT FROM input_doc->'projects' THEN DELETE FROM public.pn2_extensions t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'projects') p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p->'extensions','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workNames' IS DISTINCT FROM input_doc->'workNames' THEN DELETE FROM public.pn2_work_name_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'workNames') w WHERE w->>'id'=t.work_name_id AND w->'codeIds' @> to_jsonb(ARRAY[t.work_code_id]));END IF;
IF previous_doc->'contractRegistry' IS DISTINCT FROM input_doc->'contractRegistry' THEN DELETE FROM public.pn2_registry_work_links t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'contractRegistry') r WHERE r->>'workCode'=t.work_code AND r->>'title'=t.title);END IF;
END $delete8$;
REVOKE ALL ON FUNCTION public.pn2_delete_removed_projection(jsonb,jsonb) FROM PUBLIC;
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select public.pn2_hydrate_document(document,false),revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=previous_entries->e.key;
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_supervisors is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=excluded.work_type_id where pn2_registry_work_links is distinct from excluded;end if;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;




NOTIFY pgrst,'reload schema';

-- Compact imports append a single cold run without reassembling all prior history.
-- Compact audited CSV/XLSX import. Merge against authoritative full document inside the transaction; never transmit unloaded reports.
CREATE OR REPLACE FUNCTION public.pn2_import_changes(changes jsonb,expected_revision bigint,source jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;before_doc jsonb;diff jsonb;labels jsonb;run jsonb;run_id uuid:=gen_random_uuid();prior_import text;prior_delta text;delta_ids jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;result jsonb;audit_entry jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT public.pn2_hydrate_document(document,false),revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 before_doc:=doc;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 IF source->>'format' NOT IN ('CSV','XLSX') OR source->>'format' IS NULL THEN RAISE EXCEPTION 'ใช้สำหรับ CSV หรือ XLSX เท่านั้น';END IF;
 audit_entry:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action','นำเข้าไฟล์ '||left(coalesce(source->>'fileName','CSV'),250));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(audit_entry)||coalesce(doc->'audit','[]'));
 diff:=public.pn2_import_diff(before_doc,doc);
 IF jsonb_array_length(diff)=0 THEN RETURN jsonb_build_object('revision',rev);END IF;
 SELECT coalesce(jsonb_object_agg(x->>'id',coalesce(x->>'contract',x->>'title',x->>'name',x->>'id')),'{}') INTO labels
 FROM (SELECT x FROM jsonb_each(before_doc) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id' UNION ALL SELECT x FROM jsonb_each(doc) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id') names
 WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(diff) d WHERE x->>'id'=ANY(string_to_array(d->>'path',' / ')));
 run:=jsonb_build_object('id',run_id,'labels',labels,'at',now(),'fileName',left(coalesce(source->>'fileName','CSV'),250),'format',source->>'format','changes',diff);
 INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT uid,run_id::text,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=uid;
 INSERT INTO public.pn2_import_archives(id,workspace_id,file_name,format,before_document,after_document,changes) VALUES(run_id,uid,run->>'fileName',run->>'format',jsonb_build_object('storageFormat','delta-v1','changes',diff),jsonb_build_object('storageFormat','delta-v1','run',run),diff);
 SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) changed_reports;
 prior_import:=current_setting('pn2.importing',true);prior_delta:=current_setting('pn2.delta_report_ids',true);
 PERFORM set_config('pn2.importing','yes',true);PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.importing',coalesce(prior_import,''),true);PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result||jsonb_build_object('importRun',run,'auditEntry',audit_entry);
END $patch$;

NOTIFY pgrst,'reload schema';
-- Compact the report array in one aggregate, avoiding repeated growth/copies in a PL/pgSQL loop.
CREATE OR REPLACE FUNCTION public.pn2_compact_document() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $compactset8$
DECLARE reports jsonb;report_ids jsonb;
BEGIN
 IF NEW.document ? 'importHistory' THEN
  INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload)
  SELECT NEW.workspace_id,x->>'id',pos,x FROM jsonb_array_elements(NEW.document->'importHistory') WITH ORDINALITY v(x,pos) WHERE nullif(x->>'id','') IS NOT NULL
  ON CONFLICT(workspace_id,id) DO UPDATE SET ordinal=excluded.ordinal,payload=excluded.payload WHERE row(pn2_import_runs.ordinal,pn2_import_runs.payload) IS DISTINCT FROM row(excluded.ordinal,excluded.payload);
 END IF;
 INSERT INTO public.pn2_report_snapshots(workspace_id,report_id,payload)
 SELECT NEW.workspace_id,r->>'id',CASE WHEN r ? 'snapshots' THEN jsonb_build_object('snapshots',r->'snapshots') ELSE '{}'::jsonb END || CASE WHEN r ? 'settingsSnapshot' THEN jsonb_build_object('settingsSnapshot',r->'settingsSnapshot') ELSE '{}'::jsonb END
 FROM jsonb_array_elements(NEW.document->'reports') r WHERE r ? 'snapshots' OR r ? 'settingsSnapshot'
 ON CONFLICT(workspace_id,report_id) DO UPDATE SET payload=excluded.payload WHERE pn2_report_snapshots.payload IS DISTINCT FROM excluded.payload;
 SELECT coalesce(jsonb_agg((r-'snapshots'-'settingsSnapshot')||jsonb_build_object('_storedSnapshot',true) ORDER BY ord),'[]'),coalesce(jsonb_object_agg(r->>'id',true),'{}') INTO reports,report_ids FROM jsonb_array_elements(NEW.document->'reports') WITH ORDINALITY v(r,ord);
 DELETE FROM public.pn2_report_snapshots s WHERE workspace_id=NEW.workspace_id AND NOT report_ids ? s.report_id;
 NEW.document:=(NEW.document-'importHistory')||jsonb_build_object('reports',reports);RETURN NEW;
END $compactset8$;
NOTIFY pgrst,'reload schema';

-- Source: 20261016070159_v9_activity_and_report_actions.sql
-- Append-only activity events use the existing cold history store and shared-workspace access model.
CREATE OR REPLACE FUNCTION public.pn2_record_activity(event jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='10s' AS $$
DECLARE workspace uuid:='00000000-0000-0000-0000-000000000001';eid text;run jsonb;
BEGIN
 IF jsonb_typeof(event)<>'object' OR nullif(event->>'id','') IS NULL OR nullif(event->>'action','') IS NULL OR octet_length(event::text)>2000000 THEN RAISE EXCEPTION 'รูปแบบประวัติไม่ถูกต้อง';END IF;
 eid:=event->>'id';IF length(eid)>200 THEN RAISE EXCEPTION 'รหัสประวัติยาวเกินกำหนด';END IF;
 IF jsonb_typeof(coalesce(event->'changes','[]'))<>'array' THEN RAISE EXCEPTION 'รายละเอียดประวัติต้องเป็นรายการ';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(workspace::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.pn2_workspaces WHERE workspace_id=workspace) THEN RAISE EXCEPTION 'ยังไม่มีพื้นที่ข้อมูล';END IF;
 run:=jsonb_build_object('id',eid,'at',now(),'occurredAt',event->>'at','fileName',left(event->>'action',300),'format','ACTIVITY','labels',coalesce(event->'labels','{}'),'details',coalesce(event->'details','{}'),'changes',CASE WHEN jsonb_array_length(coalesce(event->'changes','[]'))>0 THEN event->'changes' ELSE jsonb_build_array(jsonb_build_object('path','การดำเนินการ','kind','activity','before',null,'after',coalesce(event->'details','{}'))) END);
 INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT workspace,eid,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=workspace ON CONFLICT(workspace_id,id) DO NOTHING;
 SELECT payload INTO run FROM public.pn2_import_runs WHERE workspace_id=workspace AND id=eid;
 RETURN run||jsonb_build_object('recorded',true);
END $$;
REVOKE ALL ON FUNCTION public.pn2_record_activity(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_record_activity(jsonb) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Source: 20261016173905_plannet_registry_relations.sql
-- Additive Plannet projections. Existing registry, report IDs and snapshots remain authoritative.
CREATE UNIQUE INDEX IF NOT EXISTS pn2_registry_source_identity
 ON public.pn2_contract_registry(workspace_id,fiscal_year,funding_source,(nullif(btrim(payload->>'sourceId'),'')))
 WHERE nullif(btrim(payload->>'sourceId'),'') IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.pn2_registry_segments(
 workspace_id uuid NOT NULL,registry_id text NOT NULL,ordinal integer NOT NULL CHECK(ordinal>0),
 road_no text,control_section text,section_name text,km_start text,km_end text,direction text,note text,
 PRIMARY KEY(workspace_id,registry_id,ordinal),
 FOREIGN KEY(workspace_id,registry_id) REFERENCES public.pn2_contract_registry(workspace_id,id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS public.pn2_registry_personnel(
 workspace_id uuid NOT NULL,registry_id text NOT NULL,person_id text NOT NULL,
 role text NOT NULL CHECK(role IN('inspection','supervision')),ordinal integer NOT NULL CHECK(ordinal>0),
 PRIMARY KEY(workspace_id,registry_id,role,person_id),UNIQUE(workspace_id,registry_id,role,ordinal),
 FOREIGN KEY(workspace_id,registry_id) REFERENCES public.pn2_contract_registry(workspace_id,id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(workspace_id,person_id) REFERENCES public.pn2_supervisors(workspace_id,id) DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE public.pn2_registry_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pn2_registry_personnel ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_sync_registry_relations()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.payload->'segments' IS NOT DISTINCT FROM NEW.payload->'segments'
  AND OLD.payload->'committeeIds' IS NOT DISTINCT FROM NEW.payload->'committeeIds'
  AND OLD.payload->'supervisorIds' IS NOT DISTINCT FROM NEW.payload->'supervisorIds' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.payload->'segments','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'committeeIds','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'supervisorIds','[]'))<>'array' THEN RAISE EXCEPTION 'ช่วงทางและบุคลากรต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_registry_segments WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_segments SELECT NEW.workspace_id,NEW.id,ord::integer,x->>'routeNumber',x->>'controlSection',x->>'sectionName',x->>'kmStart',x->>'kmEnd',x->>'direction',x->>'routeNote' FROM jsonb_array_elements(coalesce(NEW.payload->'segments','[]')) WITH ORDINALITY a(x,ord);
 DELETE FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_personnel SELECT NEW.workspace_id,NEW.id,x#>>'{}','inspection',ord::integer FROM jsonb_array_elements(coalesce(NEW.payload->'committeeIds','[]')) WITH ORDINALITY a(x,ord);
 INSERT INTO public.pn2_registry_personnel SELECT NEW.workspace_id,NEW.id,x#>>'{}','supervision',ord::integer FROM jsonb_array_elements(coalesce(NEW.payload->'supervisorIds','[]')) WITH ORDINALITY a(x,ord);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_registry_relations() FROM PUBLIC;
DROP TRIGGER IF EXISTS pn2_registry_relations ON public.pn2_contract_registry;
CREATE TRIGGER pn2_registry_relations AFTER INSERT OR UPDATE OF payload ON public.pn2_contract_registry FOR EACH ROW EXECUTE FUNCTION public.pn2_sync_registry_relations();

-- One payment note formatter retains explicit free-text remarks across all exports.
CREATE OR REPLACE FUNCTION public.pn2_format_paid_note(note text,paid_date date)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $note$
 SELECT format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from paid_date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from paid_date)::integer],extract(year from paid_date)::integer+543)||CASE WHEN btrim(regexp_replace(coalesce(note,''),'^เบิกจ่ายแล้ว วันที่ [^·]*(·[[:space:]]*)?',''))<>'' THEN ' · '||btrim(regexp_replace(coalesce(note,''),'^เบิกจ่ายแล้ว วันที่ [^·]*(·[[:space:]]*)?','')) ELSE '' END;
$note$;
REVOKE ALL ON FUNCTION public.pn2_format_paid_note(text,date) FROM PUBLIC;
-- Extend the installed amendment function in place, preserving cold-data hydration and compact delta flags.
DO $v10$ DECLARE body text; BEGIN
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 IF position($old$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end$old$ IN body)=0 THEN RAISE EXCEPTION 'Missing amendment lifecycle anchor';END IF;
 body:=replace(body,$noteold$e:=jsonb_set(e,'{note}',to_jsonb(format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from (e->>'paymentDate')::date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from (e->>'paymentDate')::date)::integer],extract(year from (e->>'paymentDate')::date)::integer+543)));$noteold$,$notenew$e:=jsonb_set(e,'{note}',to_jsonb(public.pn2_format_paid_note(e->>'note',(e->>'paymentDate')::date)));$notenew$);
 body:=replace(body,$old$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end$old$,$new$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    || case when (change.value ? 'note' OR (change.value ? 'paymentDate' AND e->>'payment'='เบิกจ่ายแล้ว')) AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'reports') newer WHERE newer->>'end'>r->>'end' AND newer->'entries' ? change.key) THEN jsonb_build_object('note',coalesce(e->>'note','')) ELSE '{}'::jsonb END
    || case when change.value ? 'payment' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'reports') newer WHERE newer->>'end'>r->>'end' AND newer->'entries' ? change.key) THEN jsonb_build_object('payment',coalesce(e->>'payment',''),'sourceStatus',CASE WHEN e->>'payment'='เบิกจ่ายแล้ว' THEN 'แล้วเสร็จ' ELSE '' END) ELSE '{}'::jsonb END$new$);EXECUTE body;
END $v10$;
NOTIFY pgrst,'reload schema';

-- Source: 20261017091813_personnel_assignments_and_road_catalog.sql
-- Reusable road identity and per-contract personnel positions/duties. No authentication changes.
ALTER TABLE public.pn2_registry_personnel ADD COLUMN IF NOT EXISTS position_name text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_registry_personnel ADD COLUMN IF NOT EXISTS duty text NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS pn2_registry_personnel_person_idx ON public.pn2_registry_personnel(workspace_id,person_id);
CREATE TABLE IF NOT EXISTS public.pn2_road_sections(
 workspace_id uuid NOT NULL REFERENCES public.pn2_workspaces(workspace_id) ON DELETE CASCADE,
 id text NOT NULL,road_no text NOT NULL DEFAULT '',control_section text NOT NULL DEFAULT '',section_name text NOT NULL DEFAULT '',
 PRIMARY KEY(workspace_id,id),UNIQUE(workspace_id,road_no,control_section,section_name)
);
ALTER TABLE public.pn2_road_sections ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_sync_road_catalog() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.document#>'{settings,roadSections}' IS NOT DISTINCT FROM NEW.document#>'{settings,roadSections}' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.document#>'{settings,roadSections}','[]'))<>'array' THEN RAISE EXCEPTION 'ทะเบียนสายทางต้องเป็นรายการ';END IF;
 INSERT INTO public.pn2_road_sections(workspace_id,id,road_no,control_section,section_name)
 SELECT NEW.workspace_id,x->>'id',coalesce(x->>'routeNumber',''),coalesce(x->>'controlSection',''),coalesce(x->>'sectionName','') FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x
 ON CONFLICT(workspace_id,id) DO UPDATE SET road_no=excluded.road_no,control_section=excluded.control_section,section_name=excluded.section_name WHERE (pn2_road_sections.road_no,pn2_road_sections.control_section,pn2_road_sections.section_name) IS DISTINCT FROM (excluded.road_no,excluded.control_section,excluded.section_name);
 DELETE FROM public.pn2_road_sections t WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x WHERE x->>'id'=t.id);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_road_catalog() FROM PUBLIC;
CREATE TRIGGER pn2_road_catalog AFTER INSERT OR UPDATE OF document ON public.pn2_workspaces FOR EACH ROW EXECUTE FUNCTION public.pn2_sync_road_catalog();
CREATE OR REPLACE FUNCTION public.pn2_sync_registry_relations()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item jsonb;expected jsonb;group_key text;BEGIN
 IF TG_OP='UPDATE' AND OLD.payload->'segments' IS NOT DISTINCT FROM NEW.payload->'segments' AND OLD.payload->'committeeIds' IS NOT DISTINCT FROM NEW.payload->'committeeIds' AND OLD.payload->'supervisorIds' IS NOT DISTINCT FROM NEW.payload->'supervisorIds' AND OLD.payload->'personnelAssignments' IS NOT DISTINCT FROM NEW.payload->'personnelAssignments' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.payload->'segments','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'committeeIds','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'supervisorIds','[]'))<>'array' THEN RAISE EXCEPTION 'ช่วงทางและบุคลากรต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_registry_segments WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_segments SELECT NEW.workspace_id,NEW.id,ord::integer,x->>'routeNumber',x->>'controlSection',x->>'sectionName',x->>'kmStart',x->>'kmEnd',x->>'direction',x->>'routeNote' FROM jsonb_array_elements(coalesce(NEW.payload->'segments','[]')) WITH ORDINALITY a(x,ord);
 DELETE FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 IF NEW.payload ? 'personnelAssignments' THEN
  IF jsonb_typeof(NEW.payload->'personnelAssignments')<>'array' THEN RAISE EXCEPTION 'รูปแบบบุคลากรไม่ถูกต้อง';END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(NEW.payload->'personnelAssignments') LOOP
   IF item->>'group' NOT IN('inspection','supervision') OR nullif(item->>'personId','') IS NULL OR coalesce(item->>'ordinal','') !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'ประเภท คีย์ หรือลำดับบุคลากรไม่ถูกต้อง';END IF;
   IF (item->>'group'='inspection' AND item->>'duty' NOT IN('ประธาน','กรรมการ')) OR (item->>'group'='supervision' AND item->>'duty' NOT IN('ผู้ควบคุมงาน','ผู้ช่วยผู้ควบคุมงาน')) OR item->>'duty' IS NULL THEN RAISE EXCEPTION 'บทบาทบุคลากรไม่ถูกต้อง';END IF;
   INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,position_name,duty) VALUES(NEW.workspace_id,NEW.id,item->>'personId',item->>'group',(item->>'ordinal')::integer,coalesce(item->>'position',''),item->>'duty');
  END LOOP;
  FOREACH group_key IN ARRAY ARRAY['inspection','supervision'] LOOP
   SELECT coalesce(jsonb_agg(person_id ORDER BY ordinal),'[]') INTO expected FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id AND role=group_key;
   IF expected IS DISTINCT FROM coalesce(NEW.payload->(CASE WHEN group_key='inspection' THEN 'committeeIds' ELSE 'supervisorIds' END),'[]') THEN RAISE EXCEPTION 'รายการบุคลากรและคีย์อ้างอิงไม่ตรงกัน';END IF;
   IF jsonb_array_length(expected)>0 AND (SELECT count(*) FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id AND role=group_key AND duty=CASE WHEN group_key='inspection' THEN 'ประธาน' ELSE 'ผู้ควบคุมงาน' END)<>1 THEN RAISE EXCEPTION 'ต้องมีประธานหรือผู้ควบคุมงานหลักเพียงหนึ่งคนต่อกลุ่ม';END IF;
  END LOOP;
 ELSE
  INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,duty) SELECT NEW.workspace_id,NEW.id,x#>>'{}','inspection',ord::integer,CASE WHEN ord=1 THEN 'ประธาน' ELSE 'กรรมการ' END FROM jsonb_array_elements(coalesce(NEW.payload->'committeeIds','[]')) WITH ORDINALITY a(x,ord);
  INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,duty) SELECT NEW.workspace_id,NEW.id,x#>>'{}','supervision',ord::integer,CASE WHEN ord=1 THEN 'ผู้ควบคุมงาน' ELSE 'ผู้ช่วยผู้ควบคุมงาน' END FROM jsonb_array_elements(coalesce(NEW.payload->'supervisorIds','[]')) WITH ORDINALITY a(x,ord);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_registry_relations() FROM PUBLIC;
-- Set legacy duty values without changing source documents, identities or report snapshots.
UPDATE public.pn2_registry_personnel SET duty=CASE WHEN role='inspection' THEN CASE WHEN ordinal=1 THEN 'ประธาน' ELSE 'กรรมการ' END ELSE CASE WHEN ordinal=1 THEN 'ผู้ควบคุมงาน' ELSE 'ผู้ช่วยผู้ควบคุมงาน' END END WHERE duty='';
NOTIFY pgrst,'reload schema';

-- Source: 20261017231300_scoped_registry_reads_and_delta_validation.sql
-- Smaller ordinary reads; historical backup/import APIs remain complete.
DO $migration$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 IF position('''projects'',(SELECT' in body)=0 THEN
  body:=replace(body,'''reports'',report_rows,', $scope$'projects',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr AND coalesce(p->>'funding','DOH')=fund),'contractRegistry',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM jsonb_array_elements(coalesce(doc->'contractRegistry','[]')) p WHERE (p->>'year')::integer=yr AND coalesce(p->>'funding','DOH')=fund),'reports',report_rows,$scope$);
  EXECUTE body;
 END IF;
 -- Report validation still covers every explicitly updated/removed report, and
 -- JSON replacement continues through the full validation path. Global project
 -- validation, FK protection, revision lock and audited lifecycle remain intact.
 body:=pg_get_functiondef('public.pn2_patch_workspace(jsonb,bigint,text)'::regprocedure);
 body:=regexp_replace(body,'IF NOT EXISTS\(SELECT 1 FROM jsonb_object_keys\(coalesce\(changes->''collections'',''\{\}''\)\) key WHERE key<>''reports''\)\s+AND NOT EXISTS\(SELECT 1 FROM jsonb_object_keys\(coalesce\(changes->''values'',''\{\}''\)\) key WHERE key<>ALL\(ARRAY\[''settings'',''issues'',''masterSequences''\]\)\) THEN','IF true THEN');
 EXECUTE body;
 -- Keep the carried baseline after authorized old-report pruning.
 body:=pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure);
 IF position('reportBaselines' in body)=0 THEN
  body:=replace(body,'prev:=previous_entries->e.key;', 'prev:=coalesce(previous_entries->e.key,payload->''settings''->''reportBaselines''->(r->>''id'')->e.key);');
  EXECUTE body;
 END IF;
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 body:=replace(body,'prior:=coalesce(prior,0);','prior:=coalesce(prior,(doc->''settings''->''reportBaselines''->report_id->change.key->>''actual'')::numeric,0);');
 EXECUTE body;
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'diff:=public.pn2_import_diff(old_doc,payload);','diff:=public.pn2_import_diff(old_doc-''importHistory'',payload-''importHistory'');');
 EXECUTE body;
END $migration$;
NOTIFY pgrst,'reload schema';

-- Remove retired identities before updating canonical road names to avoid
-- transient uniqueness conflicts when two source names consolidate.
CREATE OR REPLACE FUNCTION public.pn2_sync_road_catalog() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.document#>'{settings,roadSections}' IS NOT DISTINCT FROM NEW.document#>'{settings,roadSections}' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.document#>'{settings,roadSections}','[]'))<>'array' THEN RAISE EXCEPTION 'ทะเบียนสายทางต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_road_sections t WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x WHERE x->>'id'=t.id);
 INSERT INTO public.pn2_road_sections(workspace_id,id,road_no,control_section,section_name)
 SELECT NEW.workspace_id,x->>'id',coalesce(x->>'routeNumber',''),coalesce(x->>'controlSection',''),coalesce(x->>'sectionName','') FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x
 ON CONFLICT(workspace_id,id) DO UPDATE SET road_no=excluded.road_no,control_section=excluded.control_section,section_name=excluded.section_name WHERE (pn2_road_sections.road_no,pn2_road_sections.control_section,pn2_road_sections.section_name) IS DISTINCT FROM (excluded.road_no,excluded.control_section,excluded.section_name);

 RETURN NEW;
END $$;

-- Cover active FK lookups identified by the Supabase performance advisor.
-- Legacy pn_* tables are unrelated to this shared workspace release.
CREATE INDEX IF NOT EXISTS pn2_registry_contractor_fk_idx ON public.pn2_contract_registry(workspace_id,contractor_id);
CREATE INDEX IF NOT EXISTS pn2_registry_type_fk_idx ON public.pn2_contract_registry(workspace_id,work_type_id);
CREATE INDEX IF NOT EXISTS pn2_registry_budget_fk_idx ON public.pn2_contract_registry(workspace_id,budget_account_id);
CREATE INDEX IF NOT EXISTS pn2_registry_workcode_fk_idx ON public.pn2_contract_registry(workspace_id,work_code_id);
CREATE INDEX IF NOT EXISTS pn2_registry_job_fk_idx ON public.pn2_contract_registry(workspace_id,work_name_id);
CREATE INDEX IF NOT EXISTS pn2_registry_supervisor_fk_idx ON public.pn2_contract_registry(workspace_id,supervisor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_contractor_fk_idx ON public.pn2_contracts(workspace_id,contractor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_funding_fk_idx ON public.pn2_contracts(workspace_id,funding_source);
CREATE INDEX IF NOT EXISTS pn2_contract_registry_fk_idx ON public.pn2_contracts(workspace_id,registry_id);
CREATE INDEX IF NOT EXISTS pn2_contract_supervisor_fk_idx ON public.pn2_contracts(workspace_id,supervisor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_workname_fk_idx ON public.pn2_contracts(workspace_id,work_name_id);
CREATE INDEX IF NOT EXISTS pn2_contract_worktype_fk_idx ON public.pn2_contracts(workspace_id,work_type_id);
CREATE INDEX IF NOT EXISTS pn2_contract_category_fk_idx ON public.pn2_contracts(workspace_id,category_id);
CREATE INDEX IF NOT EXISTS pn2_extensions_contract_fk_idx ON public.pn2_extensions(workspace_id,contract_id);
CREATE INDEX IF NOT EXISTS pn2_reports_funding_fk_idx ON public.pn2_reports(workspace_id,funding_source);
CREATE INDEX IF NOT EXISTS pn2_worknames_type_fk_idx ON public.pn2_work_names(workspace_id,type_id);

-- Source: 20261018054604_avoid_reprocessing_cold_history_in_json_restore.sql
-- Import audit history belongs to the destination, not the active replacement
-- payload. Existing archived history remains intact; every new change is audited.
DO $json_history$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'payload:=payload-''sourceArchive'';', 'payload:=payload-''sourceArchive''-''importHistory''-''importHistoryDeferred''-''importHistoryCached''-''loadedScope'';');
 body:=replace(body,'file_name,format_name,old_doc,payload,diff)', 'file_name,format_name,jsonb_build_object(''storageFormat'',''delta-v1'',''changes'',diff),jsonb_build_object(''storageFormat'',''delta-v1'',''run'',run),diff)');
 EXECUTE body;
END $json_history$;
NOTIFY pgrst,'reload schema';

-- Source: 20261018055038_compact_added_removed_audit_nodes.sql
-- Compact whole-node additions/removals while retaining exact before/after.
CREATE OR REPLACE FUNCTION public.pn2_import_diff(old_value jsonb,new_value jsonb,field_path text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb:='[]';k text;left_obj jsonb;right_obj jsonb;
BEGIN
 IF old_value IS NOT DISTINCT FROM new_value THEN RETURN result;END IF;
 -- A whole added/removed node already contains every old/new field. Recursing
 -- through thousands of absent snapshot leaves caused quadratic JSON appends.
 IF old_value IS NULL OR new_value IS NULL THEN RETURN jsonb_build_array(jsonb_build_object('path',field_path,'before',old_value,'after',new_value,'kind',CASE WHEN old_value IS NULL THEN 'added' ELSE 'removed' END));END IF;
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

NOTIFY pgrst,'reload schema';

-- Source: 20261018055453_append_json_audit_without_history_hydration.sql
-- Append one immutable run without hydrating/re-writing all previous history.
-- Supports both the original and capped-history JSON implementation.
DO $append_json_run$
DECLARE body text;start_at integer;end_at integer;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 start_at:=position('payload:=payload||jsonb_build_object(''importHistory'',' in body);
 IF start_at>0 THEN
  end_at:=start_at+position(';' in substring(body from start_at))-1;
  body:=overlay(body placing $new$INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT uid,run_id::text,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=uid;
 payload:=payload-'importHistory';$new$ from start_at for end_at-start_at+1);
 ELSIF position('coalesce(min(ordinal),0)-1,run' in body)=0 THEN RAISE EXCEPTION 'Unrecognized JSON audit implementation';END IF;
 body:=replace(body,'WHERE token IS NOT NULL AND token<>''''','WHERE token IS NOT NULL AND token<>'''' AND length(token)<=200');
 EXECUTE body;
END $append_json_run$;
NOTIFY pgrst,'reload schema';

-- Source: 20261018105756_task_scoped_personnel_and_writes.sql
-- v13: compatible personnel rename and bounded task writes. No business record is removed.
ALTER TABLE public.pn2_supervisors RENAME TO pn2_personnel;
ALTER TABLE public.pn2_personnel ADD COLUMN position_name text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_personnel ADD COLUMN person_roles jsonb NOT NULL DEFAULT '[]';
-- Preserve legacy relation name for read integrations. All internal writers move to the real table.
CREATE VIEW public.pn2_supervisors WITH (security_invoker=true) AS SELECT workspace_id,id,name,archived,code FROM public.pn2_personnel;
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT oid,pg_get_functiondef(oid) body FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind='f' AND prosrc LIKE '%pn2_supervisors%' LOOP
  EXECUTE replace(f.body,'pn2_supervisors','pn2_personnel');
 END LOOP;
END $migration$;
UPDATE public.pn2_personnel p SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'supervisors') x WHERE p.workspace_id=w.workspace_id AND p.id=x->>'id';
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT oid,conname FROM pg_constraint WHERE conrelid='public.pn2_contracts'::regclass AND contype='f' AND confrelid='public.pn2_fiscal_years'::regclass ORDER BY oid OFFSET 1 LOOP
  EXECUTE format('ALTER TABLE public.pn2_contracts DROP CONSTRAINT %I',f.conname);
 END LOOP;
END $migration$;

-- Hydrate only reports whose content is actually changing. Other snapshots remain cold.
CREATE FUNCTION public.pn2_hydrate_changed(doc jsonb, ids jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT jsonb_set(doc-'importHistory','{reports}',coalesce((SELECT jsonb_agg(CASE WHEN ids @> jsonb_build_array(r->>'id') THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE r END ORDER BY ord) FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id'),'[]'))
$$;
CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb, expected_revision bigint, action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;prior_delta text;delta_ids jsonb;result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select public.pn2_hydrate_changed(document,coalesce((SELECT jsonb_agg(x->>'id') FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x),'[]')),revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(CASE WHEN k='contractRegistry' AND upserts ? (x->>'id') THEN (SELECT coalesce(jsonb_object_agg(key,value),'{}') FROM jsonb_each(x) WHERE key=ANY(ARRAY['sourceSheet','sourceRow','sourceEnd']))||(upserts->(x->>'id')) ELSE coalesce(upserts->(x->>'id'),x) END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 prior_delta:=current_setting('pn2.delta_report_ids',true);
 IF true THEN
  SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' AS id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) ids;
  PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 END IF;
 PERFORM set_config('pn2.changed_collections',coalesce(changes->'collections','{}')::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.changed_collections','',true);
 PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result;
END $function$
;
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select CASE WHEN nullif(current_setting('pn2.delta_report_ids',true),'') IS NULL THEN public.pn2_hydrate_document(document,false) ELSE public.pn2_hydrate_changed(document,current_setting('pn2.delta_report_ids')::jsonb) END,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=coalesce(previous_entries->e.key,payload->'settings'->'reportBaselines'->(r->>'id')->e.key);
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_personnel(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_personnel existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_personnel is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'projects'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then UPDATE public.pn2_personnel n SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM jsonb_array_elements(payload->'supervisors') x WHERE n.workspace_id=uid AND n.id=x->>'id' AND row(n.position_name,n.person_roles) IS DISTINCT FROM row(coalesce(x->>'position',''),coalesce(x->'personRoles','[]'));end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;

-- Redundant text pairs are a read model of registry rows, not a second writable catalogue.
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT pg_get_functiondef(oid) body FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='pn2_delete_removed_projection' LOOP
  EXECUTE regexp_replace(regexp_replace(f.body,'IF previous_doc->''contractRegistry'' IS DISTINCT FROM input_doc->''contractRegistry'' THEN DELETE FROM public.pn2_registry_work_links[^;]+;END IF;','','gi'),'DELETE FROM public.pn2_registry_work_links[^;]+;','','gi');
 END LOOP;
END $migration$;
DROP TABLE public.pn2_registry_work_links;
CREATE VIEW public.pn2_registry_work_links WITH (security_invoker=true) AS
 SELECT DISTINCT ON(workspace_id,work_code,title) workspace_id,work_code,title,work_type_id
 FROM public.pn2_contract_registry WHERE nullif(work_code,'') IS NOT NULL
 ORDER BY workspace_id,work_code,title,(work_type_id IS NULL),id;
GRANT SELECT ON public.pn2_registry_work_links TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL::text, requested_year integer DEFAULT NULL::integer, requested_report text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '15s'
AS $function$
DECLARE doc jsonb;rev bigint;yr integer;fund text;chosen text;selected_start text;recent jsonb;report_rows jsonb;prior jsonb;latest jsonb;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 yr:=requested_year;IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max((p->>'year')::integer) INTO yr FROM jsonb_array_elements(doc->'projects') p;END IF;
 yr:=coalesce(yr,2569);fund:=requested_funding;
 IF fund IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'fundingSources') p WHERE p->>'id'=fund) THEN SELECT coalesce(p->>'funding','DOH') INTO fund FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr ORDER BY (coalesce(p->>'funding','DOH')='DOH') DESC LIMIT 1;END IF;fund:=coalesce(fund,'DOH');
 SELECT r->>'id',r->>'start' INTO chosen,selected_start FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY (r->>'id'=requested_report) DESC NULLS LAST,nullif(r->>'end','') DESC NULLS LAST,ord LIMIT 1;
 SELECT coalesce(jsonb_agg(id),'[]') INTO recent FROM (SELECT r->>'id' id FROM jsonb_array_elements(doc->'reports') r WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY nullif(r->>'end','') DESC NULLS LAST LIMIT 6) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO prior FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND r->>'end'<selected_start ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO latest FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND nullif(r->>'end','') IS NOT NULL ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_agg(CASE WHEN r->>'id'=chosen THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE
 (r-'entries'-'snapshots'-'settingsSnapshot'-'_storedSnapshot')||jsonb_build_object('entries',CASE WHEN recent @> jsonb_build_array(r->>'id') THEN r->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'_unloaded',true,'_entryCount',(SELECT count(*) FROM jsonb_object_keys(r->'entries')),'_missingPaymentDates',(SELECT coalesce(jsonb_agg(jsonb_build_array(e.key,'{}'::jsonb)),'[]') FROM jsonb_each(r->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND coalesce(e.value->>'paymentDate','')='')) END ORDER BY ord),'[]') INTO report_rows
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 RETURN (doc-'importHistory')||jsonb_build_object('projects',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contracts WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'contractRegistry',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen,'previousEntries',prior,'latestEntries',latest));
END $function$
;

-- Normal screens omit amendment bodies and source-sheet coordinates. Full backup/source imports keep them.
CREATE FUNCTION public.pn2_load_screen(requested_funding text DEFAULT NULL, requested_year integer DEFAULT NULL, requested_report text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $$
DECLARE d jsonb; BEGIN
 d:=public.pn2_load_scope(requested_funding,requested_year,requested_report);
 IF d IS NULL THEN RETURN NULL;END IF;
 d:=jsonb_set(d,'{settings}',(d->'settings')-'logo');
 RETURN jsonb_set(d-'amendments','{contractRegistry}',coalesce((SELECT jsonb_agg(r-ARRAY['sourceSheet','sourceRow','sourceEnd']) FROM jsonb_array_elements(d->'contractRegistry') r),'[]'))||jsonb_build_object('referenceDeferred',true);
END $$;
GRANT EXECUTE ON FUNCTION public.pn2_load_screen(text,integer,text) TO anon,authenticated;
CREATE FUNCTION public.pn2_load_branding(known_hash text DEFAULT '') RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $brand$
 SELECT CASE WHEN md5(coalesce(document#>>'{settings,logo}',''))=coalesce(known_hash,'') THEN jsonb_build_object('hash',known_hash,'notModified',true) ELSE jsonb_build_object('hash',md5(coalesce(document#>>'{settings,logo}','')),'logo',coalesce(document#>>'{settings,logo}','')) END FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid
$brand$;
GRANT EXECUTE ON FUNCTION public.pn2_load_branding(text) TO anon,authenticated;

-- A common weekly edit touches exactly one entry; other linked edits use the established patch validator.
CREATE OR REPLACE FUNCTION public.pn2_save_entry(report_id text, contract_id text, entry jsonb, changes jsonb, expected_revision bigint, action text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;old_entry jsonb;previous jsonb;idx integer;p jsonb;patch jsonb;event jsonb;new_rev bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 IF jsonb_typeof(entry)<>'object' OR octet_length(entry::text)>100000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลผลงานไม่ถูกต้อง';END IF;
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 SELECT value,(ord-1)::integer INTO r,idx FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(value,ord) WHERE value->>'id'=report_id;
 IF r IS NULL OR NOT r->'entries' ? contract_id THEN RAISE EXCEPTION 'ไม่พบสัญญาในรายงาน';END IF;
 IF coalesce((r->>'locked')::boolean,false) THEN RAISE EXCEPTION 'รายงานถูกปิดแล้ว ใช้แก้ไขรายงานย้อนหลัง';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) k WHERE k<>ALL(ARRAY['projects','contractRegistry'])) OR coalesce(changes->'values','{}')<>'{}' THEN RAISE EXCEPTION 'ชุดข้อมูลแก้ไขผลงานไม่ถูกต้อง';END IF;
 -- Lifecycle edits also update the linked registry/project and require that shared validation path.
 IF EXISTS(SELECT 1 FROM jsonb_each(coalesce(changes->'collections','{}')) c WHERE coalesce(c.value->'upsert','[]')<>'[]' OR coalesce(c.value->'remove','[]')<>'[]') THEN
  SELECT (public.pn2_load_report_detail(report_id))->'report' INTO r;
  r:=jsonb_set(r,ARRAY['entries',contract_id],entry);
  patch:=coalesce(changes,'{}')||jsonb_build_object('collections',coalesce(changes->'collections','{}')||jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(r),'remove','[]'::jsonb)));
  RETURN public.pn2_patch_workspace(patch,expected_revision,action);
 END IF;
 old_entry:=r->'entries'->contract_id;
 IF old_entry=entry THEN RETURN jsonb_build_object('revision',rev);END IF;
 IF NOT entry ?& ARRAY['plan','weekly','actual','payment','note'] OR entry->>'plan' IS NULL OR entry->>'weekly' IS NULL OR entry->>'actual' IS NULL OR (entry->>'plan')::numeric NOT BETWEEN 0 AND 100 OR (entry->>'weekly')::numeric NOT BETWEEN 0 AND 100 OR (entry->>'actual')::numeric NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';END IF;
 IF entry->>'payment' NOT IN ('รอส่งมอบงาน','รอเบิกจ่าย','เบิกจ่ายแล้ว') THEN RAISE EXCEPTION 'สถานะเบิกจ่ายไม่ถูกต้อง';END IF;
 IF nullif(entry->>'deliveryDate','')::date>nullif(entry->>'acceptanceDate','')::date OR (entry->>'payment'='เบิกจ่ายแล้ว' AND nullif(entry->>'acceptanceDate','')::date>nullif(entry->>'paymentDate','')::date) THEN RAISE EXCEPTION 'ลำดับวันที่ไม่ถูกต้อง';END IF;
 IF coalesce((r->>'imported')::boolean,false)=false THEN
  SELECT payload INTO p FROM public.pn2_contracts WHERE workspace_id=uid AND id=contract_id;
  IF p IS NULL OR coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') OR p->>'year'<>r->>'year' THEN RAISE EXCEPTION 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';END IF;
  SELECT e.payload INTO previous FROM (SELECT pr.end_date,jsonb_build_object('actual',pe.actual_percent,'payment',pe.payment_status,'paymentDate',coalesce(pe.payment_date::text,'')) payload FROM public.pn2_entries pe JOIN public.pn2_reports pr ON pr.workspace_id=pe.workspace_id AND pr.id=pe.report_id WHERE pe.workspace_id=uid AND pe.contract_id=pn2_save_entry.contract_id AND pr.end_date<(r->>'start')::date AND pr.fiscal_year=(r->>'year')::integer AND pr.funding_source=coalesce(r->>'funding','DOH') ORDER BY pr.end_date DESC LIMIT 1) e;
  previous:=coalesce(previous,doc->'settings'->'reportBaselines'->report_id->contract_id);
  IF abs((entry->>'actual')::numeric-coalesce((previous->>'actual')::numeric,0)-(entry->>'weekly')::numeric)>0.011 THEN RAISE EXCEPTION 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';END IF;
  IF entry->>'payment'='เบิกจ่ายแล้ว' AND nullif(entry->>'paymentDate','') IS NULL AND (coalesce(previous->>'payment','')<>'เบิกจ่ายแล้ว' OR nullif(previous->>'paymentDate','') IS NOT NULL) THEN RAISE EXCEPTION 'กรุณาบันทึกวันที่เบิกจ่าย';END IF;
 END IF;
 UPDATE public.pn2_entries t SET plan_percent=(entry->>'plan')::numeric,weekly_percent=(entry->>'weekly')::numeric,actual_percent=(entry->>'actual')::numeric,note=coalesce(entry->>'note',''),payment_status=entry->>'payment',confirmed=coalesce((entry->>'confirmed')::boolean,false),payment_date=nullif(entry->>'paymentDate','')::date,delivery_date=nullif(entry->>'deliveryDate','')::date,acceptance_date=nullif(entry->>'acceptanceDate','')::date WHERE t.workspace_id=uid AND t.report_id=pn2_save_entry.report_id AND t.contract_id=pn2_save_entry.contract_id;
 new_rev:=rev+1;event:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกผลงาน'),300));
 doc:=jsonb_set(doc,ARRAY['reports',idx::text,'entries',contract_id],entry);
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(event)||coalesce(doc->'audit','[]'));
 UPDATE public.pn2_workspaces SET document=jsonb_set(doc,'{revision}',to_jsonb(new_rev)),revision=new_rev,updated_at=now() WHERE workspace_id=uid;
 INSERT INTO public.pn2_audit(workspace_id,revision,action) VALUES(uid,new_rev,event->>'action');
 RETURN jsonb_build_object('revision',new_rev,'auditEntry',event);
END $$;

-- Source: 20261018130524_focused_history_and_latest_registry_year.sql
-- v14: latest populated registry year and paged cold audit. No business data deletion here.
CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL::text, requested_year integer DEFAULT NULL::integer, requested_report text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '15s'
AS $function$
DECLARE doc jsonb;rev bigint;yr integer;fund text;chosen text;selected_start text;recent jsonb;report_rows jsonb;prior jsonb;latest jsonb;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 yr:=requested_year;IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max(fiscal_year) INTO yr FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND payload->>'deletedAt' IS NULL AND (requested_funding IS NULL OR funding_source=requested_funding);IF yr IS NULL THEN SELECT max(fiscal_year) INTO yr FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND payload->>'deletedAt' IS NULL;END IF;END IF;
 yr:=coalesce(yr,2569);fund:=requested_funding;
 IF fund IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'fundingSources') p WHERE p->>'id'=fund) THEN SELECT coalesce(p->>'funding','DOH') INTO fund FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr ORDER BY (coalesce(p->>'funding','DOH')='DOH') DESC LIMIT 1;END IF;fund:=coalesce(fund,'DOH');
 SELECT r->>'id',r->>'start' INTO chosen,selected_start FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY (r->>'id'=requested_report) DESC NULLS LAST,nullif(r->>'end','') DESC NULLS LAST,ord LIMIT 1;
 SELECT coalesce(jsonb_agg(id),'[]') INTO recent FROM (SELECT r->>'id' id FROM jsonb_array_elements(doc->'reports') r WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY nullif(r->>'end','') DESC NULLS LAST LIMIT 6) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO prior FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND r->>'end'<selected_start ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO latest FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND nullif(r->>'end','') IS NOT NULL ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_agg(CASE WHEN r->>'id'=chosen THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE
 (r-'entries'-'snapshots'-'settingsSnapshot'-'_storedSnapshot')||jsonb_build_object('entries',CASE WHEN recent @> jsonb_build_array(r->>'id') THEN r->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'_unloaded',true,'_entryCount',(SELECT count(*) FROM jsonb_object_keys(r->'entries')),'_missingPaymentDates',(SELECT coalesce(jsonb_agg(jsonb_build_array(e.key,'{}'::jsonb)),'[]') FROM jsonb_each(r->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND coalesce(e.value->>'paymentDate','')='')) END ORDER BY ord),'[]') INTO report_rows
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 RETURN (doc-'importHistory')||jsonb_build_object('projects',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contracts WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'contractRegistry',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen,'previousEntries',prior,'latestEntries',latest));
END $function$
;

CREATE FUNCTION public.pn2_history_preview(value jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN octet_length(value::text)>2400 THEN jsonb_build_object('_historyPreview',true,'label',CASE jsonb_typeof(value) WHEN 'array' THEN 'รายการข้อมูล' WHEN 'object' THEN 'ชุดข้อมูล' ELSE 'ข้อความ' END,'text',left(value::text,1600)) ELSE value END
$$;
CREATE FUNCTION public.pn2_load_history_page(requested_page integer DEFAULT 1) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $$
 WITH runs AS MATERIALIZED(SELECT id,ordinal,payload FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),
 totals AS(SELECT coalesce(sum(jsonb_array_length(coalesce(payload->'changes','[]'))),0)::integer n FROM runs),
 paging AS(SELECT greatest(1,least(coalesce(requested_page,1),greatest(1,(n+24)/25))) p,n FROM totals),
 changes AS(SELECT r.id,r.ordinal,r.payload,c.value,c.ord FROM runs r CROSS JOIN LATERAL jsonb_array_elements(coalesce(r.payload->'changes','[]')) WITH ORDINALITY c(value,ord) ORDER BY r.ordinal,c.ord LIMIT 25 OFFSET (SELECT (p-1)*25 FROM paging))
 SELECT jsonb_build_object('revision',(SELECT revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'page',(SELECT p FROM paging),'total',(SELECT n FROM paging),'pages',greatest(1,((SELECT n FROM paging)+24)/25),'rows',coalesce((SELECT jsonb_agg(jsonb_build_object('run',payload-'changes'-'labels'||jsonb_build_object('labels',coalesce(payload->'labels','{}')),'changeIndex',ord-1,'change',value||jsonb_build_object('before',public.pn2_history_preview(value->'before'),'after',public.pn2_history_preview(value->'after')))) FROM changes),'[]'),'audit',coalesce((SELECT jsonb_agg(row_to_json(t)) FROM (SELECT action,created_at AS at FROM public.pn2_audit WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid ORDER BY id DESC LIMIT 20) t),'[]'))
$$;
CREATE FUNCTION public.pn2_load_history_change(requested_run text,requested_index integer) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('run',payload-'changes','change',payload->'changes'->requested_index) FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND id=requested_run
$$;
GRANT EXECUTE ON FUNCTION public.pn2_load_history_page(integer),public.pn2_load_history_change(text,integer) TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb, expected_revision bigint, action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;prior_delta text;delta_ids jsonb;result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select public.pn2_hydrate_changed(document,coalesce((SELECT jsonb_agg(x->>'id') FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x),'[]')),revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(CASE WHEN k='contractRegistry' AND upserts ? (x->>'id') THEN (SELECT coalesce(jsonb_object_agg(key,value),'{}') FROM jsonb_each(x) WHERE key=ANY(ARRAY['sourceSheet','sourceRow','sourceEnd']))||(upserts->(x->>'id')) ELSE coalesce(upserts->(x->>'id'),x) END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 -- A shared master rename must reach linked projections outside the currently loaded year.
 FOREACH k IN ARRAY ARRAY['contractors','supervisors'] LOOP
  SELECT coalesce(jsonb_object_agg(x->>'id',x->>'name'),'{}') INTO upserts FROM jsonb_array_elements(coalesce(changes->'collections'->k->'upsert','[]')) x;
  IF upserts<>'{}' THEN
   SELECT coalesce(jsonb_agg(CASE WHEN upserts ? (x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END) THEN x||jsonb_build_object(CASE WHEN k='contractors' THEN 'contractor' ELSE 'supervisor' END,upserts->>(x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END)) ELSE x END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(doc->'projects') WITH ORDINALITY v(x,ord);
   doc:=jsonb_set(doc,'{projects}',merged);
   SELECT coalesce(jsonb_agg(x),'[]') INTO removed FROM jsonb_array_elements(merged) x WHERE upserts ? (x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END) OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(changes->'collections'->'projects'->'upsert','[]')) q WHERE q->>'id'=x->>'id');
   changes:=jsonb_set(changes,'{collections,projects}',coalesce(changes->'collections'->'projects','{}')||jsonb_build_object('upsert',removed,'remove',coalesce(changes->'collections'->'projects'->'remove','[]')));
   IF k='contractors' THEN
    SELECT coalesce(jsonb_agg(CASE WHEN upserts ? (x->>'contractorId') THEN x||jsonb_build_object('contractorNeedsReview',coalesce((m->>'needsNameReview')::boolean,false)) ELSE x END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(doc->'contractRegistry') WITH ORDINALITY v(x,ord) LEFT JOIN LATERAL(SELECT value m FROM jsonb_array_elements(doc->'contractors') WHERE value->>'id'=x->>'contractorId') lookup ON true;
    doc:=jsonb_set(doc,'{contractRegistry}',merged);
    SELECT coalesce(jsonb_agg(x),'[]') INTO removed FROM jsonb_array_elements(merged) x WHERE upserts ? (x->>'contractorId') OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(changes->'collections'->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=x->>'id');
    changes:=jsonb_set(changes,'{collections,contractRegistry}',coalesce(changes->'collections'->'contractRegistry','{}')||jsonb_build_object('upsert',removed,'remove',coalesce(changes->'collections'->'contractRegistry'->'remove','[]')));
   END IF;
  END IF;
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 prior_delta:=current_setting('pn2.delta_report_ids',true);
 IF true THEN
  SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' AS id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) ids;
  PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 END IF;
 PERFORM set_config('pn2.changed_collections',coalesce(changes->'collections','{}')::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.changed_collections','',true);
 PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result;
END $function$
;


-- Source: 20261020090000_master_developer_rules_optimization.sql
-- ============================================================================
-- Migration: 20261020090000_master_developer_rules_optimization.sql
-- Repository: https://github.com/DOHPATTANI/pn-weekly.git
-- Purpose:
--   1. Add 6 composite indexes aligned with WHERE / JOIN / ORDER BY clauses
--   2. Eliminate all SELECT * in PL/pgSQL functions (pn2_save_workspace,
--      pn2_amend_report) and remove unused local variables
--   3. Preserve v14pn2_load_scope & pn2_patch_workspace behaviors
--   4. Reload PostgREST schema cache automatically on push
-- ============================================================================

begin;

create index if not exists pn2_reports_scope_end_idx
  on public.pn2_reports (workspace_id, funding_source, fiscal_year, end_date desc);

create index if not exists pn2_contracts_scope_idx
  on public.pn2_contracts (workspace_id, funding_source, fiscal_year)
  where not archived;

create index if not exists pn2_import_runs_ordinal_idx
  on public.pn2_import_runs (workspace_id, ordinal asc);

create index if not exists pn2_audit_workspace_rev_idx
  on public.pn2_audit (workspace_id, revision desc, created_at desc);

create index if not exists pn2_registry_segments_lookup_idx
  on public.pn2_registry_segments (workspace_id, registry_id, ordinal);

create index if not exists pn2_registry_personnel_lookup_idx
  on public.pn2_registry_personnel (workspace_id, registry_id, role, ordinal);

CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;existing jsonb;ext jsonb;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select CASE WHEN nullif(current_setting('pn2.delta_report_ids',true),'') IS NULL THEN public.pn2_hydrate_document(document,false) ELSE public.pn2_hydrate_changed(document,current_setting('pn2.delta_report_ids')::jsonb) END,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select key, value from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=coalesce(previous_entries->e.key,payload->'settings'->'reportBaselines'->(r->>'id')->e.key);
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_personnel(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_personnel existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_personnel is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'projects'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then UPDATE public.pn2_personnel n SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM jsonb_array_elements(payload->'supervisors') x WHERE n.workspace_id=uid AND n.id=x->>'id' AND row(n.position_name,n.person_roles) IS DISTINCT FROM row(coalesce(x->>'position',''),coalesce(x->'personRoles','[]'));end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;

CREATE OR REPLACE FUNCTION public.pn2_amend_report(report_id text, entries_patch jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;before_r jsonb;change record;e jsonb;old_e jsonb;prior numeric;changed_actual boolean;changed_weekly boolean;later jsonb;later_e jsonb;new_weekly numeric;affected jsonb:='[]';result jsonb;ts text:=now()::text;previous_flag text;has_changes boolean:=false;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into doc,rev from public.pn2_workspaces where workspace_id=uid for update;
 if doc is null then raise exception 'ไม่พบพื้นที่ข้อมูล';end if;
 if expected_revision<>rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 select value into r from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id;
 if r is null then raise exception 'ไม่พบรายงาน';end if;before_r:=r;
 if jsonb_typeof(entries_patch)<>'object' or entries_patch='{}' then raise exception 'ไม่มีข้อมูลเปลี่ยนแปลง';end if;
 for change in select key, value from jsonb_each(entries_patch) loop
  if not (r->'entries' ? change.key) then raise exception 'ไม่พบสัญญาในรายงาน';end if;
  if jsonb_typeof(change.value)<>'object' or exists(select 1 from jsonb_object_keys(change.value) k where k not in ('plan','weekly','actual','note','payment','paymentDate','deliveryDate','acceptanceDate')) then raise exception 'ช่องแก้ไขไม่ถูกต้อง';end if;
  old_e:=r->'entries'->change.key;e:=old_e||change.value;
  changed_actual:=(e->>'actual')::numeric<>(old_e->>'actual')::numeric;
  changed_weekly:=(e->>'weekly')::numeric<>(old_e->>'weekly')::numeric;
  if changed_actual or changed_weekly then
   if nullif(r->>'start','') is null or nullif(r->>'end','') is null then raise exception 'รายงานไม่มีช่วงวันที่ จึงยังแก้เปอร์เซ็นต์ย้อนหลังไม่ได้';end if;
   select coalesce((x->'entries'->change.key->>'actual')::numeric,0) into prior from jsonb_array_elements(doc->'reports') x where x->>'id'<>report_id and (x->>'end')::date<(r->>'start')::date and x->'entries' ? change.key order by (x->>'end')::date desc limit 1;
   prior:=coalesce(prior,(doc->'settings'->'reportBaselines'->report_id->change.key->>'actual')::numeric,0);
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
 if doc ? 'contractRegistry' then
  for change in select key, value from jsonb_each(entries_patch) loop
   e:=r->'entries'->change.key;
   doc:=jsonb_set(doc,'{contractRegistry}',coalesce((select jsonb_agg(case when x->>'projectId'=change.key then x
    || case when change.value ? 'deliveryDate' then jsonb_build_object('deliveryDate',coalesce(e->>'deliveryDate','')) else '{}'::jsonb end
    || case when change.value ? 'acceptanceDate' then jsonb_build_object('acceptanceDate',coalesce(e->>'acceptanceDate','')) else '{}'::jsonb end
    || case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    else x end) from jsonb_array_elements(doc->'contractRegistry') x),'[]'));
  end loop;
 end if;
 perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 perform set_config('pn2.delta_report_ids','',true);
 perform set_config('pn2.amending',coalesce(previous_flag,''),true);
 insert into public.pn2_report_amendments(workspace_id,report_id,before_report,after_report,affected_reports) values(uid,report_id,before_r,r,affected);
 select public.pn2_hydrate_document(document,false) into doc from public.pn2_workspaces where workspace_id=uid;
 return result||jsonb_build_object('document',doc);
end $function$
;

NOTIFY pgrst, 'reload schema';

commit;

-- Source: 20261020152951_compatible_writes_and_batch_projection.sql
-- Preserve current scoped writes and native personnel/route data; repair legacy view writes.
begin;
DO $repair$
DECLARE f record; body text;
BEGIN
 FOR f IN SELECT p.oid,pg_get_functiondef(p.oid) definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='pn2_delete_removed_projection'
 LOOP
  body:=regexp_replace(f.definition,'DELETE FROM public\.pn2_registry_work_links[^;]*;','PERFORM 1;','gi');
  EXECUTE body;
 END LOOP;
END $repair$;
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;existing jsonb;ext jsonb;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select CASE WHEN nullif(current_setting('pn2.delta_report_ids',true),'') IS NULL THEN public.pn2_hydrate_document(document,false) ELSE public.pn2_hydrate_changed(document,current_setting('pn2.delta_report_ids')::jsonb) END,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select key,value from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=coalesce(previous_entries->e.key,payload->'settings'->'reportBaselines'->(r->>'id')->e.key);
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 insert into public.pn2_fiscal_years(workspace_id,year,code) select uid,(x.value#>>'{}')::integer,payload->'yearCodes'->>(x.value#>>'{}') from jsonb_array_elements(payload->'years') x(value) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 insert into public.pn2_categories(workspace_id,id,name) select uid,x.value->>'id',x.value->>'name' from jsonb_array_elements(payload->'categories') x(value) on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_personnel(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_personnel existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_personnel is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 if exists(select 1 from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) where nullif(x.value->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types t where t.workspace_id=uid and t.id=x.value->>'typeId')) then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
 insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) select uid,x.value->>'id',x.value->>'name',nullif(x.value->>'typeId',''),coalesce((x.value->>'archived')::boolean,false),nullif(x.value->>'code','') from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;
 end if;
 insert into public.pn2_funding_sources(workspace_id,id,name) select uid,x.value->>'id',x.value->>'name' from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]')) x(value) on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 insert into public.pn2_work_name_codes(workspace_id,work_name_id,work_code_id) select uid,x.value->>'id',c.value#>>'{}' from jsonb_array_elements(coalesce(payload->'workNames','[]')) x(value) cross join lateral jsonb_array_elements(coalesce(x.value->'codeIds','[]')) c(value) on conflict do nothing;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'projects'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  insert into public.pn2_extensions(workspace_id,id,contract_id,days,approval_reference,approved,payload) select uid,x.value->>'id',p->>'id',(x.value->>'days')::integer,x.value->>'reference',(x.value->>'approved')::boolean,x.value from jsonb_array_elements(coalesce(p->'extensions','[]')) x(value) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then UPDATE public.pn2_personnel n SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM jsonb_array_elements(payload->'supervisors') x WHERE n.workspace_id=uid AND n.id=x->>'id' AND row(n.position_name,n.person_roles) IS DISTINCT FROM row(coalesce(x->>'position',''),coalesce(x->'personRoles','[]'));end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;
CREATE OR REPLACE FUNCTION public.pn2_amend_report(report_id text, entries_patch jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;before_r jsonb;change record;e jsonb;old_e jsonb;prior numeric;changed_actual boolean;changed_weekly boolean;later jsonb;later_e jsonb;new_weekly numeric;affected jsonb:='[]';result jsonb;ts text:=now()::text;previous_flag text;has_changes boolean:=false;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into doc,rev from public.pn2_workspaces where workspace_id=uid for update;
 doc:=public.pn2_hydrate_changed(doc,coalesce((select jsonb_agg(x->>'id') from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id or (exists(select 1 from jsonb_each(entries_patch) e where e.value ?| array['actual','weekly']) and exists(select 1 from jsonb_array_elements(doc->'reports') target where target->>'id'=report_id and coalesce(x->>'funding','DOH')=coalesce(target->>'funding','DOH') and x->>'year'=target->>'year' and x->>'end'>target->>'end'))),'[]'));
 if doc is null then raise exception 'ไม่พบพื้นที่ข้อมูล';end if;
 if expected_revision<>rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 select value into r from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id;
 if r is null then raise exception 'ไม่พบรายงาน';end if;before_r:=r;
 if jsonb_typeof(entries_patch)<>'object' or entries_patch='{}' then raise exception 'ไม่มีข้อมูลเปลี่ยนแปลง';end if;
 for change in select key, value from jsonb_each(entries_patch) loop
  if not (r->'entries' ? change.key) then raise exception 'ไม่พบสัญญาในรายงาน';end if;
  if jsonb_typeof(change.value)<>'object' or exists(select 1 from jsonb_object_keys(change.value) k where k not in ('plan','weekly','actual','note','payment','paymentDate','deliveryDate','acceptanceDate')) then raise exception 'ช่องแก้ไขไม่ถูกต้อง';end if;
  old_e:=r->'entries'->change.key;e:=old_e||change.value;
  changed_actual:=(e->>'actual')::numeric<>(old_e->>'actual')::numeric;
  changed_weekly:=(e->>'weekly')::numeric<>(old_e->>'weekly')::numeric;
  if changed_actual or changed_weekly then
   if nullif(r->>'start','') is null or nullif(r->>'end','') is null then raise exception 'รายงานไม่มีช่วงวันที่ จึงยังแก้เปอร์เซ็นต์ย้อนหลังไม่ได้';end if;
   select coalesce((x->'entries'->change.key->>'actual')::numeric,0) into prior from jsonb_array_elements(doc->'reports') x where x->>'id'<>report_id and (x->>'end')::date<(r->>'start')::date and x->'entries' ? change.key order by (x->>'end')::date desc limit 1;
   prior:=coalesce(prior,(doc->'settings'->'reportBaselines'->report_id->change.key->>'actual')::numeric,0);
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
 if doc ? 'contractRegistry' then
  for change in select key, value from jsonb_each(entries_patch) loop
   e:=r->'entries'->change.key;
   doc:=jsonb_set(doc,'{contractRegistry}',coalesce((select jsonb_agg(case when x->>'projectId'=change.key then x
    || case when change.value ? 'deliveryDate' then jsonb_build_object('deliveryDate',coalesce(e->>'deliveryDate','')) else '{}'::jsonb end
    || case when change.value ? 'acceptanceDate' then jsonb_build_object('acceptanceDate',coalesce(e->>'acceptanceDate','')) else '{}'::jsonb end
    || case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    else x end) from jsonb_array_elements(doc->'contractRegistry') x),'[]'));
  end loop;
 end if;
 perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 perform set_config('pn2.delta_report_ids','',true);
 perform set_config('pn2.amending',coalesce(previous_flag,''),true);
 insert into public.pn2_report_amendments(workspace_id,report_id,before_report,after_report,affected_reports) values(uid,report_id,before_r,r,affected);
 select public.pn2_hydrate_document(document,false) into doc from public.pn2_workspaces where workspace_id=uid;
 return result||jsonb_build_object('document',doc);
end $function$;
CREATE OR REPLACE FUNCTION public.pn2_release_compatibility() RETURNS jsonb
LANGUAGE sql STABLE SET search_path='' AS $check$
 SELECT jsonb_build_object('version','19.0.0','coldSnapshotsSafe',EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pn2_amend_report' AND position('pn2_hydrate_changed(doc' in p.prosrc)>0),'viewWritesSafe',NOT EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'));
$check$;
GRANT EXECUTE ON FUNCTION public.pn2_release_compatibility() TO anon,authenticated;
notify pgrst, 'reload schema';
commit;

-- Source: 20261020230140_add_p301_asset_register.sql
-- Additive, idempotent migration; preserve existing data.
begin;
alter table public.pn2_contractors add column if not exists address text not null default '';
alter table public.pn2_contractors add column if not exists phone text not null default '';
alter table public.pn2_work_codes add column if not exists recognition_type text not null default 'asset' check(recognition_type in ('asset','expense'));
alter table public.pn2_work_codes add column if not exists asset_category text not null default '';
alter table public.pn2_work_codes add column if not exists gl_account text not null default '';
alter table public.pn2_work_codes add column if not exists useful_life_years integer not null default 0 check(useful_life_years between 0 and 100);
alter table public.pn2_work_codes add column if not exists depreciation_rate numeric(7,2) not null default 0 check(depreciation_rate between 0 and 100);
alter table public.pn2_work_codes add column if not exists default_feature text not null default '-';
alter table public.pn2_work_codes add column if not exists variants jsonb not null default '[]'::jsonb check(jsonb_typeof(variants)='array');
create table if not exists public.pn2_p301_records(
 workspace_id uuid not null, registry_id text not null, overrides jsonb not null default '{}'::jsonb check(jsonb_typeof(overrides)='object'),
 updated_at timestamptz not null default now(),primary key(workspace_id,registry_id),
 foreign key(workspace_id,registry_id) references public.pn2_contract_registry(workspace_id,id) on delete cascade deferrable initially deferred
);
alter table public.pn2_p301_records enable row level security;
do $policy$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='pn2_p301_records' and policyname='pn2_p301_shared_read') then
  create policy pn2_p301_shared_read on public.pn2_p301_records for select to anon,authenticated using(true);
 end if;
end $policy$;
grant select on public.pn2_p301_records to anon,authenticated;
create index if not exists pn2_work_codes_asset_class_idx on public.pn2_work_codes(workspace_id,recognition_type,asset_category);
-- Generated from p301WorkRule; tests compare native rules with the frontend defaults.
create or replace function public.pn2_p301_work_rule(work_code text) returns jsonb language sql immutable set search_path=public as $rules$
 select coalesce($map${"11100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"11600":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"13000":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"14110":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"20510":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"อาคารหลัก","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}]},"20520":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"อาคารหลัก","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}]},"20530":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"ปรับปรุงอาคารหลัก","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":10,"rate":10},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":5,"rate":20},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}]},"20540":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"ปรับปรุงอาคารหลัก","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":10,"rate":10},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":5,"rate":20},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}]},"21100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21900":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22000":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"23100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"24100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"31200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31310":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31320":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31410":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31420":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31500":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31510":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"32100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"32300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]}}$map$::jsonb->work_code,'{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]}'::jsonb);
$rules$;
revoke execute on function public.pn2_p301_work_rule(text) from public,anon,authenticated;
create or replace function public.pn2_project_p301(input_doc jsonb,uid uuid) returns void language plpgsql set search_path=public as $projection$
begin
 insert into public.pn2_p301_records(workspace_id,registry_id,overrides)
 select uid,r.value->>'id',r.value->'p301' from jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]'::jsonb)) r(value)
 join public.pn2_contract_registry c on c.workspace_id=uid and c.id=r.value->>'id'
 where jsonb_typeof(r.value->'p301')='object' and r.value->'p301'<>'{}'::jsonb
 on conflict(workspace_id,registry_id) do update set overrides=excluded.overrides,updated_at=now()
 where pn2_p301_records.overrides is distinct from excluded.overrides;
 delete from public.pn2_p301_records p where p.workspace_id=uid and not exists(
 select 1 from jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]'::jsonb)) r(value)
 where r.value->>'id'=p.registry_id and jsonb_typeof(r.value->'p301')='object' and r.value->'p301'<>'{}'::jsonb);
 insert into public.pn2_work_codes(workspace_id,id,name,recognition_type,asset_category,gl_account,useful_life_years,depreciation_rate,default_feature,variants)
 select uid,rule.payload->>'id',rule.payload->>'name',coalesce(rule.payload->>'recognitionType','asset'),coalesce(rule.payload->>'assetCategory',''),coalesce(rule.payload->>'glAccount',''),coalesce(nullif(rule.payload->>'usefulLifeYears','')::integer,0),coalesce(nullif(rule.payload->>'depreciationRate','')::numeric,0),coalesce(rule.payload->>'defaultFeature','-'),coalesce(rule.payload->'variants','[]'::jsonb)
 from jsonb_array_elements(coalesce(input_doc->'workCodes','[]'::jsonb)) w(value)
 cross join lateral (select public.pn2_p301_work_rule(w.value->>'name')||w.value as payload) rule
 on conflict(workspace_id,id) do update set recognition_type=excluded.recognition_type,asset_category=excluded.asset_category,gl_account=excluded.gl_account,useful_life_years=excluded.useful_life_years,depreciation_rate=excluded.depreciation_rate,default_feature=excluded.default_feature,variants=excluded.variants
 where row(pn2_work_codes.recognition_type,pn2_work_codes.asset_category,pn2_work_codes.gl_account,pn2_work_codes.useful_life_years,pn2_work_codes.depreciation_rate,pn2_work_codes.default_feature,pn2_work_codes.variants)
 is distinct from row(excluded.recognition_type,excluded.asset_category,excluded.gl_account,excluded.useful_life_years,excluded.depreciation_rate,excluded.default_feature,excluded.variants);
end $projection$;
revoke execute on function public.pn2_project_p301(jsonb,uuid) from public,anon,authenticated;
create or replace function public.pn2_p301_projection_trigger() returns trigger language plpgsql set search_path=public as $trigger$
declare current_doc jsonb;
begin
 if old.document->'contractRegistry' is not distinct from new.document->'contractRegistry' and old.document->'workCodes' is not distinct from new.document->'workCodes' then return new;end if;
 select w.document into current_doc from public.pn2_workspaces w where w.workspace_id=new.workspace_id;
 perform public.pn2_project_p301(current_doc,new.workspace_id);
 return new;
end $trigger$;
revoke execute on function public.pn2_p301_projection_trigger() from public,anon,authenticated;
do $trigger_install$ begin
 if not exists(select 1 from pg_trigger where tgname='pn2_p301_project_at_commit' and tgrelid='public.pn2_workspaces'::regclass) then
  create constraint trigger pn2_p301_project_at_commit after update on public.pn2_workspaces deferrable initially deferred for each row execute function public.pn2_p301_projection_trigger();
 end if;
end $trigger_install$;
select public.pn2_project_p301(w.document,w.workspace_id) from public.pn2_workspaces w;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','20.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';

-- Source: 20261020232734_p301_projection_in_save_transaction.sql
-- Additive, idempotent migration; preserve existing data.
begin;
-- Projection must run before the existing SECURITY DEFINER save returns.
-- A deferred invoker trigger fires as anon after that boundary on PostgreSQL.
-- Keep helpers private; do not grant public projection writes or add new elevated RPCs.
drop trigger if exists pn2_p301_project_at_commit on public.pn2_workspaces;
drop function if exists public.pn2_p301_projection_trigger();
do $install$ declare definition text;anchor text:='return jsonb_build_object(''revision'',new_rev);'; begin
 select pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure) into definition;
 if position('perform public.pn2_project_p301(payload,uid)' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Unknown save contract: cannot safely attach P301 projection';end if;
  execute replace(definition,anchor,'if old_doc->''contractRegistry'' is distinct from payload->''contractRegistry'' or old_doc->''workCodes'' is distinct from payload->''workCodes'' then perform public.pn2_project_p301(payload,uid);end if; '||anchor);
 end if;
end $install$;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','20.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0 and not exists(select 1 from pg_trigger where tgname='pn2_p301_project_at_commit' and tgrelid='public.pn2_workspaces'::regclass));
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';

-- Source: 20261021005031_asset_route_history_and_report_layouts.sql
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

-- Source: 20261021041807_integrate_sheet_depreciation_and_form_studios.sql
-- v22 authoritative sheet rules; business data is seeded through the audited import owner.
begin;
create or replace function public.pn2_p301_work_rule(work_code text) returns jsonb language sql immutable set search_path=public as $rules$
 select coalesce($map${"11100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[2,3]},"11200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"11400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":10,"rate":10}],"sourceRows":[4]},"11600":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[5,6]},"12100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[7,8]},"12200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"12400":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"13000":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}],"sourceRows":[9,10]},"14110":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":15,"rate":6.67}]},"20500":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"20510":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205010101","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"-","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}],"sourceRows":[12,13]},"20520":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205020101","usefulLifeYears":40,"depreciationRate":2.5,"defaultFeature":"-","variants":[{"feature":"อาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":40,"rate":2.5},{"feature":"สิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":15,"rate":6.67}],"sourceRows":[15,16]},"20530":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205010101","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":20,"rate":5},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":8,"rate":12.5},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}],"sourceRows":[17,18,19]},"20540":{"recognitionType":"asset","assetCategory":"สิ่งก่อสร้าง","glAccount":"1205020101","usefulLifeYears":20,"depreciationRate":5,"defaultFeature":"-","variants":[{"feature":"ปรับปรุงอาคารหลัก","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":20,"rate":5},{"feature":"ปรับปรุงสิ่งก่อสร้างประกอบ","assetCategory":"สิ่งก่อสร้าง","usefulLifeYears":8,"rate":12.5},{"feature":"ซ่อมแซม (รับรู้เป็นค่าใช้จ่าย)","recognitionType":"expense","usefulLifeYears":0,"rate":0}],"sourceRows":[20,21,22]},"21000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[24]},"21200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[25]},"21300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[26]},"21400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[27]},"21500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[28]},"21600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[29]},"21700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"21900":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22000":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"22100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[31]},"22150":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[32]},"22200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[33]},"22250":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[34]},"22300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[35]},"22350":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[36]},"22400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[37]},"22500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[38]},"22600":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[39]},"23000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"23100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[41]},"23200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[42]},"23300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[43]},"23400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[44]},"24000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"24100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[46]},"24200":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[47]},"25000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"25100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[49]},"25200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[50]},"25300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[51]},"25400":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[52]},"25500":{"recognitionType":"asset","assetCategory":"สะพาน","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สะพาน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[53]},"25600":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[54]},"25700":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[55]},"25800":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[56]},"25900":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[57]},"26000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"26100":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[59]},"26200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[60]},"26300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[61]},"26400":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[62]},"26500":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[63]},"27000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"27100":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[65]},"27200":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[66]},"28000":{"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]},"28100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"ถนน","usefulLifeYears":3,"rate":33.33}],"sourceRows":[68]},"28200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":15,"rate":6.67}],"sourceRows":[69]},"28300":{"recognitionType":"expense","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[],"sourceRows":[70]},"29000":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":3,"depreciationRate":33.33,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33}],"sourceRows":[72]},"31200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31310":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31320":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":8,"depreciationRate":12.5,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":8,"rate":12.5,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":3,"rate":33.33,"label":"ปรับปรุง/ซ่อมแซม"}]},"31400":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[73]},"31410":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[74]},"31420":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[75]},"31500":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[76]},"31510":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10,"label":"ติดตั้งใหม่"},{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20,"label":"ปรับปรุง/ซ่อมแซม"}]},"31700":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":15,"depreciationRate":6.67,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":15,"rate":6.67}],"sourceRows":[77]},"31800":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[78]},"32000":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[79]},"32100":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"32300":{"recognitionType":"asset","assetCategory":"ถนน","glAccount":"1208010101","usefulLifeYears":7,"depreciationRate":14.29,"defaultFeature":"ลาดยาง","variants":[{"feature":"ลาดยาง","assetCategory":"ถนน","usefulLifeYears":7,"rate":14.29},{"feature":"คอนกรีต","assetCategory":"ถนน","usefulLifeYears":20,"rate":5}]},"33100":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[80]},"33200":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[81]},"33300":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[82]},"33400":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[83]},"33700":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":10,"depreciationRate":10,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":10,"rate":10}],"sourceRows":[84]},"33800":{"recognitionType":"asset","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","glAccount":"1208050101","usefulLifeYears":5,"depreciationRate":20,"defaultFeature":"-","variants":[{"feature":"-","assetCategory":"สินทรัพย์โครงสร้างพื้นฐานอื่น","usefulLifeYears":5,"rate":20}],"sourceRows":[85]}}$map$::jsonb->btrim(work_code),$fallback${"recognitionType":"asset","assetCategory":"","glAccount":"","usefulLifeYears":0,"depreciationRate":0,"defaultFeature":"-","variants":[]}$fallback$::jsonb);
$rules$;
revoke execute on function public.pn2_p301_work_rule(text) from public,anon,authenticated;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','22.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null and position('perform public.pn2_project_asset_routes(input_doc,uid)' in pg_get_functiondef('public.pn2_project_p301(jsonb,uuid)'::regprocedure))>0,'depreciationSourceReady',position('"20530"' in pg_get_functiondef('public.pn2_p301_work_rule(text)'::regprocedure))>0 and position('"sourceRows"' in pg_get_functiondef('public.pn2_p301_work_rule(text)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';

-- Source: 20261021084125_work_catalog_and_p301_day_basis.sql
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

-- Source: 20261022133000_v24_1_ux_and_performance_upgrade.sql
-- Migration: 20261022133000_v24_1_ux_and_performance_upgrade.sql
-- Created at: 2026-10-22T13:30:00+07:00 (Asia/Bangkok)
-- Master Developer Rules & PLANNET DOH v24.1:
-- 1. Create Composite Indexes for Scope filtering on reports/contracts
-- 2. Optimize RPC for On-Demand Report Detail & Idempotent

begin;

create index if not exists pn2_reports_scope_end_idx
  on public.pn2_reports (workspace_id, funding_source, fiscal_year, end_date desc);

create index if not exists pn2_contracts_scope_idx
  on public.pn2_contracts (workspace_id, funding_source, fiscal_year, archived);

create index if not exists pn2_entries_report_contract_idx
  on public.pn2_entries (workspace_id, report_id, contract_id);

create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
  select jsonb_build_object('version','23.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;

notify pgrst, 'reload schema';

commit;

-- Source: 20261024101337_fluid_ui_and_rpc_optimization.sql
-- v26 audit correction: paged search uses actual change rows, never downloads cold history into the page.
-- Read-only surface follows the existing shared-workspace access contract. No business data rewrite.
begin;
CREATE OR REPLACE FUNCTION public.pn2_search_history(requested_page integer DEFAULT 1,requested_query text DEFAULT '',requested_kind text DEFAULT 'all') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $history$
BEGIN
 RETURN (WITH matching AS MATERIALIZED(
  SELECT r.id,r.ordinal,r.payload,c.value,c.ord
  FROM public.pn2_import_runs r
  CROSS JOIN LATERAL jsonb_array_elements(coalesce(r.payload->'changes','[]'::jsonb)) WITH ORDINALITY c(value,ord)
  WHERE r.workspace_id='00000000-0000-0000-0000-000000000001'::uuid
   AND (coalesce(requested_kind,'all')='all' OR c.value->>'kind'=CASE requested_kind WHEN 'new' THEN 'added' WHEN 'updated' THEN 'updated' WHEN 'removed' THEN 'removed' ELSE '' END)
   AND (coalesce(btrim(requested_query),'')='' OR strpos(lower(concat_ws(' ',r.payload->>'fileName',r.payload->>'format',r.payload->>'source',c.value->>'path')),lower(btrim(requested_query)))>0)
 ), totals AS(SELECT count(*)::integer n FROM matching),
 paging AS(SELECT greatest(1,least(coalesce(requested_page,1),greatest(1,(n+24)/25))) p,n FROM totals),
 page_rows AS(SELECT id,ordinal,payload,value,ord FROM matching ORDER BY ordinal,ord LIMIT 25 OFFSET (SELECT (p-1)*25 FROM paging))
 SELECT jsonb_build_object('revision',(SELECT revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'page',(SELECT p FROM paging),'total',(SELECT n FROM paging),'pages',greatest(1,((SELECT n FROM paging)+24)/25),
 'rows',coalesce((SELECT jsonb_agg(jsonb_build_object('run',payload-'changes','changeIndex',ord-1,'change',value||jsonb_build_object('before',public.pn2_history_preview(value->'before'),'after',public.pn2_history_preview(value->'after'))) ORDER BY ordinal,ord) FROM page_rows),'[]'::jsonb),
 'audit',coalesce((SELECT jsonb_agg(row_to_json(t)) FROM (SELECT action,created_at AS at FROM public.pn2_audit WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid ORDER BY id DESC LIMIT 20) t),'[]'::jsonb)));
END;
$history$;
REVOKE ALL ON FUNCTION public.pn2_search_history(integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_search_history(integer,text,text) TO anon,authenticated;
-- This index duplicates the primary key exactly. Keep the primary key and reverse lookup index.
DROP INDEX IF EXISTS public.pn2_entries_report_contract_idx;
-- Existing readiness flags stay backward compatible; the new client requires paged audit search too.
CREATE OR REPLACE FUNCTION public.pn2_release_compatibility() RETURNS jsonb LANGUAGE sql STABLE SET search_path=public AS $check$
 SELECT jsonb_build_object('version','23.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'auditSearchReady',to_regprocedure('public.pn2_search_history(integer,text,text)') is not null);
$check$;
commit;
notify pgrst, 'reload schema';
