-- Franchise Horizon: align the public Core Team cards with Admin > Leadership & Team.
-- Run once in Supabase SQL Editor. This keeps the existing records and updates their display order.

update public.site_content
set
  status = 'published',
  sort_order = case lower(trim(title))
    when 'amit agarwal' then 1
    when 'raj mishra' then 2
    when 'muthukumaran mp' then 3
    when 'niranjan nikalje' then 4
    else sort_order
  end,
  data = jsonb_set(
    jsonb_set(coalesce(data, '{}'::jsonb), '{designation}',
      to_jsonb(case lower(trim(title))
        when 'amit agarwal' then 'Founder, Regional Director – East'
        when 'raj mishra' then 'Regional Director – North'
        when 'muthukumaran mp' then 'Regional Director – South'
        when 'niranjan nikalje' then 'Regional Director – West'
        else coalesce(data->>'designation','')
      end), true),
    '{sort_order}',
    to_jsonb(case lower(trim(title))
      when 'amit agarwal' then 1
      when 'raj mishra' then 2
      when 'muthukumaran mp' then 3
      when 'niranjan nikalje' then 4
      else coalesce((data->>'sort_order')::integer, sort_order, 0)
    end), true
  ),
  updated_at = now()
where section = 'team'
  and lower(trim(title)) in (
    'amit agarwal',
    'raj mishra',
    'muthukumaran mp',
    'niranjan nikalje'
  );

-- Verify that the four Core Team records exist and are published.
select title, data->>'designation' as designation, sort_order, status
from public.site_content
where section = 'team'
  and lower(trim(title)) in (
    'amit agarwal',
    'raj mishra',
    'muthukumaran mp',
    'niranjan nikalje'
  )
order by sort_order asc;
