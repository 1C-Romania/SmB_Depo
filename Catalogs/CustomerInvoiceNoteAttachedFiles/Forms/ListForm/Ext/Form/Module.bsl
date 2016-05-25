////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AttachedFiles.CallFormOpeningException(ThisForm);
	
EndProcedure



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
