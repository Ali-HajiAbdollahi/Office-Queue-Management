-- Run once on the intended Neon database, using the SQL Editor.

-- This file targets schema_OQM. Adapt EVERY schema reference if renamed.

-- No tables/columns are added, no tickets deleted, no data converted.

BEGIN;

LOCK TABLE "schema_OQM".services, "schema_OQM".tickets

  IN SHARE ROW EXCLUSIVE MODE;

 

DO $$

BEGIN

  IF NOT EXISTS (

    SELECT 1 FROM information_schema.columns

    WHERE table_schema = 'schema_OQM' AND table_name = 'tickets'

      AND column_name = 'issued_at' AND data_type = 'timestamp with time zone'

  ) THEN

    RAISE EXCEPTION 'tickets.issued_at must be timestamptz; ask the DB owner to establish the timezone of existing data before conversion';

  END IF;

  IF NOT EXISTS (

    SELECT 1 FROM information_schema.columns

    WHERE table_schema = 'schema_OQM' AND table_name = 'tickets'

      AND column_name = 'code' AND data_type = 'character varying'

      AND (character_maximum_length IS NULL OR character_maximum_length >= 6)

  ) THEN

    RAISE EXCEPTION 'tickets.code must accept at least six characters';

  END IF;

  IF EXISTS (

    SELECT 1 FROM information_schema.columns

    WHERE table_schema = 'schema_OQM' AND table_name = 'tickets'

      AND column_name IN ('business_day', 'daily_number')

      AND is_nullable = 'NO' AND column_default IS NULL

  ) THEN

    RAISE EXCEPTION 'Legacy required columns from the previous design remain: reconcile the database with fix/db_conflicts before proceeding';

  END IF;

  IF EXISTS (

    SELECT 1 FROM "schema_OQM".services

    WHERE tag IS NULL OR upper(left(btrim(tag), 1)) !~ '^[A-Z]$'

  ) THEN

    RAISE EXCEPTION 'Existing service tags must start with an ASCII letter';

  END IF;

  IF EXISTS (

    SELECT 1 FROM "schema_OQM".tickets

    WHERE code IS NULL OR code !~ '^[A-Z]-[0-9]{1,4}$'

  ) THEN

    RAISE EXCEPTION 'Existing ticket codes are incompatible with numeric suffix extraction';

  END IF;

END $$;

 

-- This is the concurrency guarantee. A SELECT before INSERT alone is insufficient.

CREATE UNIQUE INDEX IF NOT EXISTS uq_services_ticket_initial

  ON "schema_OQM".services ((upper(left(btrim(tag), 1))));

 

-- Extra protection against duplicated codes within a service and working day.

CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_service_day_code

  ON "schema_OQM".tickets (

    service_id,

    (((issued_at AT TIME ZONE 'Europe/Rome') - interval '6 hours')::date),

    code

  );

 

COMMIT;