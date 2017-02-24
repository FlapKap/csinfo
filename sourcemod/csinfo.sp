// listening socket example for the socket extension

#include <sourcemod>
#include <socket>
#include <sdktools>
#include <cstrike>
#include <timers>
#include <smjansson>
#include <clients>

public Plugin:myinfo = {
	name = "Listener",
	author = "FlapKap",
	description = "This example provides a simple echo server. Assumes Socket 3 and",
	version = "0.1",
	url = ""
};

 
public OnPluginStart() {
	// enable socket debugging (only for testing purposes!)
	SocketSetOption(INVALID_HANDLE, DebugMode, 1);


	// create a new tcp socket
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	// bind the socket to all interfaces, port 50000
	SocketBind(socket, "0.0.0.0", 50000);
	// let the socket listen for incoming connections
	SocketListen(socket, OnSocketIncoming);
	
}

Handle GatherInfoOnPlayer(int i){
	new armor = GetClientArmor(i);
	new deaths = GetClientDeaths(i);
	new frags = GetClientFrags(i);
	new health = GetClientHealth(i);
	new team = GetClientTeam(i);
	new assists = CS_GetClientAssists(i);
	new contribution = CS_GetClientContributionScore(i);
	new mvp = CS_GetMVPCount(i);

	new String:weapon[32];
	GetClientWeapon(i, weapon, sizeof(weapon));

	new String:name[MAX_NAME_LENGTH];
	GetClientName(i, name, sizeof(name));
	
	new Float:vecOrigin[3];
	new Float:vecAngles[3];
	GetClientAbsAngles(i, vecAngles);
	GetClientAbsOrigin(i, vecOrigin);

	new Handle:Player = json_object();
	json_object_set(Player, "armor", json_integer(armor));
	json_object_set(Player, "deaths", json_integer(deaths));
	json_object_set(Player, "frags", json_integer(frags));
	json_object_set(Player, "health", json_integer(health));
	json_object_set(Player, "team", json_integer(team));
	json_object_set(Player, "assists", json_integer(assists));
	json_object_set(Player, "MVP", json_integer(mvp));
	json_object_set(Player, "contribution", json_integer(contribution));
	json_object_set(Player, "weapon", json_string(weapon));
	json_object_set(Player, "name", json_string(name));

	new Handle:Origin = json_object();
	json_object_set(Origin, "x", json_real(vecOrigin[0]));
	json_object_set(Origin, "y", json_real(vecOrigin[1]));
	json_object_set(Origin, "z", json_real(vecOrigin[2]));
	
	new Handle:Angles = json_object();
	json_object_set(Angles, "x", json_real(vecAngles[0]));
	json_object_set(Angles, "y", json_real(vecAngles[1]));
	json_object_set(Angles, "z", json_real(vecAngles[2]));

	json_object_set(Player, "vecOrigin", Origin);
	json_object_set(Player, "vecAngles", Angles);
	
	return Player;
}

//team names are CS_TEAM_NONE, CS_TEAM_CT, CS_TEAM_T and CS_TEAM_SPECTATORS
GatherInfoOnTeam(i){
	new String:name[MAX_NAME_LENGTH];
	GetTeamName(i, name, sizeof(name));

	new csscore = CS_GetTeamScore(i);
	new score = GetTeamScore(i);

	new Handle:Team = json_object();
	json_object_set(Team, "name", json_string(name));
	json_object_set(Team, "score", json_integer(score));
	json_object_set(Team, "csscore", json_integer(csscore));

	return Team;
}

public Action GatherInfoAll(Handle Timer, Handle socket) {
	new Handle:players = json_array();
	new Handle:teams = json_object();
	json_object_set(teams, "Terrorist", Handle:GatherInfoOnTeam(CS_TEAM_T));
	json_object_set(teams, "Counter-Terrorist", Handle:GatherInfoOnTeam(CS_TEAM_CT));

	new Handle:info = json_object();
	json_object_set(info, "team data", teams);

	json_object_set(info, "players", players);
	for(new i = 1; i <= MaxClients; i++){
		if(IsClientInGame(i)) json_array_append_new(players, GatherInfoOnPlayer(i));
	}
	new String:output[1024];
	json_dump(info, output, sizeof(output));
	SocketSend(socket, output);

	return Plugin_Continue;
}

GetBotCount() {
	new count = 0;
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && IsFakeClient(i)) {
			count++;
		}
	}
	return count;
}





public OnSocketIncoming(Handle:socket, Handle:newSocket, String:remoteIP[], remotePort, any:arg) {
	PrintToServer("%s:%d connected", remoteIP, remotePort);

	// setup callbacks required to 'enable' newSocket
	// newSocket won't process data until these callbacks are set
	SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnChildSocketError);
	CreateTimer(1.0,GatherInfoAll, newSocket, TIMER_REPEAT);
		//SocketSend(newSocket, "send quit to quit\n");
		
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
	// a socket error occured

	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

public OnChildSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
	// send (echo) the received data back
	SocketSend(socket, receiveData);
	// close the connection/socket/handle if it matches quit
	if (strncmp(receiveData, "quit", 4) == 0) CloseHandle(socket);
}

public OnChildSocketDisconnected(Handle:socket, any:hFile) {
	// remote side disconnected

	CloseHandle(socket);
}

public OnChildSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
	// a socket error occured

	LogError("child socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

