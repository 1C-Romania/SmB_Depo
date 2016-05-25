
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			If Not Parameters.Filter.Owner.UseBatches Then
				
				Message = New UserMessage();
		        Message.Text = NStr("en = 'Products and services are not accounted by batches!'");
				Message.Message();
		        Cancel = True;
				
			EndIf;	
			
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
