MedDB = {}

local RESOURCE = GetCurrentResourceName()

function MedDB.init()
    local migration = LoadResourceFile(RESOURCE, 'sql/001_init.sql')
    if migration then
        MySQL.query.await(migration)
    else
        print('[MED] Missing SQL migration file sql/001_init.sql')
    end
end

function MedDB.fetchPlayerState(charIdentifier)
    return MySQL.single.await('SELECT * FROM med_player_state WHERE char_identifier = ?', { charIdentifier })
end

function MedDB.upsertPlayerState(charIdentifier, state)
    MySQL.insert.await([[
        INSERT INTO med_player_state (char_identifier, pain, shock, hemorrhage, infection_risk, has_open_wound, sprint_abuse, fracture_state, projectile_state, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            pain = VALUES(pain),
            shock = VALUES(shock),
            hemorrhage = VALUES(hemorrhage),
            infection_risk = VALUES(infection_risk),
            has_open_wound = VALUES(has_open_wound),
            sprint_abuse = VALUES(sprint_abuse),
            fracture_state = VALUES(fracture_state),
            projectile_state = VALUES(projectile_state),
            updated_at = NOW()
    ]], {
        charIdentifier,
        state.pain,
        state.shock,
        state.hemorrhage,
        state.infection_risk,
        state.has_open_wound and 1 or 0,
        state.sprint_abuse,
        json.encode(state.fracture_state or {}),
        json.encode(state.projectile_state or {})
    })
end

function MedDB.fetchInjuries(charIdentifier)
    return MySQL.query.await('SELECT * FROM med_injuries WHERE char_identifier = ? ORDER BY created_at DESC', { charIdentifier })
end

function MedDB.insertInjury(charIdentifier, injury)
    return MySQL.insert.await([[
        INSERT INTO med_injuries (char_identifier, injury_type, body_zone, severity, cause, has_projectile, projectile_type, fracture_type, is_open_wound, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ]], {
        charIdentifier,
        injury.injury_type,
        injury.body_zone,
        injury.severity,
        injury.cause,
        injury.has_projectile and 1 or 0,
        injury.projectile_type,
        injury.fracture_type,
        injury.is_open_wound and 1 or 0,
        json.encode(injury.metadata or {})
    })
end

function MedDB.updateInjury(injuryId, patch)
    MySQL.update.await([[
        UPDATE med_injuries
        SET severity = ?, has_projectile = ?, is_treated = ?, treatment_note = ?, is_open_wound = ?, metadata = ?, updated_at = NOW()
        WHERE id = ?
    ]], {
        patch.severity,
        patch.has_projectile and 1 or 0,
        patch.is_treated and 1 or 0,
        patch.treatment_note,
        patch.is_open_wound and 1 or 0,
        json.encode(patch.metadata or {}),
        injuryId
    })
end

function MedDB.clearInjuries(charIdentifier)
    MySQL.update.await('DELETE FROM med_injuries WHERE char_identifier = ?', { charIdentifier })
    MySQL.update.await('DELETE FROM med_treatments WHERE char_identifier = ?', { charIdentifier })
    MySQL.update.await('DELETE FROM med_player_state WHERE char_identifier = ?', { charIdentifier })
end

function MedDB.insertTreatment(charIdentifier, doctorIdentifier, details)
    MySQL.insert.await([[
        INSERT INTO med_treatments (char_identifier, doctor_identifier, treatment_type, operation_log, result, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], {
        charIdentifier,
        doctorIdentifier,
        details.treatment_type,
        json.encode(details.operation_log or {}),
        json.encode(details.result or {})
    })
end

function MedDB.insertLog(level, action, payload)
    MySQL.insert.await([[
        INSERT INTO med_logs (level, action, payload, created_at)
        VALUES (?, ?, ?, NOW())
    ]], { level, action, json.encode(payload or {}) })
end
