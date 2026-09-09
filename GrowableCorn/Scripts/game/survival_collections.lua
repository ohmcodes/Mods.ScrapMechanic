dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )

g_resourceCollectorHarvests = {
	ITEMS.obj_harvest_wood,
	ITEMS.obj_harvest_wood2,
	ITEMS.obj_harvest_metal,
	ITEMS.obj_harvest_metal2,
	ITEMS.obj_harvest_stone,
	ITEMS.obj_harvest_crystal,
}

g_gravelCollectorHarvests = {
	ITEMS.obj_resource_drillcasingt1,
	ITEMS.obj_resource_drillcasingt3,
	ITEMS.obj_resource_drillcasingt4,
	ITEMS.obj_resource_drillcasingrich,
	ITEMS.obj_resource_drillcasingmixedt1,
	ITEMS.obj_resource_drillcasingmixedt3,
	ITEMS.obj_resource_drillcasingmixedt4,
	ITEMS.obj_resource_drillcasingmixedrich,
}

g_dangerousObjects = {
	obj_powertools_sawblade,
	obj_powertools_drill,
	obj_interactive_plasmadrill_lvl1,
	obj_interactive_plasmadrill_lvl2,
	obj_interactive_plasmadrill_lvl3
}

g_capsules = {
	sm.uuid.new( "34d22fc5-0a45-4d71-9aaf-64df1355c272" ), -- Totebot
	sm.uuid.new( "da993c70-ba90-4748-8a22-6246bad32930" ), -- Haybot
	sm.uuid.new( "4c5c3ffd-9aaf-4ded-a7c5-452d239cac32" ), -- Tapebot
	sm.uuid.new( "50f624e6-7e33-4118-8252-2219e73e9af1" ), -- Red Tapebot
	sm.uuid.new( "9c1f1f76-7391-4661-ae32-e96250030229" ), -- Farmbot
	sm.uuid.new( "7735cab3-56d7-4d52-b615-090d021e8fdc" ), -- Glowgorp
	sm.uuid.new( "12cc6e9a-6d66-4a9a-bb59-b13a50373fd8" )  -- Woc
}

g_explosives = { 
	obj_interactive_propanetank_small,
	obj_interactive_propanetank_large
}

g_drillbot_loot_crates = {
	sm.uuid.new( "27583290-ebc2-452e-9f02-4894da09a9fc" ), --bigbox01
	sm.uuid.new( "ea77b8ae-579a-4c37-9eaf-191f0049f1f5" ), --bigbox02
	  sm.uuid.new( "bcb44f5d-ef57-40a9-890b-9d1d404904d5" ), --bigbox03
	  sm.uuid.new( "c49296a9-9fb5-490b-aad9-3ce8de30d10b" )  --bigbox04
}

CROP_NAMES_COLLECTION = {
	"tomato",
	"carrot",
	"redbeet",
	"banana",
	"blueberry",
	"orange",
	"chili",
	"broccoli",
	"pineapple",
	"potato",
	"corn"
}

CROP_NAME_TO_UUID = {
	["tomato"] = hvs_growing_tomato,
	["carrot"] = hvs_growing_carrot,
	["redbeet"] = hvs_growing_redbeet,
	["banana"] = hvs_growing_banana,
	["blueberry"] = hvs_growing_blueberry,
	["orange"] = hvs_growing_orange,
	["chili"] = hvs_growing_chili,
	["broccoli"] = hvs_growing_broccoli,
	["pineapple"] = hvs_growing_pineapple,
	["potato"] = hvs_growing_potato,
	["corn"] = hvs_growing_corn
}

END_QUEST_ACTORS = {
	"Lorenzo",
	"Hubert",
	"Phe",
	"ActorFarmer1",
	"mechanicmale1",
	"mechanicmale2",
	"mechanicmale3",
	"mechanicmale4"
}

CELEBRATION_ACTORS = {
	"Lorenzo",
	"Hubert",
	"Phe",
	"ActorFarmer1",
	"mechanicmale1",
	"mechanicmale2",
	"mechanicmale3",
	"mechanicmale4",
	"ActorMechanicMale4",
	"ActorMechanicFemale1",
	"ActorMechanicFemale2",
	"ActorMechanicFemale3",
	"ActorMechanicFemale4",
	"ActorFarmerBasic1",
	"ActorFarmerBasic2",
	"ActorFarmerBasic3",
	"ActorFarmerBasic4",
	"ActorFarmerBasic5",
	"ActorFarmerBasic6",
	"ActorFarmerBasic7",
	"ActorFarmerBasic8",
	"ActorFarmerBasic9",
	"ActorFarmerBasic10",
	"ActorFarmerFemale1",
	"ActorFarmerFemale2",
	"ActorFarmerFemale3",
	"ActorFarmerFemale4",
	"ActorFarmerFemale5",
	"ActorFarmerMale1",
	"ActorFarmerMale2",
	"ActorFarmerMale3",
	"ActorFarmerMale4",
	"ActorFarmerMale5",
	"ActorScrapper", 
	"ActorAxobot",
	"ActorFarmerBasic11",
	"ActorFarmerWaving1",
	"ActorFarmerWaving2",
	"ActorFarmerWaving3"
}

DRILLBOT_FIGHT_ACTORS = {
	"Lorenzo_Clone",
	"Hubert_Clone",
	"Phe_Clone"
}