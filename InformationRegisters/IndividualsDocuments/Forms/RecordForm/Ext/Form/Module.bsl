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
