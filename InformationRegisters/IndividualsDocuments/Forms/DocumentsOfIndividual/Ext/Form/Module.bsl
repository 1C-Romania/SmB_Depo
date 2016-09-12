////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Filter.Property("Ind") Then
		Ind = Parameters.Filter.Ind;
		
		IdentityCard = InformationRegisters.IndividualsDocuments.DocumentCertifyingPersonalityOfInd(Ind);
		
		IsIdentity = Not IsBlankString(IdentityCard);
		
		Items.IdentityCard.Height		= ?(IsIdentity, 2, 0);
		IdentityCard = ?(IsIdentity, "Identity card: ", "") + IdentityCard;
		
		Query = New Query;
		Query.SetParameter("Ind",	Ind);
		Query.Text =
		"SELECT TOP 1
		|	IndividualsDocuments.Presentation
		|FROM
		|	InformationRegister.IndividualsDocuments AS IndividualsDocuments
		|WHERE
		|	IndividualsDocuments.Ind = &Ind";
		AreDocuments = Not Query.Execute().IsEmpty();
		
		If Not IsIdentity AND AreDocuments Then
			Items.NoneIdentity.Visible		= True;
			MessageText = NStr("en='For the individual %1 the ID document has not been specified.';ru='Для физлица %1 не задан документ, удостоверяющий личность.'");
			IdentityCard = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Ind);
		EndIf;
		
		Items.IdentityCard.Visible	= Not IsBlankString(IdentityCard);
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
