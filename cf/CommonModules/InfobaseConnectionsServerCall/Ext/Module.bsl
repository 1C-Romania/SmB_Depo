////////////////////////////////////////////////////////////////////////////////
// Subsystem "Logging off users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Get IB connection lock parameters for use on the client side.
//
// Parameters:
//  GetSessionCount - Boolean - if True that the
//                                       returned structure filed NumberOfSessions is filled.
//
// Returns:
//   Structure - with fields:
//     Use - Boolean - True if lock is set, False - Else. 
//     Begin - Date - lock start data. 
//     End - Date - lock end date. 
//     Message - String - message to user. 
//     SessionTerminationTimeout - Number - interval in seconds.
//     NumberOfSessions  - 0 if the parameter GetSessionCount = False.
//     CurrentSessionDate - Date - current session date.
//
Function SessionLockParameters(GetSessionCount = False) Export
	
	Return InfobaseConnections.SessionLockParameters(GetSessionCount);
	
EndFunction

// Sets IB connection lock.
// If it is called from session with
// established divider values that it sets the data area session lock.
//
// Parameters:
//  MessageText    - String - text which will be a error
//                             message part when trying to set
//                             connection with locked infobase.
// 
//  KeyCode - String -  string which should be added
//                             to the command string parameter "/uc" connection
//                             string parameter "uc" to set connection
//                             with infobase despite of lock.
//                             It isn't applicable for data area session lock.
//
// Returns:
//   Boolean   - True if lock is set successfully.
//              False if the rights are not sufficient for locking.
//
Function SetConnectionLock(MessageText = "",
	KeyCode = "KeyCode") Export
	
	Return InfobaseConnections.SetConnectionLock(MessageText, KeyCode);
	
EndFunction

// Set data area session lock.
// 
// Parameters:
//   Parameters          - Structure - see NewConnectionLockParameters.
//   LocalTime - Boolean - start and end lock time are specified in local session time.
//                                If False then in the universal time.
//
Procedure SetDataAreaSessionLock(Parameters, LocalTime = True) Export
	
	InfobaseConnections.SetDataAreaSessionLock(Parameters, LocalTime);
	
EndProcedure

// Remove infobase lock.
//
// Returns:
//   Boolean   - True if the operation is completed successfully.
//              False if there are not enough rights to perform operation.
//
Function AllowUsersWork() Export
	
	Return InfobaseConnections.AllowUsersWork();
	
EndFunction

// Get data area session lock information.
// 
// Parameters:
//   LocalTime - Boolean - start and end lock time it
// is necessary to return in local session time. If False that
// it is returned in universal time.
//
// Returns:
//   Structure - see NewConnectionLockParameters.
//
Function GetDataAreaSessionLock(LocalTime = True) Export
	
	Return InfobaseConnections.GetDataAreaSessionLock(LocalTime);
	
EndFunction

// See procedure description in the module InfobaseConnections.
//
Function ConnectionInformation(ReceiveConnectionString = False, MessagesForEventLogMonitor = Undefined, ClusterPort = 0) Export
	
	Return InfobaseConnections.ConnectionInformation(ReceiveConnectionString, MessagesForEventLogMonitor, ClusterPort);
	
EndFunction

#EndRegion