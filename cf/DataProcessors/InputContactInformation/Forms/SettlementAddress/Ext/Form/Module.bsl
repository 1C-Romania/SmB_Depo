// Form is parameterized:
//
//      SettlementIdentifier    - UUID - Current object identifier for
//                                                                    defining and editing form parts.
//      SettlementInDetail           - Structure               - Description of the settlement in
//                                                                    terms of the classifier variant. It is used
//                                                                    if the identifier is not specified.
//      AddressFormat - String - Variant of the
//      address classifier, HideObsoleteAddresses        - Boolean - Flag showing that the obsolete addresses
//                                                   will be hidden when editing.
//      ClassifierServiceNotAvailable    - Boolean - Optional flag showing that the supplier is under service.
//
//  Selection result:
//      Structure - fields:
//          * Identifier           - UUID - Selected settlement.
//          * Presentation           - String                  - Presentation of the selected.
//          * SettlementInDetail - Structure               - Edited description of the settlement.
//
// -------------------------------------------------------------------------------------------------

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("AddressFormat", AddressFormat);
	Parameters.Property("ClassifierServiceNotAvailable",    ClassifierServiceNotAvailable);
	Parameters.Property("HideObsoleteAddresses ",       HideObsoleteAddresses);
	
	If IsBlankString(AddressFormat) Then
		AddressFormat = "FIAS";
	EndIf;
	
	CanImportClassifier = ContactInformationManagementService.IsAbilityToChangesOfAddressClassifier();
	PrefixNamePartsAddresses = "part";
	PartsAddresses = Parameters.SettlementInDetail;
	If PartsAddresses = Undefined Or PartsAddresses.Count() = 0 Then
		PartsAddresses = ContactInformationManagementService.AttributesListSettlement( , AddressFormat);
	EndIf;
	
	ContactInformationManagementService.FillSettlementIdentifiers(PartsAddresses, Parameters.SettlementIdentifier);
	
	BuildFormInPartAddresses();
	SetKeyUseForms();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	
	If AddressChanged Then
		Result = ChoiceResult();
		
#If WebClient Then
		ClosingFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = ClosingFlag;
#Else
		NotifyChoice(Result);
#EndIf
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) AND IsOpen() Then
		Close(Result);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure BuildFormInPartAddresses()
	Add = New Array;
	
	StringType = New TypeDescription("String");
	For Each KeyValue In PartsAddresses Do
		part = KeyValue.Value;
		Name   = KeyValue.Key;
		Add.Add( New FormAttribute(PrefixNamePartsAddresses + Name, StringType, , part.Title));
	EndDo;
	ChangeAttributes(Add);
	
	ItemsParent = Items.AddressPartsGroup;
	
	FormItemsByLevel.Clear();
	For Each KeyValue In PartsAddresses Do
		part = KeyValue.Value;
		Name   = KeyValue.Key;
		
		If part.Level < 7 Then
			Item = Items.Add(PrefixNamePartsAddresses + Name, Type("FormField"), ItemsParent);
			
			Item.DataPath  = Item.Name;
			Item.Type          = FormFieldType.InputField;
			Item.ChoiceButton = True;
			
			Item.EditTextUpdate = EditTextUpdate.OnValueChange;
			
			part.Property("ToolTip", Item.ToolTip);
			If IsBlankString(Item.ToolTip) Then
				Item.ToolTip = part.Title;
			EndIf;
				
			Item.SetAction("OnChange",         "Attachable_FieldOnChange");
			Item.SetAction("StartChoice",         "Attachable_FieldStartChoice");
			Item.SetAction("Clearing",              "Attachable_Clearing");
			Item.SetAction("ChoiceProcessing",      "Attachable_FieldChoiceProcessing");
			Item.SetAction("AutoComplete",           "Attachable_FieldAutoPickup");
			Item.SetAction("TextEditEnd", "Attachable_FieldTextInputEnd");
			
			ThisObject[Item.Name] = part.Presentation;
			
			FormItemsByLevel.Add(KeyValue.Value.Level, Item.Name);
		EndIf;
		
	EndDo;
	
EndProcedure

// -------------------------------------------------------------------------------------------------

&AtClient 
Function NamePartsAddressesItem(Item)
	
	Return Mid(Item.Name, 1 + StrLen(PrefixNamePartsAddresses));
	
EndFunction

&AtClient 
Function PartAddressesItem(Item)
	
	Return PartsAddresses[NamePartsAddressesItem(Item)];
	
EndFunction

// -------------------------------------------------------------------------------------------------

&AtClient
Function SetPartsAddressesValue(Item, ValueSelected)
	
	Result = ContactInformationManagementClientServer.SetPartsAddressesValue(
		NamePartsAddressesItem(Item), PartsAddresses, ValueSelected
	);
	
	ThisObject[Item.Name] = Result;
	Return Result;
EndFunction

&AtClient
Procedure Attachable_FieldOnChange(Item)
	AddressChanged = True;
	If IsBlankString(ThisObject[Item.Name]) Then
		ClearChildAddressFields(Item.Name);
	EndIf;
	
	EnedledButtonOK = False;
	For Each Item In FormItemsByLevel Do 
		If Not IsBlankString(ThisObject[Item.Presentation]) Then 
			EnedledButtonOK = True;
		EndIf;
	EndDo;
	Items.FormOKCommand.Enabled = EnedledButtonOK;
	
EndProcedure

&AtClient
Procedure Attachable_FieldStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	// If came directly after editing, then reset the address part value.
	If Item.EditText <> ThisObject[Item.Name] Then
		SetPartsAddressesValue(Item, Item.EditText);
	EndIf;
	
	PartAddresses = PartAddressesItem(Item);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("AddressFormat", AddressFormat);
	OpenParameters.Insert("HideObsoleteAddresses",        HideObsoleteAddresses);
	
	OpenParameters.Insert("Level",  PartAddresses.Level);
	OpenParameters.Insert("Parent", ItemAddressPartParentIdentifier(PartAddresses, PartsAddresses));
	
	// Current item
	OpenParameters.Insert("ID", PartAddresses.Identifier);
	Presentation = ?(IsBlankString(PartAddresses.Presentation),PartAddresses.Title, PartAddresses.Presentation);
	OpenParameters.Insert("Presentation", Presentation);
	
	OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByLevel", OpenParameters, Item);
EndProcedure

&AtServer
Function ItemAddressPartParentIdentifier(PartAddresses, PartsAddresses)
	
	ID = Undefined;
	ThereIsAddressPartWithoutId = False;
	AddressPartsAreHigherLevel = New Structure;
	AddressLevel = 0;
	For Each KeyValue In PartsAddresses Do
		part = KeyValue.Value;
		If part.Level < PartAddresses.Level AND Not IsBlankString(part.Presentation) Then
			AddressPartsAreHigherLevel.Insert(KeyValue.Key, part);
			If ValueIsFilled(KeyValue.Value.Identifier) Then
				If AddressLevel < KeyValue.Value.Level Then
					ID = KeyValue.Value.Identifier;
					AddressLevel = KeyValue.Value.Level;
				EndIf;
			Else
				ThereIsAddressPartWithoutId = True;
			EndIf;
		EndIf;
	EndDo;

	If ThereIsAddressPartWithoutId Then 
		ContactInformationManagementService.FillSettlementIdentifiers(AddressPartsAreHigherLevel, ID);
	EndIf;

	Return ID;

EndFunction 

&AtClient
Procedure Attachable_Clearing(Item, StandardProcessing)
	
	ClearChildAddressFields(Item.Name);
	AddressChanged = True;
	
EndProcedure

&AtClient
Procedure Attachable_FieldChoiceProcessing(Item, ValueSelected, StandardProcessing)
	TypeOfSelected = TypeOf(ValueSelected);
	
	If TypeOfSelected = Type("Structure") Then
		// It is selected by button or from the autopick.
		ValueSelected.Property("Cancel", ClassifierServiceNotAvailable);
		
		If ClassifierServiceNotAvailable Then
			StandardProcessing = False;
			If Not IsBlankString(ValueSelected.BriefErrorDescription) Then
				ShowMessageBox(, ValueSelected.BriefErrorDescription);
			EndIf;
		Else
			DoNotImportAddressClassifier = ApplicationParameters.Get("AddressClassifier.DoNotImportClassifier");
			If DoNotImportAddressClassifier = Undefined OR DoNotImportAddressClassifier = False Then 
				StateNotImported = ValueSelected.Property("StateImported") AND ValueSelected.StateImported = False;
				If CanImportClassifier AND StateNotImported Then
					// Offer to import a classifier.
					ContactInformationManagementClient.OfferExportClassifier(
						StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Data for ""%1"" is not imported.';ru='Данные для ""%1"" не загружены.'"), ValueSelected.Presentation
						),
						ValueSelected.Presentation
					);
				EndIf;
			EndIf;
		EndIf;
		
		ClearChildAddressFields(Item.Name);
		// Convert the selected string.
		ValueSelected = SetPartsAddressesValue(Item, ValueSelected);
		AddressChanged = True;
		RefreshDataRepresentation();
		
	ElsIf TypeOfSelected = Type("String") Then
		SetPartsAddressesValue(Item, ValueSelected);
		AddressChanged = True;
		RefreshDataRepresentation();
	Else
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearChildAddressFields(ItemName)
	
	SelectedFieldLevel = 0;
	For Each Item In FormItemsByLevel Do
		If Item.Presentation = ItemName Then
			SelectedFieldLevel = Item.Value;
		EndIf;
	EndDo;
	
	If SelectedFieldLevel = 0 Then
		Return;
	EndIf;
	
	If SelectedFieldLevel < 6 Then
		Item = FormItemsByLevel.FindByValue(6);
		If Item <> Undefined Then 
			ThisObject[Item.Presentation] = "";
			ClearPartAddresses("Settlement");
		EndIf;
	EndIf;
	
	If SelectedFieldLevel < 5 Then
		Item = FormItemsByLevel.FindByValue(5);
		If Item <> Undefined Then 
			ThisObject[Item.Presentation] = "";
			ClearPartAddresses("UrbDistrict");
		EndIf;
	EndIf;
	
	If SelectedFieldLevel < 4 Then
		Item = FormItemsByLevel.FindByValue(4);
		If Item <> Undefined Then
			ThisObject[Item.Presentation] = "";
			ClearPartAddresses("City");
		EndIf;
	EndIf;
	
	If SelectedFieldLevel < 3 Then
		Item = FormItemsByLevel.FindByValue(3);
		If Item <> Undefined Then 
			ThisObject[Item.Presentation] = "";
			ClearPartAddresses("Region");
		EndIf;
	EndIf;
	
	If SelectedFieldLevel < 2 Then
		Item = FormItemsByLevel.FindByValue(2);
		If Item <> Undefined Then 
			ThisObject[Item.Presentation] = "";
			ClearPartAddresses("District");
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ClearPartAddresses(PartName)
		PartsAddresses[PartName].Description = Undefined;
		PartsAddresses[PartName].Identifier = Undefined;
		PartsAddresses[PartName].Presentation = Undefined;
		PartsAddresses[PartName].Abbr = Undefined;
EndProcedure

&AtClient
Procedure Attachable_FieldAutoPickup(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	ChoiceData = New ValueList;
	
	If Wait = 0 Then
		// Creation of list for fast selection, standard processing is not used.
		Return;
	EndIf;
	
	If ClassifierServiceNotAvailable Or StrLen(Text) < 3 Then 
		// No options, the list is empty, standard processing must not be used.
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AddressFormat", AddressFormat);
	AdditionalParameters.Insert("HideObsolete",              HideObsoleteAddresses);
	
	ClassifierData = AutopickListAddressParts(Text, NamePartsAddressesItem(Item), PartsAddresses, AdditionalParameters);
	
	If ClassifierData.Cancel Then
		// Service is broken
		ClassifierServiceNotAvailable = True;
		Return;
	EndIf;
	
	ChoiceData = ClassifierData.Data;
	
	// Standard processing is off, only if there are own options.
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FieldTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	
	AddressChanged = True;
	SetPartsAddressesValue(Item, Text);
EndProcedure

&AtServer
Function ChoiceResult()
	Result = New Structure;
	
	ID = Undefined;
	IdLevel = 0;
	For Each PartAddresses In PartsAddresses Do
		If PartAddresses.Value.Level > IdLevel AND ValueIsFilled(PartAddresses.Value.Identifier) Then
			IdLevel = PartAddresses.Value.Level;
			ID = PartAddresses.Value.Identifier;
		EndIf;
	EndDo;
	If ValueIsFilled(ID) Then
		Result.Insert("ID", ID);
	Else
		Result.Insert("ID", ContactInformationManagementService.SettlementIdentifierByAddressParts(PartsAddresses));
	EndIf;
	
	Result.Insert("Presentation", ContactInformationManagementClientServer.SettlementPresentationByAddressParts(PartsAddresses));
	Result.Insert("SettlementInDetail", PartsAddresses);
	
	Return Result;
EndFunction

&AtServerNoContext
Function AutopickListAddressParts(Text, AddressesPartName, PartsAddresses, AdditionalParameters)
	
	Return ContactInformationManagementService.AutopickListAddressParts(Text, AddressesPartName, PartsAddresses, AdditionalParameters);
	
EndFunction

&AtServer
Procedure SetKeyUseForms()
	
	WindowOptionsKey = TrimAll(AddressFormat)
		+ "/" + Format(PartsAddresses.Count(), "NZ=; NG=");
		
EndProcedure

#EndRegion
