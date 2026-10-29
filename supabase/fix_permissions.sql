-- Fix Permissions and Security Definer for GrainTrust PDS
-- Run this in your Supabase Project SQL Editor (https://supabase.com/dashboard/project/byxvxvsvhiyeryavgafx/sql)

-- 1. Grant public SELECT access on persons and household_profiles so cards can be fetched with citizen names
DO $$ BEGIN
    CREATE POLICY "Public read persons" ON persons FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Public read household_profiles" ON household_profiles FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Allow deleting unapproved registration drafts
DO $$ BEGIN
    CREATE POLICY "Public delete registrations" ON registrations FOR DELETE USING (status <> 'APPROVED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. Update fn_approve_registration with SECURITY DEFINER
CREATE OR REPLACE FUNCTION fn_approve_registration(
    p_reg_id TEXT,
    p_actor_id TEXT DEFAULT 'admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reg RECORD;
    v_person_id TEXT;
    v_card_id TEXT;
    v_quota_id TEXT;
    v_profile_id TEXT;
    v_family_count INT;
    v_phone TEXT;
    v_quota_amount NUMERIC(12, 2);
    v_node_id TEXT;
    v_result JSONB;
BEGIN
    -- 1. Fetch and validate registration
    SELECT * INTO v_reg FROM registrations WHERE id = p_reg_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registration % not found', p_reg_id;
    END IF;

    IF v_reg.status NOT IN ('SUBMITTED', 'VERIFIED') THEN
        RAISE EXCEPTION 'Cannot approve registration in status %', v_reg.status;
    END IF;

    v_family_count := (v_reg.data->>'family_count')::INT;
    v_phone := v_reg.data->>'phone_number';
    v_node_id := COALESCE(v_reg.node_id, (SELECT id FROM distribution_nodes ORDER BY created_at ASC LIMIT 1));
    v_quota_amount := v_family_count * 10.0; -- 10kg per household member

    -- 2. Check phone uniqueness
    IF EXISTS (SELECT 1 FROM persons WHERE phone_number = v_phone) THEN
        RAISE EXCEPTION 'Phone number % is already registered to an approved citizen', v_phone;
    END IF;

    -- 3. Create Person
    v_person_id := 'person_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
    INSERT INTO persons (id, first_name, last_name, phone_number, dob)
    VALUES (
        v_person_id,
        v_reg.data->>'first_name',
        v_reg.data->>'last_name',
        v_phone,
        (v_reg.data->>'dob')::DATE
    );

    -- 4. Create Household Profile
    v_profile_id := 'prof_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
    INSERT INTO household_profiles (id, person_id, family_count, yearly_income, address, city, state)
    VALUES (
        v_profile_id,
        v_person_id,
        v_family_count,
        (v_reg.data->>'yearly_income')::NUMERIC,
        v_reg.data->>'address',
        v_reg.data->>'city',
        v_reg.data->>'state'
    );

    -- 5. Create Card
    v_card_id := 'card_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
    INSERT INTO cards (id, person_id, status, issued_at)
    VALUES (v_card_id, v_person_id, 'ACTIVE', NOW());

    -- 6. Allocate Monthly Quota Lease (associated with registration node)
    v_quota_id := 'quota_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
    INSERT INTO quota_leases (id, card_id, node_id, allocated_qty, consumed_qty, period_start)
    VALUES (v_quota_id, v_card_id, v_node_id, v_quota_amount, 0, CURRENT_DATE);

    -- 7. Update Registration to APPROVED
    UPDATE registrations
    SET status = 'APPROVED',
        person_id = v_person_id,
        card_id = v_card_id,
        node_id = v_node_id,
        updated_at = NOW()
    WHERE id = p_reg_id;

    -- 8. Audit Event
    INSERT INTO audit_events (id, actor_id, action, resource_type, resource_id, details, timestamp)
    VALUES (
        'audit_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
        p_actor_id,
        'REGISTRATION_APPROVED',
        'REGISTRATION',
        p_reg_id,
        jsonb_build_object(
            'person_id', v_person_id,
            'card_id', v_card_id,
            'allocated_quota', v_quota_amount,
            'node_id', v_node_id
        ),
        NOW()
    );

    -- 9. Return JSON payload
    SELECT jsonb_build_object(
        'success', true,
        'registration_id', p_reg_id,
        'person_id', v_person_id,
        'card_id', v_card_id,
        'allocated_qty', v_quota_amount,
        'node_id', v_node_id
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 3. Update fn_online_dispense with SECURITY DEFINER
CREATE OR REPLACE FUNCTION fn_online_dispense(
    p_idempotency_key TEXT,
    p_card_id TEXT,
    p_lot_id TEXT,
    p_node_id TEXT,
    p_quantity NUMERIC,
    p_actor_id TEXT DEFAULT 'distribution-operator'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cached RECORD;
    v_card RECORD;
    v_lot RECORD;
    v_lease RECORD;
    v_txn_id TEXT;
    v_hist_id TEXT;
    v_audit_id TEXT;
    v_response JSONB;
BEGIN
    -- 1. Check Idempotency Key
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
        SELECT * INTO v_cached FROM idempotency_records WHERE key = p_idempotency_key;
        IF FOUND THEN
            RETURN v_cached.response_body;
        END IF;
    END IF;

    -- 2. Validate input parameters
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    -- 3. Row lock on Card
    SELECT * INTO v_card FROM cards WHERE id = p_card_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Card % not found', p_card_id;
    END IF;
    IF v_card.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Card % is not ACTIVE (status: %)', p_card_id, v_card.status;
    END IF;

    -- 4. Row lock on Quota Lease
    SELECT * INTO v_lease FROM quota_leases
    WHERE card_id = p_card_id AND (node_id = p_node_id OR node_id = 'GLOBAL')
    ORDER BY (allocated_qty - consumed_qty) DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND OR (v_lease.allocated_qty - v_lease.consumed_qty) < p_quantity THEN
        v_txn_id := 'txn_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
        INSERT INTO distribution_transactions (id, card_id, node_id, lot_id, quantity, state, idempotency_key, failure_reason)
        VALUES (v_txn_id, p_card_id, p_node_id, p_lot_id, p_quantity, 'FAIL_REASON', p_idempotency_key, 'ERR_201');

        INSERT INTO transaction_state_history (id, txn_id, from_state, to_state, reason_code, actor_id)
        VALUES ('hist_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'ATTEMPT', 'FAIL_REASON', 'ERR_201', p_actor_id);

        INSERT INTO failures (id, txn_id, type, code, node_id, retryable, metadata)
        VALUES ('fail_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'TXN_FAILURE', 'ERR_201', p_node_id, false,
            jsonb_build_object('reason', 'Quota exceeded', 'card_id', p_card_id, 'requested', p_quantity));

        v_response := jsonb_build_object(
            'success', false,
            'code', 'ERR_201',
            'state', 'FAIL_REASON',
            'message', 'Beneficiary Quota Limit Exceeded. Card balance cannot fulfill this quantity.',
            'transaction_id', v_txn_id
        );

        IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
            INSERT INTO idempotency_records (id, key, status_code, response_body)
            VALUES ('idem_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), p_idempotency_key, 409, v_response);
        END IF;

        RETURN v_response;
    END IF;

    -- 5. Row lock on Grain Lot
    SELECT * INTO v_lot FROM grain_lots WHERE id = p_lot_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Grain lot % not found', p_lot_id;
    END IF;

    IF v_lot.remaining_quantity < p_quantity THEN
        v_txn_id := 'txn_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
        INSERT INTO distribution_transactions (id, card_id, node_id, lot_id, quantity, state, idempotency_key, failure_reason)
        VALUES (v_txn_id, p_card_id, p_node_id, p_lot_id, p_quantity, 'FAIL_REASON', p_idempotency_key, 'ERR_202');

        INSERT INTO transaction_state_history (id, txn_id, from_state, to_state, reason_code, actor_id)
        VALUES ('hist_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'ATTEMPT', 'FAIL_REASON', 'ERR_202', p_actor_id);

        INSERT INTO failures (id, txn_id, type, code, node_id, retryable, metadata)
        VALUES ('fail_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'TXN_FAILURE', 'ERR_202', p_node_id, false,
            jsonb_build_object('reason', 'Lot depleted', 'lot_id', p_lot_id, 'remaining', v_lot.remaining_quantity));

        v_response := jsonb_build_object(
            'success', false,
            'code', 'ERR_202',
            'state', 'FAIL_REASON',
            'message', 'Emergency Grain Lot Depleted. The lot does not have sufficient remaining grain.',
            'transaction_id', v_txn_id
        );

        IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
            INSERT INTO idempotency_records (id, key, status_code, response_body)
            VALUES ('idem_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), p_idempotency_key, 409, v_response);
        END IF;

        RETURN v_response;
    END IF;

    -- 6. Apply atomic deductions
    UPDATE quota_leases
    SET consumed_qty = consumed_qty + p_quantity,
        updated_at = NOW()
    WHERE id = v_lease.id;

    UPDATE grain_lots
    SET remaining_quantity = remaining_quantity - p_quantity,
        updated_at = NOW()
    WHERE id = p_lot_id;

    -- 7. Record transaction & state transition
    v_txn_id := 'txn_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
    INSERT INTO distribution_transactions (id, card_id, node_id, lot_id, quantity, state, idempotency_key)
    VALUES (v_txn_id, p_card_id, p_node_id, p_lot_id, p_quantity, 'RECONCILED', p_idempotency_key);

    INSERT INTO transaction_state_history (id, txn_id, from_state, to_state, actor_id)
    VALUES
        ('hist_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'ATTEMPT', 'PROVISIONAL_ISSUE', p_actor_id),
        ('hist_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), v_txn_id, 'PROVISIONAL_ISSUE', 'RECONCILED', p_actor_id);

    -- 8. Audit Event
    INSERT INTO audit_events (id, actor_id, action, resource_type, resource_id, details)
    VALUES (
        'audit_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
        p_actor_id,
        'GRAIN_DISPENSED_ONLINE',
        'TRANSACTION',
        v_txn_id,
        jsonb_build_object(
            'card_id', p_card_id,
            'lot_id', p_lot_id,
            'node_id', p_node_id,
            'quantity', p_quantity,
            'remaining_lot_stock', v_lot.remaining_quantity - p_quantity,
            'remaining_quota', v_lease.allocated_qty - (v_lease.consumed_qty + p_quantity)
        )
    );

    v_response := jsonb_build_object(
        'success', true,
        'state', 'RECONCILED',
        'transaction_id', v_txn_id,
        'quantity', p_quantity,
        'lot_id', p_lot_id,
        'card_id', p_card_id,
        'remaining_lot_qty', v_lot.remaining_quantity - p_quantity,
        'remaining_card_qty', v_lease.allocated_qty - (v_lease.consumed_qty + p_quantity)
    );

    IF p_idempotency_key IS NOT NULL AND p_idempotency_key <> '' THEN
        INSERT INTO idempotency_records (id, key, status_code, response_body)
        VALUES ('idem_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16), p_idempotency_key, 201, v_response);
    END IF;

    RETURN v_response;
END;
$$;

