////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure DocumentKindOnChange(Item)
	
	If IsPersonID(Record.Ind, Record.DocumentKind, Record.Period) Then
		Record.IsIdentityDocument = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServerNoContext
Function IsPersonID(Ind, DocumentKind, Date)
	
	Return InformationRegisters.IndividualsDocuments.IsPersonID(Ind, DocumentKind, Date);
	
EndFunction
