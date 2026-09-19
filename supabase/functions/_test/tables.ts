import type { RecordedQuery } from './fake_supabase.ts'

// A table the shared fake answers from as the database would, as far as the
// outbox drain asks of it. The plain fake answers every query on a table with
// the same rows, which cannot tell one outbox row from the next or a hook that
// is on from one that is off; a test that runs the drain end to end needs
// tables that honour a filter and remember a write.
//
// `select` and `update` honour `eq`, `is`, `in` and `lte`; `insert` and
// `upsert` append with the defaults the columns would fill in; `order` and
// `limit` are ignored because rows are kept in insertion order and never
// reach a batch limit here.

export type Row = Record<string, unknown>

export interface TableOptions {
  /// Columns a unique index covers: a row that repeats them is not added,
  /// as `ignoreDuplicates` has the database do.
  unique?: string[]
  /// Embedded tables a filter can name as `table.column`, as an inner join
  /// does: the row of that table this row points at, or none.
  joins?: Record<string, (row: Row) => Row | undefined>
}

export function table(
  rows: Row[],
  defaults: () => Row = () => ({}),
  { unique, joins = {} }: TableOptions = {},
) {
  return (query: RecordedQuery): Row[] => {
    if (query.operation === 'insert' || query.operation === 'upsert') {
      const given = (Array.isArray(query.payload)
        ? query.payload
        : [query.payload]) as Row[]
      const added = given
        .filter((row) =>
          !unique ||
          !rows.some((have) =>
            unique.every((k) => have[k] === row[k])
          )
        )
        .map((row) => ({ ...defaults(), ...row }))
      rows.push(...added)
      return added
    }
    const matching = rows.filter((row) =>
      query.filters.every((filter) => matches(row, filter, joins))
    )
    if (query.operation === 'update') {
      for (const row of matching) {
        Object.assign(row, query.payload as Row)
      }
    }
    return matching
  }
}

function matches(
  row: Row,
  { method, args }: { method: string; args: unknown[] },
  joins: TableOptions['joins'] = {},
): boolean {
  if (!['eq', 'is', 'in', 'lte'].includes(method)) {
    return true
  }
  const [column, value] = args as [string, unknown]
  const [relation, field] = column.split('.')
  const target = field === undefined ? row : joins[relation]?.(row)
  if (target === undefined) {
    return false
  }
  const have = target[field ?? column]
  switch (method) {
    case 'in':
      return (value as unknown[]).includes(have)
    // Timestamps are ISO strings of one shape, which sort as they read.
    case 'lte':
      return (have as string) <= (value as string)
    default:
      return have === value
  }
}
