Config = {}

Config.Duration = 15              -- secondes pour survivre / tuer le ped
Config.SpawnDistance = 18.0       -- distance de spawn du tueur autour du joueur
Config.PedModel = `Terrifier_ATC`
Config.Weapon = `WEAPON_KNIFE`
Config.PedHealth = 200
Config.RunSpeed = 1.25            -- 1.0 = normal, 1.49 = max
Config.GoToSpeed = 3.0            -- vitesse de déplacement du tueur (1.0 marche, 2.0 course, 3.0 sprint)
Config.AttackDistance = 1.6       -- distance à partir de laquelle il poignarde
Config.HitDamage = 25             -- dégâts par coup (200 PV = mort en ~4 s)
Config.HitInterval = 500          -- ms entre chaque coup
Config.VehicleExplosion = false    -- si le joueur est en véhicule : un Cerberus arrive et le véhicule explose
Config.CerberusModel = `cerberus` -- nécessite un serveur en build 2189 ou plus
Config.CerberusDistance = 25.0    -- distance de spawn du Cerberus derrière le véhicule
Config.ExplodeDistance = 6.0      -- le véhicule explose quand le Cerberus est à cette distance
Config.ExplodeTimeout = 5000      -- ms avant explosion forcée (ou si le Cerberus ne peut pas spawn)

-- Groupes autorisés à lancer la commande
Config.AdminGroups = { 'fondateur'}

-- Event aléatoire automatique (mettre false pour désactiver)
Config.RandomEvent = {
    enabled = false,
    minMinutes = 20,
    maxMinutes = 45,
}