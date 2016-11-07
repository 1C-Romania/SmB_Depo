
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Title", Title);
	Parameters.Property("MessageText", MessageText);
	Parameters.Property("VisibleDoNotShowAgain", VisibleDoNotShowAgain);
	
	CommonUseClientServer.SetFormItemProperty(Items, "DontShowAgain", "Visible", VisibleDoNotShowAgain);
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////////////////////////
// COMMANDS HANDLERS PROCEDURES 
//

&AtClient
// Procedure - the OK command handler
//
Procedure OK(Command)
	
	Close(New Structure("CustomSettingValue", Not DontShowAgain));
	
EndProcedure // OK()



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
