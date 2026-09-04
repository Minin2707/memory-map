ALTER TABLE invites
    ADD COLUMN role VARCHAR(20);

UPDATE invites
SET role = 'CO_OWNER'
WHERE role IS NULL;

ALTER TABLE invites
    ALTER COLUMN role SET NOT NULL;

ALTER TABLE invites
    ADD CONSTRAINT chk_invites_role
        CHECK (role IN ('CO_OWNER', 'EDITOR', 'VIEWER'));
