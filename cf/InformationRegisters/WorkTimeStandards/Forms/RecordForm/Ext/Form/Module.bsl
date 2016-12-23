
&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Record.SourceRecordKey.ProductsAndServices) Then
		Record.Author = Users.CurrentUser();	
	EndIf;	
	
EndProcedure














