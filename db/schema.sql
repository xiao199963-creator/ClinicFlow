CREATE TABLE IF NOT EXISTS clinics (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  suburb VARCHAR(60) NOT NULL
);

CREATE TABLE IF NOT EXISTS bookings (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  clinic_id INT UNSIGNED NOT NULL,
  patient_name VARCHAR(100) NOT NULL,
  mobile VARCHAR(20) NOT NULL,
  slot_date DATE NOT NULL,
  slot_hour TINYINT UNSIGNED NOT NULL,
  status ENUM('booked','attended','cancelled') NOT NULL DEFAULT 'booked',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  slot_key VARCHAR(40) GENERATED ALWAYS AS (IF(status = 'cancelled', NULL, CONCAT(clinic_id, '-', slot_date, '-', slot_hour))) STORED,
  UNIQUE KEY uq_active_slot (slot_key),
  KEY idx_clinic_date (clinic_id, slot_date),
  CONSTRAINT fk_bookings_clinic FOREIGN KEY (clinic_id) REFERENCES clinics (id)
);

INSERT IGNORE INTO clinics (id, name, suburb) VALUES
  (1, 'Harbour Physio', 'Sydney'),
  (2, 'Bright Smile Dental', 'Parramatta'),
  (3, 'Calm Mind Psychology', 'Chatswood')
