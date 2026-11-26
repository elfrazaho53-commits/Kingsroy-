class_name StageDefs
extends RefCounted

const STAGES := [
	{
		"id": "bassam",
		"name": "Grand-Bassam — Front de mer",
		"seed": 11,
		"length": 1400.0,
		"target_time": 80.0,
		"reward": 600,
		"difficulty": "Facile",
		"theme": "coast",
	},
	{
		"id": "abidjan",
		"name": "Abidjan — Le Plateau",
		"seed": 27,
		"length": 1800.0,
		"target_time": 100.0,
		"reward": 800,
		"difficulty": "Facile",
		"theme": "city",
	},
	{
		"id": "yamoussoukro",
		"name": "Yamoussoukro — Piste du Lac",
		"seed": 42,
		"length": 2200.0,
		"target_time": 125.0,
		"reward": 1100,
		"difficulty": "Moyen",
		"theme": "savane",
	},
	{
		"id": "man",
		"name": "Man — Mont Tonkoui",
		"seed": 73,
		"length": 2600.0,
		"target_time": 145.0,
		"reward": 1500,
		"difficulty": "Difficile",
		"theme": "montagne",
	},
	{
		"id": "comoe",
		"name": "Parc du Comoé — Piste Rouge",
		"seed": 99,
		"length": 3000.0,
		"target_time": 170.0,
		"reward": 2000,
		"difficulty": "Expert",
		"theme": "savane",
	},
]

const CARS := [
	{
		"id": "taxi",
		"name": "Taxi Abidjan",
		"price": 0,
		"top_speed": 38.0,
		"accel": 15.0,
		"grip": 6.5,
		"color": Color(0.92, 0.55, 0.08),
		"desc": "L'équilibre parfait pour débuter sur les pistes ivoiriennes.",
	},
	{
		"id": "foureux",
		"name": "4x4 Tonkoui",
		"price": 3500,
		"top_speed": 42.0,
		"accel": 13.0,
		"grip": 8.5,
		"color": Color(0.12, 0.38, 0.18),
		"desc": "Adhérence redoutable hors-piste, taillé pour la brousse.",
	},
	{
		"id": "wari",
		"name": "Wari RS Proto",
		"price": 8000,
		"top_speed": 52.0,
		"accel": 19.0,
		"grip": 6.0,
		"color": Color(0.78, 0.06, 0.06),
		"desc": "Pur sprint : le plus rapide, mais il exige un pilotage précis.",
	},
]

static func get_stage(stage_id: String) -> Dictionary:
	for stage in STAGES:
		if stage.id == stage_id:
			return stage
	return STAGES[0]
