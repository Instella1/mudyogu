-- 코드랩: 예전에 탈주한 기록 소급 처리 (Supabase → SQL Editor 에서 실행. 여러 번 실행해도 같은 판은 한 번만)
-- 2026-11-06 사용자 제보: '통잼민' 이 2번 참여해 2번 탈주했는데 랭킹에 0판으로 나옴.
-- 원인: 탈주(앱 닫기·연결 끊김)하면 본인 결과가 저장되지 않았음 → 판수·레이팅이 그대로.
-- 같은 판을 끝까지 한 다른 사람들의 기록(detail)에는 "기권(left)" 으로 남아 있으므로, 그걸로 찾아서
-- 그 사람 이름으로 그 판 결과(꼴등)를 넣고, 탈주 규칙대로 레이팅을 내린다: −max(10, K × E)
--   K = 20 + 5 × 인원,  E = 1 / (1 + 10^((상대들 지금 레이팅 평균 − 내 레이팅) / 400))
-- 판수 +1 (1등 횟수는 그대로).

-- ⚠️ 실행 전에 꼭 ① 목록만 먼저 돌려서, 정말 끝까지 안 돌아온 사람인지 사용자에게 확인받을 것.
--    (다른 사람 기록의 left 는 '30초 넘게 끊겼다' 는 뜻일 뿐, 그 뒤에 돌아왔는지는 모른다 — 2026-11-06 이전 버전 게임)
-- ① 먼저 보기만: 어떤 판이 처리될지 (이 select 만 실행해 봐도 됨)
with q as (
  select distinct on (p.user_id, m.match_id)
         p.user_id, p.nickname, m.match_id, m.players, m.played_at, m.detail,
         coalesce((d->>'points')::int, 0) as points, coalesce((d->>'cards')::int, 0) as cards
    from public.codelab_matches m
    cross join lateral jsonb_array_elements(m.detail) d
    join public.codelab_profiles p on lower(p.nickname) = lower(d->>'nick')
   where coalesce((d->>'left')::boolean, false)
     and not exists (select 1 from public.codelab_matches x where x.user_id = p.user_id and x.match_id = m.match_id)
   order by p.user_id, m.match_id, m.played_at
)
select nickname as "탈주한 사람", match_id as "판", players as "인원", played_at as "날짜" from q order by nickname, played_at;

-- ② 실제 처리
do $$
declare
  r record;
  avg_r numeric;
  k numeric;
  e numeric;
  pen int;
begin
  for r in
    select distinct on (p.user_id, m.match_id)
           p.user_id, p.nickname, p.rating, m.match_id, m.players, m.played_at, m.detail,
           coalesce((d->>'points')::int, 0) as points, coalesce((d->>'cards')::int, 0) as cards
      from public.codelab_matches m
      cross join lateral jsonb_array_elements(m.detail) d
      join public.codelab_profiles p on lower(p.nickname) = lower(d->>'nick')
     where coalesce((d->>'left')::boolean, false)
       and not exists (select 1 from public.codelab_matches x where x.user_id = p.user_id and x.match_id = m.match_id)
     order by p.user_id, m.match_id, m.played_at
  loop
    -- 지금 레이팅 다시 읽기 (같은 사람이 여러 판이면 차례로 내려감)
    select rating into r.rating from public.codelab_profiles where user_id = r.user_id;
    select avg(pp.rating) into avg_r
      from jsonb_array_elements(r.detail) d2
      join public.codelab_profiles pp on lower(pp.nickname) = lower(d2->>'nick')
     where pp.user_id <> r.user_id;
    avg_r := coalesce(avg_r, r.rating);
    k := 20 + 5 * r.players;
    e := 1 / (1 + power(10::numeric, (avg_r - r.rating) / 400));
    pen := greatest(10, round(k * e)::int);

    insert into public.codelab_matches
      (user_id, match_id, played_at, players, rank, points, cards, rating_before, rating_after, detail)
    values
      (r.user_id, r.match_id, r.played_at, r.players, r.players, least(400, r.points), least(100, r.cards),
       r.rating, greatest(0, r.rating - pen), r.detail)
    on conflict (user_id, match_id) do nothing;

    if found then
      update public.codelab_profiles
         set rating = greatest(0, rating - pen), games = games + 1, updated_at = now()
       where user_id = r.user_id;
      if to_regclass('public.codelab_pending') is not null then
        execute 'delete from public.codelab_pending where user_id = $1 and match_id = $2' using r.user_id, r.match_id;
      end if;
      raise notice '% · % → −%', r.nickname, r.match_id, pen;
    end if;
  end loop;
end $$;

-- ③ 결과 확인
-- select nickname, rating, games, wins from public.codelab_profiles where nickname = '통잼민';
