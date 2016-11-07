////////////////////////////////////////////////////////////////////////////////
// The Deleted administration subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface


// Called during completing the session using the UserSessions subsystem.
// 
// Parameters:
//  OwnerForm - ManagedForm from which
//  the session end is executed, SessionNumber - Digit (8,0,+) - number of the session
//  that will be ended, StandardProcessor - Boolean, shows that a standard
//    processor of the session end is processed (connection to the
//    server agent via COM-connection or administer server with the query of connection parameters to the cluster of the current user). May
//    be set to the False value inside the event processor, in
//    this case the standard processor of
//  the session end will not be executed, AlertAfterSessionEnd - NotifyDescription - description of
//    the alert that should be called after the session is
//    over (for an auto update of the active users list). If you set the value of
//    the StandardProcessor parameter as False, after the session is complete
//    successfully, a processor for the passed description of an
//    alert should be executed using the ExecuteAlertProcessor method
//    (you should pass DialogReturnCode.OK  as a value of the Result parameter if the session is completed successfully). Parameter can be omitted - in this case do not process
//    the alert.
//
Procedure OnSessionEnd(OwnerForm, Val SessionNumber, StandardProcessing, Val AlertAfterSessionEnd = Undefined) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled Then
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().CanUseSeparatedData Then
			
			StandardProcessing = False;
			
			FormParameters = New Structure();
			FormParameters.Insert("SessionNumber", SessionNumber);
			
			NotifyDescription = New NotifyDescription(
				"AfterSessionEnd", ThisObject, New Structure("NotifyDescription", AlertAfterSessionEnd));
			
			OpenForm("CommonForm.TerminateSessionSaaS",
				FormParameters,
				OwnerForm,
				SessionNumber,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Called after the session is complete. Executes an initial description of the
// alert from the form of the ActiveUsers processor to update the list of active users after the session is over.
//
// Parameters:
//  Result - Custom - is not analyzed in this procedure. Should be passed
//                            to the
//  source description of alert, Context - Structure:
//             * AlertDescription - NotifyDescription - source description of an alert.
//
Procedure AfterSessionEnd(Result, Context) Export
	
	If Context.NotifyDescription <> Undefined Then
		
		ExecuteNotifyProcessing(Context.NotifyDescription, Result);
		
	EndIf;
	
EndProcedure

#EndRegion

