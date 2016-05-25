
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Text") Then
		Text = Parameters.Text;
	EndIf;
	
	If Parameters.Property("Title") Then
		ThisForm.Title = Parameters.Title;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - command handler Ok.
//
Procedure Ok(Command)
	
	Close(Text);
	
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
