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

select * from pathman_partition_list order by range_min, range_max;


explain (costs off) select * from parts.pt;
explain (costs off) select * from only parts.pt;
explain (costs off) select * from parts.pt where val = 1;



drop schema parts cascade;
drop extension pg_particulous;
