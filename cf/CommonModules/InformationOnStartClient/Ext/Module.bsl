////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information on start".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// It is called once the configuration is launched, connects the wait handler that opens the information dialog box.
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.Property("InformationOnStart") AND ClientParameters.InformationOnStart.Show Then
		AttachIdleHandler("ShowInformationAfterLaunch", 0.2, True);
	EndIf;
	
EndProcedure

// It is called from the wait handler and opens the information dialog box.
Procedure Show() Export
	OpenForm("DataProcessor.InformationOnStart.Form");
EndProcedure

#EndRegion
