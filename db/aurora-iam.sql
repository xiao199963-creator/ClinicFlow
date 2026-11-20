-- Legacy Phase 1 IAM alternative only; not used by the approved CF-401 password runtime.
-- Staff column SELECT and status UPDATE are intentionally absent; do not run for staff acceptance.
-- Run as the bootstrap administrator after schema.sql (Aurora MySQL only).
CREATE USER IF NOT EXISTS 'clinicflow_app'@'%'
  IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS' REQUIRE SSL;

GRANT SELECT (id, name, suburb)
  ON clinicflow.clinics TO 'clinicflow_app'@'%';
GRANT SELECT (clinic_id, slot_date, slot_hour, status),
      INSERT (clinic_id, patient_name, mobile, slot_date, slot_hour)
  ON clinicflow.bookings TO 'clinicflow_app'@'%';

SHOW GRANTS FOR 'clinicflow_app'@'%';
