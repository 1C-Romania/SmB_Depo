#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Set or delete infobase lock,
// proceeding from DataProcessor attribute values.
//
Procedure RunSetup() Export
	
	ExecuteSetLock(ProhibitUserWorkTemporarily);
	
EndProcedure

// Cancel previously installed session lock.
//
Procedure Unlock() Export
	
	ExecuteSetLock(False);
	
EndProcedure

// Read the infobase lock parameters in DataProcessor attributes.
// 
Procedure GetBlockParameters() Export
	
	If Users.InfobaseUserWithFullAccess(, True) Then
		CurrentMode = GetSessionsLock();
		UnlockCode = CurrentMode.KeyCode;
	Else	
		CurrentMode = InfobaseConnections.GetDataAreaSessionLock();
	EndIf;
	
	ProhibitUserWorkTemporarily = CurrentMode.Use;
	MessageForUsers = InfobaseConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If ProhibitUserWorkTemporarily Then
		LockBegin    = CurrentMode.Begin;
		LockEnding = CurrentMode.End;
	Else	
		// If the lock isn't set you
		// can assume that the user opened the form for lock setting.
		// Therefore, we set the date of locking equal to current date.
		LockBegin     = BegOfMinute(CurrentSessionDate() + 5 * 60);
	EndIf;
	
EndProcedure

Procedure ExecuteSetLock(Value)
	
	ConnectionsBlockIsSet = InfobaseConnections.ConnectionsBlockIsSet();
	If Users.InfobaseUserWithFullAccess(, True) Then
		Block = New SessionsLock;
		Block.KeyCode    = UnlockCode;
	Else
		Block = InfobaseConnections.NewLockConnectionParameters();
	EndIf;
	
	Block.Begin           = LockBegin;
	Block.End            = LockEnding;
	Block.Message        = InfobaseConnections.GenerateLockMessage(MessageForUsers, 
		UnlockCode); 
	Block.Use      = Value;
	
	If Users.InfobaseUserWithFullAccess(, True) Then
		SetSessionsLock(Block);
	Else
		InfobaseConnections.SetDataAreaSessionLock(Block);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf