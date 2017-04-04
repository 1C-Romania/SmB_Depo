
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



