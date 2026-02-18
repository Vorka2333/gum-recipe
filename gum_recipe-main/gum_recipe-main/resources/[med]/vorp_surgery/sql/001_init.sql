CREATE TABLE IF NOT EXISTS med_player_state (
    char_identifier VARCHAR(64) NOT NULL PRIMARY KEY,
    pain TINYINT UNSIGNED NOT NULL DEFAULT 0,
    shock TINYINT UNSIGNED NOT NULL DEFAULT 0,
    hemorrhage TINYINT UNSIGNED NOT NULL DEFAULT 0,
    infection_risk TINYINT UNSIGNED NOT NULL DEFAULT 0,
    has_open_wound TINYINT(1) NOT NULL DEFAULT 0,
    sprint_abuse TINYINT UNSIGNED NOT NULL DEFAULT 0,
    fracture_state JSON NULL,
    projectile_state JSON NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_player_state_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS med_injuries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    char_identifier VARCHAR(64) NOT NULL,
    injury_type VARCHAR(32) NOT NULL,
    body_zone VARCHAR(32) NOT NULL,
    severity TINYINT UNSIGNED NOT NULL,
    cause VARCHAR(64) NULL,
    has_projectile TINYINT(1) NOT NULL DEFAULT 0,
    projectile_type VARCHAR(32) NULL,
    fracture_type VARCHAR(16) NULL,
    is_open_wound TINYINT(1) NOT NULL DEFAULT 0,
    is_treated TINYINT(1) NOT NULL DEFAULT 0,
    treatment_note VARCHAR(128) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_injuries_char (char_identifier),
    INDEX idx_injuries_zone (char_identifier, body_zone),
    INDEX idx_injuries_open (char_identifier, is_open_wound)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS med_treatments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    char_identifier VARCHAR(64) NOT NULL,
    doctor_identifier VARCHAR(64) NULL,
    treatment_type VARCHAR(32) NOT NULL,
    operation_log JSON NULL,
    result JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_treatments_char (char_identifier),
    INDEX idx_treatments_doctor (doctor_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS med_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    level VARCHAR(16) NOT NULL,
    action VARCHAR(64) NOT NULL,
    payload JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_logs_level (level),
    INDEX idx_logs_action (action),
    INDEX idx_logs_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
