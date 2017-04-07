
#Region ProgramInterface

// The function receives a representation of the value of the contact information on the form
//
// Parameters:
//  Form	- ManagedForm	 - form-owner contact information
//  Kind	- CatalogRef.ContactInformationKinds	 - kind for which the value is obtained
// 
// Returned value:
//  String - entering on the form contact information value
//
Function GetContactInformationValue(Form, Kind) Export
	
	Filter = New Structure("Kind", Kind);
	FindedRows = Form.ContactInformation.FindRows(Filter);
	
	If FindedRows.Count() > 0 Then
		Return FindedRows[0].Presentation;
	Else
		Return "";
	EndIf;
	
EndFunction

Function KindsListForAddingContactInformation(Form) Export
	
	ListAvailableKinds = New ValueList;
	Filter = New Structure("Kind");
	For Each TableRow In Form.ContactInformationKindProperties Do
		Filter.Kind = TableRow.Kind;
		If TableRow.AllowMultipleValueInput Or Form.ContactInformation.FindRows(Filter).Count() = 0 Then
			ListAvailableKinds.Add(TableRow.Kind, TableRow.KindPresentation);
		EndIf;
	EndDo;
	
	Return ListAvailableKinds;
	
EndFunction

Procedure FillChoiceListAddresses(Form) Export
	
	ArrayAddresses = New Array;
	Filter = New Structure("Kind");
	
	For Each TableRow In Form.ContactInformation Do
		
		If TableRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
			Continue;
		EndIf;
		
		Filter.Kind = TableRow.Kind;
		FindedRows = Form.ContactInformationKindProperties.FindRows(Filter);
		If FindedRows.Count() = 0 Then
			Continue;
		EndIf;
		
		If Not IsBlankString(TableRow.Presentation)
			And ArrayAddresses.Find(TableRow.Presentation) = Undefined Then
			
			ArrayAddresses.Add(TableRow.Presentation);
		EndIf;
		
	EndDo;
	
	For Each TableRow In Form.ContactInformation Do
		
		If TableRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
			Continue;
		EndIf;
		
		Filter.Kind = TableRow.Kind;
		FindedRows = Form.ContactInformationKindProperties.FindRows(Filter);
		If FindedRows.Count() = 0 Then
			Continue;
		EndIf;
		
		FieldPresentation = Form.Items["PresentationCI_" + Form.ContactInformation.IndexOf(TableRow)];
		FieldPresentation.ChoiceList.LoadValues(ArrayAddresses);
		
		FieldPresentation.DropListButton = FieldPresentation.ChoiceList.Count() > 0;
		
	EndDo;
	
EndProcedure

#EndRegion
