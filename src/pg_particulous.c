#include "postgres.h"

#include "catalog/pg_inherits_fn.h"
#include "executor/spi.h"
#include "fmgr.h"
#include "storage/lmgr.h"
#include "utils/builtins.h"
#include "utils/ruleutils.h"
#include "utils/syscache.h"
#include "utils/lsyscache.h"

#if PG_VERSION_NUM >= 100000
#include "catalog/partition.h"
#endif


PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(build_vanilla_part_condition);


Datum
build_vanilla_part_condition(PG_FUNCTION_ARGS)
{
#if PG_VERSION_NUM >= 100000
	Oid			relationId = PG_GETARG_OID(0);
	Expr	   *constr_expr;
	List	   *context;
	char	   *consrc;

	constr_expr = get_partition_qual_relid(relationId);

	if (IsA(constr_expr, BoolExpr))
	{
		BoolExpr   *bool_expr = (BoolExpr *) constr_expr;
		List	   *new_args = NIL;
		ListCell   *lc;

		foreach (lc, bool_expr->args)
		{
			Node *node = lfirst(lc);

			if (!IsA(node, NullTest))
				new_args = lappend(new_args, node);
		}

		if (new_args == NIL)
			elog(ERROR, "partitioning constraint is broken");

		bool_expr->args = new_args;
	}

	/* Quick exit if not a partition */
	if (constr_expr == NULL)
		PG_RETURN_NULL();

	/* Deparse and return the constraint expression */
	context = deparse_context_for(get_rel_name(relationId), relationId);
	consrc = deparse_expression((Node *) constr_expr, context, false, false);

	PG_RETURN_TEXT_P(cstring_to_text(consrc));
#else
	ereport(ERROR, (ERRCODE_FEATURE_NOT_SUPPORTED,
					errmsg("this function works only on PostgreSQL 10")));

	PG_RETURN_NULL(); /* keep compiler happy */
#endif
}
