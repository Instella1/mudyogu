-- 타워 크래시 전체 랭킹 (Supabase → SQL Editor 에서 한 번 실행)
-- 2026-10-25 사용자 프로젝트에 적용함 (지금 시즌 2). 다시 만들 때 참고용.
create table public.tower_ranking (
  id          uuid primary key,
  secret_hash text not null,
  nickname    text not null check (char_length(nickname) between 1 and 12),
  best        int  not null default 0 check (best between 0 and 100000),
  total       bigint not null default 0 check (total between 0 and 100000000),
  skin        text not null default 'worker',
  updated_at  timestamptz not null default now()
);
create index tower_ranking_best_idx  on public.tower_ranking (best desc);
create index tower_ranking_total_idx on public.tower_ranking (total desc);

-- 누구나 '보기'만 가능 (직접 쓰기/지우기 금지)
alter table public.tower_ranking enable row level security;
create policy "랭킹 보기" on public.tower_ranking for select using (true);

-- 기록 올리기는 이 함수로만: 내 비밀값이 맞아야 내 줄을 고칠 수 있고, 기록은 큰 쪽만 남음.
-- p_season 이 지금 시즌(아래 숫자)과 같아야 받음 → 옛 버전 게임이 옛 기록을 다시 올리지 못함
create or replace function public.tower_submit(
  p_id uuid, p_secret text, p_nickname text, p_best int, p_total bigint, p_skin text, p_season int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  h text := encode(sha256(convert_to(p_secret, 'UTF8')), 'hex');
begin
  if p_season is distinct from 2 then raise exception 'old season'; end if;   -- ← 지금 시즌
  if char_length(coalesce(p_secret, '')) < 16 then raise exception 'bad secret'; end if;
  if p_best < 0 or p_best > 100000 or p_total < 0 or p_total > 100000000 then raise exception 'bad score'; end if;
  if char_length(trim(p_nickname)) not between 1 and 12 then raise exception 'bad name'; end if;

  insert into tower_ranking (id, secret_hash, nickname, best, total, skin)
  values (p_id, h, trim(p_nickname), p_best, p_total, left(coalesce(p_skin, 'worker'), 20))
  on conflict (id) do update set
    nickname   = excluded.nickname,
    best       = greatest(tower_ranking.best, excluded.best),
    total      = greatest(tower_ranking.total, excluded.total),
    skin       = excluded.skin,
    updated_at = now()
  where tower_ranking.secret_hash = h;
end $$;

revoke all on function public.tower_submit(uuid, text, text, int, bigint, text, int) from public;
grant execute on function public.tower_submit(uuid, text, text, int, bigint, text, int) to anon;

-- ─────────────────────────────────────────────────────────────
-- 랭킹 초기화(새 시즌) 하는 법
--   1) 게임 index.html 의 RANK_SEASON 숫자를 +1 하고 배포
--   2) 위 함수의 'is distinct from 2' 숫자도 같게 바꿔 이 블록을 실행 + 아래 한 줄 실행
--        delete from public.tower_ranking;
--   (시즌 1 → 2 : 2026-10-25, 테스트 기록 지움)
