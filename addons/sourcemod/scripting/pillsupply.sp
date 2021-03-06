#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
#include <l4d2_direct>
#include <smlib>
#include "includes/hardcoop_util.sp"

#define DEBUG 0
#define EMPTY_SLOT -1

// Reference: 'Hard 12 manager' by Standalone and High Cookie
// "current" by "CanadaRox"

public Plugin:myinfo =
{
	name = "Pill Supply",
	author = "Breezy",
	description = "Supplies survivors a set of pills upon leaving saferoom and a supplementary set at a configured map percentage",
	version = "1.0",
	url = ""
};

new Handle:hCvarSuppPillPercent;
new bool:g_bIsRoundActive;
new bool:g_bHasReceivedSuppPills;

public OnPluginStart() {
	hCvarSuppPillPercent = CreateConVar("supplementary_pill_percent", "50", "Percent of map completion upon which a second set of pills is granted. '-1' to disable");

	HookEvent("mission_lost", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:OnRoundOver, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_pillpercent", Cmd_PillPercent, "Set the percentage map flow at which supplementary pills are granted");
}


/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/

public Action:L4D_OnFirstSurvivorLeftSafeArea() {
	DistributePills();
	g_bIsRoundActive = true;
	g_bHasReceivedSuppPills = false;
}

public OnRoundOver() {
	g_bIsRoundActive = false;
}

/***********************************************************************************************************************************************************************************

																			SUPPLEMENTARY PILLS
																	
***********************************************************************************************************************************************************************************/

// Give supplementary pills at specified percentage
public OnGameFrame() {
	if (g_bIsRoundActive) {
		if( GetConVarInt(hCvarSuppPillPercent) > 0 && !g_bHasReceivedSuppPills ) {
			new iMaxSurvivorCompletion = GetMaxSurvivorCompletion();
			new iSuppPillsPercent = GetConVarInt(hCvarSuppPillPercent);
			if (iMaxSurvivorCompletion > iSuppPillsPercent) {
				DistributePills();
				Client_PrintToChatAll(true, "Granted supplementary pill to survivors at {G}%d%% {N}map flow", iSuppPillsPercent);
				g_bHasReceivedSuppPills = true;
			}
		}
	}
}

public Action:Cmd_PillPercent(client, args) {	
	if( args < 1 ) {
		new iSuppPillPercent = RoundToNearest(GetConVarFloat(hCvarSuppPillPercent));
		Client_PrintToChat(client, true, "Supplementary pill percent is currently set to {G}%d%%", iSuppPillPercent);
	} else {
		if( L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor || IsGenericAdmin(client) ) {
			new String:sPercentValue[32];		
			GetCmdArg(1, sPercentValue, sizeof(sPercentValue));
			new iPercentValue = StringToInt(sPercentValue);
			if (iPercentValue > 0 && iPercentValue < 100) {
				SetConVarInt(hCvarSuppPillPercent, iPercentValue);
				Client_PrintToChatAll(true, "Supplementary pill percent set to {G}%d%% {N}map flow", iPercentValue);
			} else {
				Client_PrintToChatAll(true, "Supplementary pill percent must be between {G}0-100");
			}
		} else {
			PrintToChat(client, "Command only available to survivor team");
		}	
	}	
	return Plugin_Handled;	
}

/***********************************************************************************************************************************************************************************

																				STARTING PILLS
																	
***********************************************************************************************************************************************************************************/

public DistributePills() {
	// iterate though all clients
	for (new client = 1; client <= MaxClients; client++) { 
		//check player is a survivor
		if (IsSurvivor(client)) {
			// check pills slot is empty
			if (GetPlayerWeaponSlot(client, 5) == EMPTY_SLOT) { 
				GiveItem(client, "pain_pills"); 
			}								
		}
	}
}

GiveItem(client, String:itemName[]) {
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
}

/*
GiveItem(client, String:itemName[22]) {	
	new item = CreateEntityByName(itemName);
	new Float:clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	TeleportEntity(item, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(item); 
	EquipPlayerWeapon(client, item);
}*/