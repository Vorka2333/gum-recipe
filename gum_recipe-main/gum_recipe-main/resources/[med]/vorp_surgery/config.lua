Config = {}

Config.Debug = false
Config.Locale = 'fr'

Config.Tables = {
    UseFixedTables = true,
    Fixed = {
        { id = 'valentine_hospital_1', coords = vector3(-286.62, 805.12, 119.39), heading = 108.8, radius = 2.2 },
        { id = 'saintdenis_hospital_1', coords = vector3(2732.15, -1225.01, 50.36), heading = 177.3, radius = 2.2 }
    }
}

Config.Surgery = {
    MinDurationMs = 45000,
    MaxDurationMs = 900000,
    MaxActions = 200,
    RequirePatientOnTable = true,
    AllowedDistance = 3.0,
    CancelOpenWoundBleed = 15,
    CancelInfectionRisk = 10,
    RequiredActions = { 'select_zone', 'incision', 'retractors', 'sutures' }
}

Config.Injury = {
    AutoDetectionEnabled = false,
    SaveThrottleMs = 1200,
    Zones = { 'head', 'thorax', 'abdomen', 'arm_l', 'arm_r', 'leg_l', 'leg_r' },
    Severity = { min = 1, max = 100 },
    ProgressionIntervalSec = 30,
    InfectionTickChance = 8,
    OpenBleedTick = 4,
    SprintAggravationTick = 5,
    ShockFromBleedThreshold = 60
}

Config.PatientTable = {
    AllowPatientSelfLay = true,
    AllowDoctorPlace = true,
    PromptKeyLay = 0xCEFD9220, -- E
    PromptKeyStartSurgery = 0x760A9C6F, -- G
    PromptKeyPlacePatient = 0x24978A28, -- H
    SnapZOffset = 0.85,
    UseScenarioWhenLaying = false,
    LayingScenario = `WORLD_HUMAN_SLEEP_GROUND_ARM`
}

Config.Inventory = {
    Strict = true,
    LogMissingBridgeAsError = true,
    Items = {
        surgical_kit = 'surgical_kit',
        scalpel = 'scalpel',
        forceps = 'forceps',
        retractors = 'retractors',
        clamps = 'clamps',
        sutures = 'sutures',
        antiseptic = 'antiseptic',
        splint_kit = 'splint_kit',
        morphine = 'morphine',
        bandage = 'bandage'
    },
    RequiredBase = { 'surgical_kit', 'scalpel', 'forceps', 'retractors', 'clamps', 'sutures', 'antiseptic' },
    RequiredFracture = { 'splint_kit' },
    Optional = { 'morphine', 'bandage' },
    ConsumeItems = false
}

Config.Effects = {
    SyncIntervalSec = 4,
    ForceStateSyncSec = 20,
    Blur = { enabled = true, pulseMs = 1800, strength = 0.3 },
    Stamina = { drainWhileSevere = 6, severeThreshold = 55 },
    Sprint = { maxContinuousSec = 7, ragdollDurationMs = 2500 },
    Fracture = { legMoveClipset = 'move_m@injured', speedMultiplier = 0.75 }
}

Config.Logging = {
    PrintToConsole = true,
    SaveToDb = true,
    SaveToFile = false,
    FilePath = 'logs/med_logs.jsonl',
    FileFlushIntervalSec = 15,
    FileFlushBatchSize = 25,
    FlagAdminOnExploit = true
}

Config.Admin = {
    Mode = 'both', -- 'vorp' | 'ace' | 'both'
    GroupAce = 'group.admin',
    AllowedVorpGroups = { 'admin', 'superadmin', 'mod' }
}

Config.NUI = {
    Canvas = {
        width = 620,
        height = 520,
        maxIdenticalActionBurst = 60
    },
    ToolHotkeys = {
        [1] = 'scalpel',
        [2] = 'retractors',
        [3] = 'forceps',
        [4] = 'clamps',
        [5] = 'sutures',
        [6] = 'antiseptic'
    }
}
