////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB version update".  
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Checks status of delayed update. If update
// is completed with errors - informs user and administrator about it.
//
Procedure ValidateStatusDeferredUpdate() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientParameters.Property("ShowMessageAboutErrorHandlers") Then
		OpenForm("DataProcessor.InfobaseUpdate.Form.InfobaseDelayedUpdateProgressIndication");
	Else
		InfobaseUpdateClient.NotifyPendingHandlersNotImplemented();
	EndIf;
	
EndProcedure

#EndRegion
