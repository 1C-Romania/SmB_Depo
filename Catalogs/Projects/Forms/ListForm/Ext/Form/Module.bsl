////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS 


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS
// 



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
