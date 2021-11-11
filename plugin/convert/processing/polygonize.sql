insert into {dtable}({cols})
with t1 as (
select {attr}, st_union({geom}) as geometria
from {stable}
where st_isvalid({geom})
group by {attr}
)
select {t1attr}, (st_dump(st_polygonize(t1.geometria))).geom as {geom} from t1
group by {t1attr};