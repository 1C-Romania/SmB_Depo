
// Form parameters:
//     Level                           - Number  - Requested level.
//     Parent                          - UUID - Parent object.
//     HideObsoleteAddresses        - Boolean - check box indicating that obsolete addresses are hidden.
//     AddressFormat - String - version of the classifier.
//     ID                     - UUID - Current address item.
//     Presentation                     - String - Current item presentation. it is used
//                                                  if the Identifier is not specified.
//
// Selection result:
//     Structure - with
//         * Cancel fields                      - Boolean - check box indicating that an error occurred while processing.
//         * BriefErrorPresentation - String - Error description.
//         * Identifier              - UUID - Address data.
//         * Presentation              - String                  - Address data.
//         * StateIsImported             - Boolean                  - Only for states, True if there
//                                                                  are records.
// ---------------------------------------------------------------------------------------------------------------------
//
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	PortionNumber = Undefined;
	
	Parameters.Property("Parent", Parent);
	Parameters.Property("Level",  Level);
	Parameters.Property("HideObsoleteAddresses", HideObsoleteAddresses);
	Parameters.Property("AddressFormat", AddressFormat);
	
	If IsBlankString(AddressFormat) Then
		AddressFormat = "FIAS";
	EndIf;
	
	SearchParameters = New Structure;
	SearchParameters.Insert("HideObsolete", HideObsoleteAddresses);
	SearchParameters.Insert("AddressFormat", AddressFormat);
	SearchParameters.Insert("Sort",   "ASC");
	SearchParameters.Insert("FirstRecord", PortionNumber);
	
	// Batched mode if Required.
	DataReceivingUsingWebService = ContactInformationManagementService.ClassifierAvailableThroughWebService();

	Items.PortionNavigation.Visible = DataReceivingUsingWebService;
	
	If DataReceivingUsingWebService Then
		// PortionSize - operation mode check box at the same time.
		PortionSize = 100;
		Items.FindGroupWebService.Visible = True;
		Items.FindGroup.Visible = False;
	Else
		PortionSize = Undefined;
		Items.FindGroupWebService.Visible = False;
		Items.FindGroup.Visible = True;
	EndIf;
	SearchParameters.Insert("PortionSize", PortionSize);
		
	ClassifierData = ContactInformationManagementService.AddressesForInteractiveSelection(Parent, Level, SearchParameters);
	
	ClassifierDataAdditionalTerritories = ContactInformationManagementService.AddressesForInteractiveSelection(Parent, 90, SearchParameters);
	If ClassifierDataAdditionalTerritories.Data.Count() = 0 Then
		Items.AdditionalTerritories.Visible = False;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	If ClassifierData.Data.Count() = 0 Then
		Items.StreetsAndSettlements.Visible = False;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	If Items.AdditionalTerritories.Visible = False AND Items.StreetsAndSettlements.Visible = False Then
		BriefErrorDescription = NStr("en='Data of streets, settlements and additional territories for the entered address are absent';ru='Данные о улицах, населенных пунктах и дополнительных территориях для введенного адреса отсутствуют'");
		Return;
	EndIf;
	Items.SelectStreet.DefaultButton = True;
	
	AddressVariants.Load(ClassifierData.Data);
	AdditionalTerritoriesVariants.Load(ClassifierDataAdditionalTerritories.Data);
	ClearSubordinate = False;
	SetDataOnStreetRepresentation(Parameters.PresentationStreet, Parent);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(BriefErrorDescription) Then
		NotifyOwner(Undefined, True);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure FindAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		// Creation of list for fast selection, standard processing is not used.
		Return;
	EndIf;
	
	If Not IsBlankString(Text) Then
		FillOptionBatchByFirstLetter(Text);
	Else
		GotoListBegin();
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectStreet(Command)
	MakeSelection(Items.AddressVariants.CurrentRow);
EndProcedure

&AtClient
Procedure Select(Command)
	MakeSelection(Items.AdditionalTerritoriesVariants.CurrentRow);
EndProcedure

&AtClient
Procedure AdditionalTerritoriesVariantsSelection(Item, SelectedRow, Field, StandardProcessing)
	MakeSelection(SelectedRow);
EndProcedure

&AtClient
Procedure AddressVariantsSelectionValue(Item, Value, StandardProcessing)
	
	MakeSelection(Value);
	
EndProcedure

&AtClient
Procedure AdditionalItemSelectionStart(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.AddressVariants.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentParent = CurrentData.ID;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("AddressFormat", AddressFormat);
	OpenParameters.Insert("HideObsoleteAddresses",        HideObsoleteAddresses);
	
	OpenParameters.Insert("Level",  90);
	OpenParameters.Insert("Parent", CurrentParent);
	
	OpenParameters.Insert("ID", AdditionalIdentifier);
	OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByLevel", OpenParameters, Item);
	
EndProcedure

&AtClient
Procedure SubordinateItemSelectionStart(Item, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(AdditionalIdentifier) Then
		CurrentParent = AdditionalIdentifier;
	Else
		CurrentData = Items.AddressVariants.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		CurrentParent = CurrentData.ID;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("AddressFormat", AddressFormat);
	OpenParameters.Insert("HideObsoleteAddresses",        HideObsoleteAddresses);
	
	OpenParameters.Insert("Level",  91);
	OpenParameters.Insert("Parent", CurrentParent);
	
	OpenParameters.Insert("ID", SubordinateIdentifier);
	
	OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByLevel", OpenParameters, Item);
EndProcedure

&AtClient
Procedure SubordinateItemForTerritorySelectionStart(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.AdditionalTerritoriesVariants.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentParent = CurrentData.ID;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("AddressFormat", AddressFormat);
	OpenParameters.Insert("HideObsoleteAddresses",        HideObsoleteAddresses);
	
	OpenParameters.Insert("Level",  91);
	OpenParameters.Insert("Parent", CurrentParent);
	
	OpenParameters.Insert("ID", SubordinateIdentifierForTerritory);
	
	OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByLevel", OpenParameters, Item);

EndProcedure

&AtClient
Procedure AdditionalItemSelectionDataProcessor(Item, ValueSelected, StandardProcessing)
	If TypeOf(ValueSelected) = Type("Structure") Then 
		StandardProcessing = False;
		AdditionalIdentifier = ValueSelected.ID;
		AdditionalItem = ValueSelected.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SubordinateItemSelectionDataProcessor(Item, ValueSelected, StandardProcessing)
	If TypeOf(ValueSelected) = Type("Structure") Then 
		StandardProcessing = False;
		SubordinateIdentifier = ValueSelected.ID;
		SubordinateItem = ValueSelected.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SubordinateItemForTerritorySelectionDataProcessor(Item, ValueSelected, StandardProcessing)
	If TypeOf(ValueSelected) = Type("Structure") Then 
		StandardProcessing = False;
		SubordinateIdentifierForTerritory = ValueSelected.ID;
		SubordinateItemForTerritory = ValueSelected.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	If CurrentPage = Items.StreetsAndSettlements Then 
		Items.SelectStreet.DefaultButton = True;
	Else
		Items.AdditionalTerritoriesVariantsSelect.DefaultButton = True;
	EndIf;
	ClearSubordinate = False;
EndProcedure

&AtClient
Procedure AddressVariantsOnActivateRow(Item)
	If Item.CurrentData <> Undefined AND ThereAreChildItems(Item.CurrentData.ID) Then
		Items.AdditionalItem.Enabled = True;
		Items.SubordinateItem.Enabled = True;
	Else
		Items.AdditionalItem.Enabled = False;
		Items.SubordinateItem.Enabled = False;
	EndIf;
	If ClearSubordinate Then
		AdditionalItem = Undefined;
		SubordinateItem = Undefined;
	Else 
		ClearSubordinate = True;
	EndIf;
EndProcedure

&AtServerNoContext
Function ThereAreChildItems(ID)
	SearchParameters = New Structure;
	SearchParameters.Property("AddressFormat", "FIAS");
	SearchParameters.Property("HideObsolete", True);

	ClassifierData = ContactInformationManagementService.AddressesForInteractiveSelection(ID, 90, SearchParameters);
	If ClassifierData.Data.Count() > 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#Region FormCommands

&AtClient
Procedure FirstPortion(Command)
	
	If PortionSize = Undefined Then
		Return;
	EndIf;
		
	GotoListBegin();

EndProcedure

&AtClient
Procedure PreviousPortion(Command)
	
	NumberOfRecords = AddressVariants.Count();
	If NumberOfRecords = 0 Or PortionSize = Undefined Then
		Return;
	EndIf;
	
	If PortionNumber > 0 Then
		PortionNumber = PortionNumber - 1;
	Else
		PortionNumber = Undefined;
	EndIf;
	
	SearchParameters = New Structure;
	SearchParameters.Insert("HideObsolete",              False);
	SearchParameters.Insert("AddressFormat", AddressFormat);
	SearchParameters.Insert("PortionSize", PortionSize);
	SearchParameters.Insert("FirstRecord", PortionNumber);
	SearchParameters.Insert("Sort",   "DESC");
	
	FillOptionBatch(SearchParameters);
EndProcedure

&AtClient
Procedure NextPortion(Command)
	
	NumberOfRecords = AddressVariants.Count();
	If NumberOfRecords = 0 Or PortionSize = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(PortionNumber) Then
		PortionNumber = PortionNumber + 1;
	Else
		PortionNumber = 1;
	EndIf;
	
	SearchParameters = New Structure;
	SearchParameters.Insert("HideObsolete",              False);
	SearchParameters.Insert("AddressFormat", AddressFormat);
	SearchParameters.Insert("PortionSize", PortionSize);
	SearchParameters.Insert("FirstRecord", PortionNumber);
	SearchParameters.Insert("Sort",   "ASC");
	
	FillOptionBatch(SearchParameters);
EndProcedure

&AtClient
Procedure GoToPortion(Command)
	
	TransitionVariants= New ValueList;
	
	TransitionVariants.Add("1", "1..9");
	Variants = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	For Position = 1 To StrLen(Variants) Do
		Letter = Mid(Variants, Position, 1);
		TransitionVariants.Add(Letter, Letter + "...");
	EndDo;
	
	FirstLetter = Undefined;
	CurrentData = Items.AddressVariants.CurrentData;
	If CurrentData <> Undefined Then
		FirstLetter = TransitionVariants.FindByValue( Upper(Left(TrimL(CurrentData.Presentation), 1)) );
	EndIf;
	
	Notification = New NotifyDescription("TransitionToPositionByFirstLetter", ThisObject);
	ShowChooseFromMenu(Notification, TransitionVariants, Items.CommandBarGoToPortion);
EndProcedure

&AtClient
Procedure TransitionToPositionByFirstLetter(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		FillOptionBatchByFirstLetter(Result.Value);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val LineNumber)
	
	If Items.Pages.CurrentPage = Items.AdditionalTerritories Then 
		Data = AdditionalTerritoriesVariants.FindByID(Items.AdditionalTerritoriesVariants.CurrentRow);
	Else
		Data = AddressVariants.FindByID(LineNumber);
	EndIf;
	
	If Data = Undefined Then
		Return;
	ElsIf Not Data.NotActual Then
		NotifyOwner(Data);
		Return;
	EndIf;
	
	Notification = New NotifyDescription("MakeSelectionEndQuestion", ThisObject, Data);
	
	WarningIrrelevant = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Address ""%1"" is not applicable.
		|Continue?';ru='Адрес ""%1"" неактуален.
		|Продолжить?'"),
		Data.Presentation
	);
	TitleWarnings = NStr("en='Confirmation';ru='Подтверждение'");
	
	ShowQueryBox(Notification, WarningIrrelevant, QuestionDialogMode.YesNo, , ,TitleWarnings);
	
EndProcedure

&AtClient
Procedure GotoListBegin()
	
	SearchParameters = New Structure;
	SearchParameters.Insert("HideObsolete",              False);
	SearchParameters.Insert("AddressFormat", AddressFormat);
	SearchParameters.Insert("PortionSize", PortionSize);
	SearchParameters.Insert("FirstRecord", Undefined);
	SearchParameters.Insert("Sort",   "ASC");
	
	FillOptionBatch(SearchParameters);
	
EndProcedure


&AtClient
Procedure MakeSelectionEndQuestion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		NotifyOwner(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyOwner(Val Data, Cancel = False)
	
	Result = SelectedAddressStructure();
	If Not Cancel Then
		FillPropertyValues(Result, Data);
		If Items.Pages.CurrentPage = Items.AdditionalTerritories Then
			Result.Street = "";
			Result.AdditionalItem = Data.Presentation;
			Result.SubordinateItem = SubordinateItemForTerritory;
			
			If ValueIsFilled(SubordinateIdentifierForTerritory) Then
				Result.ID = SubordinateIdentifier;
			EndIf;
		Else
			Result.Street = Data.Presentation;
			Result.AdditionalItem = AdditionalItem;
			Result.SubordinateItem = SubordinateItem;
			
			If ValueIsFilled(SubordinateIdentifier) Then
				Result.ID = SubordinateIdentifier;
			ElsIf ValueIsFilled(AdditionalIdentifier) Then
				Result.ID = AdditionalIdentifier;
			EndIf;
		EndIf;
		Result.Presentation = GenerateAddressPresentation(Result);
	Else
		Result.Cancel = True;
	EndIf;
	
	Result.BriefErrorDescription = BriefErrorDescription;
	
	
	NotifyChoice(Result);
EndProcedure

&AtClient
Function SelectedAddressStructure()
	StructureOfAddress = New Structure;
	StructureOfAddress.Insert("Presentation", Undefined);
	StructureOfAddress.Insert("Street", Undefined);
	StructureOfAddress.Insert("ID", Undefined);
	StructureOfAddress.Insert("AdditionalItem", Undefined);
	StructureOfAddress.Insert("SubordinateItem", Undefined);
	StructureOfAddress.Insert("StateImported", True);
	StructureOfAddress.Insert("NotActual", False);
	StructureOfAddress.Insert("BriefErrorDescription", "");
	StructureOfAddress.Insert("Cancel", False);
	
	Return StructureOfAddress;
EndFunction

&AtClient
Function GenerateAddressPresentation(StructureOfAddress)
	
	Result = "";
	
	Delimiter = "";
	If ValueIsFilled(StructureOfAddress.Street) Then
		Result = StructureOfAddress.Street;
		Delimiter = ", ";
	EndIf;
	
	If ValueIsFilled(StructureOfAddress.AdditionalItem) Then
		Result = Result + Delimiter + StructureOfAddress.AdditionalItem;
		Delimiter = ", ";
	EndIf;
		
	If ValueIsFilled(StructureOfAddress.SubordinateItem) Then
		Result = Result + Delimiter + StructureOfAddress.SubordinateItem;
		Delimiter = ", ";
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure FillOptionBatch(SearchParameters)
	
	ClassifierData = ContactInformationManagementService.AddressesForInteractiveSelection(Parent, Level, SearchParameters);
	If ClassifierData.Cancel Then
		// Service at maintenance
		Return;
	EndIf;
	
	If ClassifierData.Data.Count() > 0 Then
		AddressVariants.Clear();
		AddressVariants.Load(ClassifierData.Data);
	EndIf;
EndProcedure

&AtServer
Procedure FillOptionBatchByFirstLetter(Text)
	ChoiceData = New ValueList;
	
	If StrLen(Text) < 1 Or Not ValueIsFilled(Parent)Then
		// No options, the list is empty, standard processing must not be used.
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AddressFormat", "FIAS");
	AdditionalParameters.Insert("HideObsolete", False);
	
	ClassifierData = ContactInformationManagementService.StreetAutoselectionList(Parent, Text, AdditionalParameters);
	If ClassifierData.Cancel Then
		Return;
	EndIf;
	
	ChoiceData = ClassifierData.Data;
	
	// Standard processing is off, only if there are own options.
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
		AddressVariants.Clear();
		For Each Address In ChoiceData Do
			AddressString = AddressVariants.Add();
			AddressString.Presentation = Address.Value.Value.Presentation;
			AddressString.ID = Address.Value.Value.ID;
			AddressString.NotActual = Address.Check;
		EndDo;
	EndIf;

EndProcedure

&AtServer
Procedure SetDataOnStreetRepresentation(Presentation, ParentIdentifier)
	
	AnalysisClassifier =ContactInformationManagementService.StreetsReporting(ParentIdentifier, Presentation);
	If AnalysisClassifier <> Undefined Then
		StreetData = AnalysisClassifier.Find(7, "Level");
		If StreetData <> Undefined Then
			Filter = New Structure("Presentation",StreetData.Value);
			Variants = AddressVariants.FindRows(Filter);
			If Variants.Count() > 0 Then 
				Items.AddressVariants.CurrentRow = Variants[0].GetID();
			EndIf;
			DataAdditionalItem = AnalysisClassifier.Find(90, "Level");
			If DataAdditionalItem <> Undefined Then
				AdditionalItem = DataAdditionalItem.Value;
			EndIf;
			DataSubordinateItem = AnalysisClassifier.Find(91, "Level");
			If DataSubordinateItem <> Undefined Then 
				SubordinateItem = DataSubordinateItem.Value;
			EndIf;
		Else
			DataAdditionalItem = AnalysisClassifier.Find(90, "Level");
			If DataAdditionalItem <> Undefined Then 
				Filter = New Structure("Presentation", DataAdditionalItem.Value);
				Variants = AdditionalTerritoriesVariants.FindRows(Filter);
				If Variants.Count() > 0 Then
					Items.AdditionalTerritoriesVariants.CurrentRow = Variants[0].GetID();
				EndIf;
				Items.Pages.CurrentPage = Items.AdditionalTerritories;
			EndIf;
			DataSubordinateItemForTerritory = AnalysisClassifier.Find(91, "Level");
			If DataSubordinateItemForTerritory <> Undefined Then 
				SubordinateItemForTerritory = DataSubordinateItemForTerritory.Value;
			EndIf;
		EndIf;
	Else
		StreetParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Presentation, ",", True, True);
		If StreetParts.Count() = 3 Then
			Filter = New Structure("Presentation", StreetParts[0]);
			Variants = AddressVariants.FindRows(Filter);
			If Variants.Count() > 0 Then 
				Items.AddressVariants.CurrentRow = Variants[0].GetID();
			EndIf;
			AdditionalItem =  StreetParts[1];
			SubordinateItem = StreetParts[2];
		ElsIf StreetParts.Count() = 2 Then
			Filter = New Structure("Presentation", StreetParts[0]);
			Variants = AddressVariants.FindRows(Filter);
			If Variants.Count() > 0 Then
				Items.AddressVariants.CurrentRow = Variants[0].GetID();
				If Items.StreetsAndSettlements.Visible Then
					AdditionalItem = TrimAll(StreetParts[1]);
				Else
					SubordinateItemForTerritory = TrimAll(StreetParts[1]);
				EndIf;
			Else
				Variants = AdditionalTerritoriesVariants.FindRows(Filter);
				If Variants.Count() > 0 Then
					Items.AdditionalTerritoriesVariants.CurrentRow = Variants[0].GetID();
					If Items.StreetsAndSettlements.Visible Then
						AdditionalItem = TrimAll(StreetParts[1]);
					Else
						SubordinateItemForTerritory = TrimAll(StreetParts[1]);
					EndIf;
				EndIf;
			EndIf;
		ElsIf StreetParts.Count() = 1 Then
			Filter = New Structure("Presentation", StreetParts[0]);
			Variants = AddressVariants.FindRows(Filter);
			If Variants.Count() > 0 Then
				Items.AddressVariants.CurrentRow = Variants[0].GetID();
			Else
				Variants = AdditionalTerritoriesVariants.FindRows(Filter);
				If Variants.Count() > 0 Then
					Items.AdditionalTerritoriesVariants.CurrentRow = Variants[0].GetID();
					Items.Pages.CurrentPage = Items.AdditionalTerritories;
				Else
					If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
						AddressObject = ContactInformationManagementClientServer.DescriptionAbbreviation(Presentation);
						
						ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
						Result = ModuleAddressClassifierService.StreetAndAdditionalTerritory(AddressObject, ParentIdentifier);
						If Result <> Undefined Then
							Filter = New Structure("ID", Result.StreetIdentifier);
							Variants = AddressVariants.FindRows(Filter);
							Items.AddressVariants.CurrentRow = Variants[0].GetID();
							AdditionalIdentifier = Result.ID;
							AdditionalItem = Result.Value;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
EndProcedure



#EndRegion
