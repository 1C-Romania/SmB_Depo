
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
		        Message.Text = NStr("en='Accounting by batches is not kept for products and services.';ru='Для номенклатуры не ведется учет по партиям!'");
				Message.Message();
		        Cancel = True;
				
			EndIf;	
			
		EndIf;	
		
	EndIf;	

EndProcedure
