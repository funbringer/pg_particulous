CREATE FUNCTION build_vanilla_part_condition(
	relation	REGCLASS)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'build_vanilla_part_condition'
LANGUAGE C STRICT;


CREATE FUNCTION build_vanilla_part_key(
	relation	REGCLASS)
RETURNS TEXT AS
$$
DECLARE
	raw_key		text;

BEGIN
	raw_key = pg_get_partkeydef(relation);

	/* Replace some keywords */
	raw_key = replace(raw_key, 'PARTITION BY', '');
	raw_key = replace(raw_key, 'RANGE', '');
	raw_key = replace(raw_key, 'LIST', '');

	RETURN raw_key;
END
$$
LANGUAGE plpgsql STRICT;


CREATE FUNCTION is_partitioned_by_pg10(
	relation	REGCLASS)
RETURNS BOOL AS
$$
DECLARE
	rows_count	int8;

BEGIN
	/* Check if this table is partitioned by PG 10 */
	EXECUTE '
		SELECT count(*)
		FROM pg_catalog.pg_partitioned_table
		WHERE partrelid = $1'
	USING relation INTO rows_count;

	RETURN rows_count > 0;

EXCEPTION
	WHEN others THEN
		RETURN FALSE;
END
$$
LANGUAGE plpgsql STRICT;


CREATE FUNCTION desugar_vanilla(
	relation	REGCLASS)
RETURNS BOOL AS
$$
DECLARE
	part_rel		pg_catalog.pg_class;
	temp_rel		pg_catalog.pg_class;
	temp_rel_name	text := build_sequence_name(relation);
	part_relid		regclass;
	temp_relid		regclass;
	partition		regclass;
	first_part		bool := TRUE;

BEGIN
	/* Create temporary table for storage */
	EXECUTE format('CREATE TABLE %s (LIKE %s)', temp_rel_name, relation);

	/* Initialize relids */
	part_relid = relation;
	temp_relid = temp_rel_name::regclass;

	/* Create check constraints on partitions */
	FOR partition IN SELECT inhrelid
					 FROM pg_catalog.pg_inherits
					 WHERE inhparent = part_relid LOOP

		/* Execute this check one time */
		IF first_part THEN
			/* Make sure that this table is partitioned by PG 10 */
			IF NOT is_partitioned_by_pg10(relation) THEN
				RAISE EXCEPTION 'table % is not managed by PostgreSQL 10', relation;
			END IF;

			first_part = FALSE;
		END IF;

		EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %s CHECK (%s)',
					   partition,
					   build_check_constraint_name(partition),
					   build_vanilla_part_condition(partition));

		RAISE NOTICE 'created constraint on partition %', partition;

		IF NOT desugar_vanilla(partition) THEN
			RAISE EXCEPTION 'cannot desugar partition %', partition;
		END IF;
	END LOOP;

	/* Read tuples of parent & temp tables */
	SELECT * FROM pg_catalog.pg_class WHERE oid = part_relid INTO part_rel;
	SELECT * FROM pg_catalog.pg_class WHERE oid = temp_relid INTO temp_rel;

	/* Use storage of temp table for parent */
	UPDATE pg_catalog.pg_class SET
		relkind		= temp_rel.relkind,
		relfilenode	= temp_rel.relfilenode
	WHERE oid = part_relid;

	/* Use storate of parent table for temp */
	UPDATE pg_catalog.pg_class SET
		relkind		= part_rel.relkind,
		relfilenode	= part_rel.relfilenode
	WHERE oid = temp_relid;

	/* Make temporary table kind of 'partitioned' */
	EXECUTE '
		UPDATE pg_catalog.pg_partitioned_table SET
			partrelid	= $1
		WHERE partrelid = $2'
	USING temp_relid, part_relid;

	/* Turn partitions into ordinary tables */
	UPDATE pg_catalog.pg_class SET
		relpartbound	= NULL,
		relispartition	= FALSE
	FROM pg_catalog.pg_inherits
	WHERE pg_catalog.pg_class.oid = inhrelid AND inhparent = part_relid;

	/* Finally, drop temporary table */
	EXECUTE format('DROP TABLE %s', temp_rel_name);

	RETURN TRUE;
END
$$
LANGUAGE plpgsql STRICT;


CREATE FUNCTION migrate_to_pathman(
	relation	REGCLASS,
	expression	TEXT DEFAULT NULL,
	run_tests	BOOL DEFAULT TRUE)
RETURNS BOOL AS
$$
BEGIN
	IF relation IS NULL THEN
		RAISE EXCEPTION 'relation should not be NULL';
	END IF;

	/* Desugar if partitioned by PG 10 */
	IF is_partitioned_by_pg10(relation) THEN
		expression = build_vanilla_part_key(relation);
		PERFORM desugar_vanilla(relation);
	ELSE
		RAISE EXCEPTION 'expression should not be NULL';
	END IF;

	/* Tell pg_pathman about this table */
	PERFORM add_to_pathman_config(relation, expression, NULL);

	RETURN TRUE;
END
$$
LANGUAGE plpgsql;
