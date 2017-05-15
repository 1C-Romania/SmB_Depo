
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnWrite(Cancel)
	
	// Do not continue in case data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)

	// Do not continue in case data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	
	If IsNew() Then
		
		Query = New Query;
		Query.Text = "SELECT TOP 1
		|	SerialNumbers.Ref
		|FROM
		|	Catalog.SerialNumbers AS SerialNumbers
		|WHERE
		|	SerialNumbers.Description = &Description
		|	AND SerialNumbers.Owner = &Owner";
		
		Query.SetParameter("Owner", Owner);
		Query.SetParameter("Description", TrimAll(Description));
		
		Result = Query.Execute();
		If NOT Result.IsEmpty() Then
			Cancel = True;
			
			MessageText = NStr("en= 'Product %1% already has serial number %2%'; ru = 'У номенклатуры %1% уже введен серийный номер %2%'");
			MessageText = StrReplace(MessageText, "%1%", Owner);
			MessageText = StrReplace(MessageText, "%2%", TrimAll(Description));
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndIf