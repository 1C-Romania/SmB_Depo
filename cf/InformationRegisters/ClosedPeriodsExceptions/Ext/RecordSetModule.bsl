// Procedure - "BeforeWrite" form event handler
//
Procedure BeforeWrite(Cancel, Replacing)
	
	For Each Record In ThisObject Do
		If Record.DocumentType = Undefined Then
			Cancel = True;
			CancelString = NStr("en='The document type is not filled.';pl='Nie wybrano typu dokumentu.';ru='Не выбран тип документа.'");
			Continue;
		EndIf;
	EndDo;
	
	If Cancel Then
		Message(CancelString);
	EndIf; 

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If NOT CommonAtServer.UseMultiCompaniesMode() Then
		
		CheckedAttributes.Delete(CheckedAttributes.Find("Company"));
		
	EndIf;
	
EndProcedure
