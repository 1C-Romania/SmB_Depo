#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// The procedure updates the application events parameters when configuration is changed.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there is a record,
//               True is set, otherwise, it is not changed.
//
Procedure Refresh(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	EventsHandlers = StandardSubsystemsServer.EventsHandlers();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.ServiceEventsParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"ServiceEventsParameters");
		
		Saved = Undefined;
		
		If Parameters.Property("EventsHandlers") Then
			Saved = Parameters.EventsHandlers;
			
			If Not CommonUse.DataMatch(EventsHandlers, Saved) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			If CheckOnly Then
				CommitTransaction();
				Return;
			EndIf;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"ServiceEventsParameters", "EventsHandlers", EventsHandlers);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"ServiceEventsParameters", "EventsHandlers");
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
