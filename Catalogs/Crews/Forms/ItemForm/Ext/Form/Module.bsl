
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("ContentEmployeeCode") <> Undefined Then		
			Items.ContentEmployeeCode.Visible = False;		
		EndIf;
	EndIf; 	
	
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
