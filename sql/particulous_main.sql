create extension pg_particulous cascade;
create schema parts;



/*
 * Migrate from PG 10 partitioning to pg_pathman.
 */

create table parts.pt (val int not null) partition by range (val);

create table parts.pt_0 partition of parts.pt for values from (minvalue) to (1);
create table parts.pt_1 partition of parts.pt for values from (1)        to (11);
create table parts.pt_2 partition of parts.pt for values from (11)       to (21);
create table parts.pt_3 partition of parts.pt for values from (21)       to (31);
create table parts.pt_4 partition of parts.pt for values from (31)       to (maxvalue);

select migrate_to_pathman('parts.pt');


/* test part bounds etc */
select * from pathman_partition_list order by range_min, range_max;


/* test SELECT */
select count(*) from parts.pt;
explain (costs off) select * from parts.pt;
explain (costs off) select * from only parts.pt;
explain (costs off) select * from parts.pt where val = 1;


/* test INSERT */
explain (costs off) insert into parts.pt values (1);
insert into parts.pt values (0), (10), (100) returning *, tableoid::regclass;


/* test UPDATE */
begin;
explain (costs off) delete from parts.pt where val = 0;
delete from parts.pt where val = 0 returning *, tableoid::regclass;
rollback;


/* test DELETE */
begin;
explain (costs off) update parts.pt set val = 9 where val = 10;
update parts.pt set val = 9 where val = 10 returning *, tableoid::regclass;
rollback;


/* test TRUNCATE */
begin;
truncate parts.pt;
select count(*) from parts.pt;
rollback;



drop schema parts cascade;
drop extension pg_particulous;
