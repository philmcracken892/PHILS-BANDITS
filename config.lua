Config = {}

Config.Cooldown = 300 -- amount in seconds
Config.TriggerBandits = 100
Config.CalloffBandits = 250

-- Toggle for config-defined bandits
Config.EnableConfigBandits = false -- Set to false to disable predefined bandit spawns

-- Rewards for killing bandits
Config.EnableRewards = true
Config.RewardChance = 100 -- Percentage chance to get a reward (0-100)
Config.CashReward = {
    enabled = true,
    min = 5,
    max = 25
}

-- Item rewards - random item from this list
Config.ItemRewards = {
    enabled = true,
    minItems = 1,
    maxItems = 3,
    items = {
        { item = "bread", chance = 30, min = 1, max = 3 },
        
    }
}

Config.Bandits = {
    {
        enabled = true, -- Individual toggle for each location
        triggerPoint = vector3(1934.94, 1938.32, 265.49),
        bandits = {
            vector3(1975.67, 1961.53, 254.53),
            vector3(1954.77, 1863.75, 248.62),
            vector3(1876.39, 1882.09, 242.96),
        }
    },
    {
        enabled = true,
        triggerPoint = vector3(367.72, 1456.13, 178.76),
        bandits = {
            vector3(435.63, 1472.83, 167.16),
            vector3(439.89, 1351.65, 172.69),
            vector3(301.88, 1358.83, 174.67),
        }
    },
    {
        enabled = true,
        triggerPoint = vector3(-6268.53, -3596.53, -29.53),
        bandits = {
            vector3(-6325.13, -3626.81, -23.00),
            vector3(-6221.66, -3540.88, -19.92),
            vector3(-6166.75, -3604.88, -19.40),
        }
    },
    {
        enabled = true,
        triggerPoint = vector3(-151.32, 1463.23, 112.73),
        bandits = {
            vector3(-143.27, 1451.55, 112.66),
            vector3(-154.18, 1510.15, 118.01),
            vector3(-110.96, 1546.02, 116.68),
            vector3(-72.94, 1580.79, 114.42),
        }
    },
}

Config.Weapons = {
    0x772C8DD6, 
    0x169F59F7, 
    0xDB21AC8C, 
    0x6DFA071B,
    0xF5175BA1, 
    0xD2718D48, 
    0x797FBF5, 
    0x772C8DD6,
    0x7BBD1FF6, 
    0x63F46DE6, 
    0xA84762EC, 
    0xDDF7BC1E,
    0x20D13FF, 
    0x1765A8F8, 
    0x657065D6, 
    0x8580C63E,
    0x95B24592, 
    0x31B7B9FE, 
    0x88A855C, 
    0x1C02870C,
    0x28950C71, 
    0x6DFA071B
}

Config.HorseModels = {
    "A_C_HORSE_GANG_KIERAN",
    "A_C_HORSE_MORGAN_BAY",
    "A_C_HORSE_MORGAN_BAYROAN",
    "A_C_HORSE_MORGAN_FLAXENCHESTNUT",
    "A_C_HORSE_MORGAN_PALOMINO",
    "A_C_HORSE_KENTUCKYSADDLE_BLACK",
    "A_C_HORSE_KENTUCKYSADDLE_CHESTNUTPINTO",
    "A_C_HORSE_KENTUCKYSADDLE_GREY",
    "A_C_HORSE_KENTUCKYSADDLE_SILVERBAY",
    "A_C_HORSE_TENNESSEEWALKER_BLACKRABICANO",
    "A_C_HORSE_TENNESSEEWALKER_CHESTNUT",
    "A_C_HORSE_TENNESSEEWALKER_DAPPLEBAY",
    "A_C_HORSE_TENNESSEEWALKER_REDROAN",
    "A_C_HORSE_AMERICANPAINT_GREYOVERO",
    "A_C_HORSE_AMERICANSTANDARDBRED_PALOMINODAPPLE",
    "A_C_HORSE_AMERICANSTANDARDBRED_SILVERTAILBUCKSKIN",
    "A_C_HORSE_ANDALUSIAN_DARKBAY",
    "A_C_HORSE_ANDALUSIAN_ROSEGRAY",
    "A_C_HORSE_APPALOOSA_BROWNLEOPARD",
    "A_C_HORSE_APPALOOSA_LEOPARD",
    "A_C_HORSE_ARABIAN_BLACK",
    "A_C_HORSE_ARABIAN_ROSEGREYBAY",
    "A_C_HORSE_ARDENNES_BAYROAN",
    "A_C_HORSE_ARDENNES_STRAWBERRYROAN",
    "A_C_HORSE_BELGIAN_BLONDCHESTNUT",
    "A_C_HORSE_BELGIAN_MEALYCHESTNUT",
    "A_C_HORSE_DUTCHWARMBLOOD_CHOCOLATEROAN",
    "A_C_HORSE_DUTCHWARMBLOOD_SEALBROWN",
    "A_C_HORSE_DUTCHWARMBLOOD_SOOTYBUCKSKIN",
    "A_C_HORSE_HUNGARIANHALFBRED_DARKDAPPLEGREY",
    "A_C_HORSE_HUNGARIANHALFBRED_PIEBALDTOBIANO",
    "A_C_HORSE_MISSOURIFOXTROTTER_AMBERCHAMPAGNE",
    "A_C_HORSE_MISSOURIFOXTROTTER_SILVERDAPPLEPINTO",
    "A_C_HORSE_NOKOTA_REVERSEDAPPLEROAN",
    "A_C_HORSE_SHIRE_DARKBAY",
    "A_C_HORSE_SHIRE_LIGHTGREY",
    "A_C_HORSE_SUFFOLKPUNCH_SORREL",
    "A_C_HORSE_SUFFOLKPUNCH_REDCHESTNUT",
    "A_C_HORSE_TENNESSEEWALKER_FLAXENROAN",
    "A_C_HORSE_THOROUGHBRED_BRINDLE",
    "A_C_HORSE_TURKOMAN_DARKBAY",
    "A_C_HORSE_TURKOMAN_GOLD",
    "A_C_HORSE_TURKOMAN_SILVER",
    "A_C_HORSE_GANG_BILL",
    "A_C_HORSE_GANG_CHARLES",
    "A_C_HORSE_GANG_DUTCH",
    "A_C_HORSE_GANG_HOSEA",
    "A_C_HORSE_GANG_JAVIER",
    "A_C_HORSE_GANG_JOHN",
    "A_C_HORSE_GANG_KAREN",
    "A_C_HORSE_GANG_LENNY",
    "A_C_HORSE_GANG_MICAH",
    "A_C_HORSE_GANG_SADIE",
    "A_C_HORSE_GANG_SEAN",
    "A_C_HORSE_GANG_TRELAWNEY",
    "A_C_HORSE_GANG_UNCLE",
    "A_C_HORSE_GANG_SADIE_ENDLESSSUMMER",
    "A_C_HORSE_GANG_CHARLES_ENDLESSSUMMER",
    "A_C_HORSE_GANG_UNCLE_ENDLESSSUMMER",
    "A_C_HORSE_AMERICANPAINT_OVERO",
    "A_C_HORSE_AMERICANPAINT_TOBIANO",
    "A_C_HORSE_AMERICANPAINT_SPLASHEDWHITE",
    "A_C_HORSE_AMERICANSTANDARDBRED_BLACK",
    "A_C_HORSE_AMERICANSTANDARDBRED_BUCKSKIN",
    "A_C_HORSE_APPALOOSA_BLANKET",
    "A_C_HORSE_APPALOOSA_LEOPARDBLANKET",
    "A_C_HORSE_ARABIAN_WHITE",
    "A_C_HORSE_HUNGARIANHALFBRED_FLAXENCHESTNUT",
    "A_C_HORSE_MUSTANG_GRULLODUN",
    "A_C_HORSE_MUSTANG_WILDBAY",
    "A_C_HORSE_MUSTANG_TIGERSTRIPEDBAY",
    "A_C_HORSE_NOKOTA_BLUEROAN",
    "A_C_HORSE_NOKOTA_WHITEROAN",
    "A_C_HORSE_THOROUGHBRED_BLOODBAY",
    "A_C_HORSE_THOROUGHBRED_DAPPLEGREY",
    "A_C_Donkey_01",
}

Config.BanditsModel = {
    "G_M_M_UniBanditos_01",
    "A_M_M_GRIFANCYDRIVERS_01",
    "A_M_M_NEAROUGHTRAVELLERS_01",
    "A_M_M_RANCHERTRAVELERS_COOL_01",
    "A_M_M_RANCHERTRAVELERS_WARM_01",
}


-------------------------------
-- Zombie Settings
-------------------------------
Config.EnableZombies = true
Config.ZombieRewards = true
Config.ZombieRewardChance = 60 -- % chance to get reward from zombie kill

Config.ZombieCashReward = {
    enabled = true,
    min = 1,
    max = 5
}

Config.ZombieItemRewards = {
    enabled = true,
    minItems = 0,
    maxItems = 2,
    items = {
        { item = 'herbs', chance = 30, min = 1, max = 2 },
        { item = 'raw_meat', chance = 40, min = 1, max = 3 },
        
    }
}

-------------------------------
-- Spawn Limits
-------------------------------
Config.SpawnLimits = {
    banditsPerSpawn = 50,      -- Max bandits per single spawn
    zombiesPerSpawn = 100,     -- Max zombies per single spawn
    totalBandits = 100,        -- Max total bandits at once
    totalZombies = 200,        -- Max total zombies at once
    hordeSize = 50,            -- Max horde size
}

-- Zombie behavior settings
Config.ZombieSettings = {
    health = 100,                -- Zombie health (lower = easier to kill)
    damage = 15,                 -- Damage per hit
    speed = 1.0,                 -- Movement speed multiplier (1.0 = normal, 1.5 = fast)
    aggroRange = 50.0,           -- Range at which zombies detect players
    attackRange = 2.0,           -- Melee attack range
    canRun = true,               -- Whether zombies can run
    canSprint = false,           -- Whether zombies can sprint
}

-------------------------------
-- Zombie Models
-------------------------------
Config.ZombieModels = {
    { model = `CS_MrAdler`,                    outfit = 1},
    { model = `CS_ODProstitute`,               outfit = 0},
    { model = `CS_SwampFreak`,                 outfit = 0},
    { model = `CS_Vampire`,                    outfit = 0},
    { model = `CS_ChelonianMaster`,            outfit = 0},
    { model = `RE_Voice_Females_01`,           outfit = 0},
    { model = `RE_SavageAftermath_Males_01`,   outfit = 0},
    { model = `RE_SavageAftermath_Males_01`,   outfit = 1},
    { model = `RE_SavageAftermath_Males_01`,   outfit = 2},
    { model = `RE_SavageWarning_Males_01`,     outfit = 3},
    { model = `RE_SavageWarning_Males_01`,     outfit = 4},
    { model = `RE_SavageWarning_Males_01`,     outfit = 5},
    { model = `RE_SavageWarning_Males_01`,     outfit = 6},
    { model = `RE_SavageAftermath_Males_01`,   outfit = 3},
    { model = `RE_SavageAftermath_Males_01`,   outfit = 4},
    { model = `RE_SavageAftermath_Females_01`, outfit = 0},
    { model = `RE_SavageAftermath_Females_01`, outfit = 1},
    { model = `RE_CorpseCart_Males_01`,        outfit = 0},
    { model = `RE_CorpseCart_Males_01`,        outfit = 1},
    { model = `RE_CorpseCart_Males_01`,        outfit = 2},
    { model = `RE_LostFriend_Males_01`,        outfit = 0},
    { model = `RE_LostFriend_Males_01`,        outfit = 1},
    { model = `RE_LostFriend_Males_01`,        outfit = 2},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 0},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 1},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 2},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 3},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 4},
    { model = `A_F_M_ArmCholeraCorpse_01`,     outfit = 5},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 0},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 1},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 2},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 3},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 4},
    { model = `A_M_M_ArmCholeraCorpse_01`,     outfit = 5},
    { model = `U_M_M_CircusWagon_01`,          outfit = 0},
    { model = `A_M_M_UniCorpse_01`,            outfit = 0},
    { model = `A_M_M_UniCorpse_01`,            outfit = 3},
    { model = `A_M_M_UniCorpse_01`,            outfit = 4},
    { model = `A_M_M_UniCorpse_01`,            outfit = 5},
    { model = `A_M_M_UniCorpse_01`,            outfit = 8},
    { model = `A_M_M_UniCorpse_01`,            outfit = 15},
    { model = `A_M_M_UniCorpse_01`,            outfit = 16},
    { model = `A_F_M_UniCorpse_01`,            outfit = 0},
    { model = `A_F_M_UniCorpse_01`,            outfit = 1},
    { model = `A_F_M_UniCorpse_01`,            outfit = 2},
    { model = `A_F_M_UniCorpse_01`,            outfit = 4},
    { model = `A_F_M_UniCorpse_01`,            outfit = 5},
    { model = `U_M_M_APFDeadMan_01`,           outfit = 0}
}