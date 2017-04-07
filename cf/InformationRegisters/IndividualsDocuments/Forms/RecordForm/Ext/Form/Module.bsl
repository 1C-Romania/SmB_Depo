
#Region FormEventsHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("ChangedIndividualDocument");
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure DocumentKindOnChange(Item)
	
	If IsIdentityDocument(Record.Ind, Record.DocumentKind, Record.Period) Then
		Record.IsIdentityDocument = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function IsIdentityDocument(Ind, DocumentKind, Date)
	
	Return InformationRegisters.IndividualsDocuments.IsPersonID(Ind, DocumentKind, Date);
	
EndFunction

#EndRegion
