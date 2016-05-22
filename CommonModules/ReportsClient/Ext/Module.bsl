////////////////////////////////////////////////////////////////////////////////
// Work methods with the DAS from the report form (client).
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

Procedure LinkerListSelectionBegin(Form, Item, ChoiceData, StandardProcessing) Export
	StandardProcessing = False;
	
	ItemIdentificator = Right(Item.Name, 32);
	DCUsersSetting = FindElementsUsersSetup(Form, ItemIdentificator);
	AdditionalSettings = FindAdditionalItemSettings(Form, ItemIdentificator);
	If AdditionalSettings = Undefined Then
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Form", Form);
	HandlerParameters.Insert("ItemIdentificator", ItemIdentificator);
	Handler = New NotifyDescription("LinkerListEndSelection", ThisObject, HandlerParameters);
	
	If TypeOf(DCUsersSetting) = Type("DataCompositionFilterItem") Then
		Value = DCUsersSetting.RightValue;
	Else
		Value = DCUsersSetting.Value;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("UniqueKey", ItemIdentificator);
	FormParameters.Insert("marked", ReportsClientServer.ValueList(Value));
	CommonUseClientServer.ExpandStructure(FormParameters, AdditionalSettings, True);
	
	FormParameters.Insert("ChoiceParameters", New Array);
	
	// Add the fixed selection parameters.
	For Each ChoiceParameter IN Item.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If ValueIsFilled(ChoiceParameter.Name) Then
			FormParameters.ChoiceParameters.Add(ChoiceParameter);
		EndIf;
	EndDo;
	
	// Insert dynamic selection parameters (from leading). For the backward compatibility.
	For Each ChoiceParameterLink IN Item.ChoiceParameterLinks Do
		If IsBlankString(ChoiceParameterLink.Name) Then
			Continue;
		EndIf;
		LeaderValue = Form[ChoiceParameterLink.DataPath];
		FormParameters.ChoiceParameters.Add(New ChoiceParameter(ChoiceParameterLink.Name, LeaderValue));
	EndDo;
	
	// Insert dynamic selection parameters (from leading).
	Found = Form.DisabledLinks.FindRows(New Structure("SubordinateIdentifierInForm", ItemIdentificator));
	For Each Link IN Found Do
		If Not ValueIsFilled(Link.LeadingIdentifierInForm)
			Or Not ValueIsFilled(Link.SubordinateNameParameter) Then
			Continue;
		EndIf;
		LeaderDASetting = FindElementsUsersSetup(Form, Link.LeadingIdentifierInForm);
		If Not LeaderDASetting.Use Then
			Continue;
		EndIf;
		If TypeOf(LeaderDASetting) = Type("DataCompositionFilterItem") Then
			LeaderValue = LeaderDASetting.RightValue;
		Else
			LeaderValue = LeaderDASetting.Value;
		EndIf;
		If Link.LinkType = "ParametersSelect" Then
			FormParameters.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateNameParameter, LeaderValue));
		ElsIf Link.LinkType = "ByType" Then
			LeadingType = TypeOf(LeaderValue);
			If FormParameters.TypeDescription.ContainsType(LeadingType) AND FormParameters.TypeDescription.Types().Count() > 1 Then
				TypeArray = New Array;
				TypeArray.Add(LeadingType);
				FormParameters.TypeDescription = New TypeDescription(TypeArray);
			EndIf;
		EndIf;
	EndDo;
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("CommonForm.EnterValuesListWithCheckBoxes", FormParameters, ThisObject, , , , Handler, Block);
EndProcedure

Procedure LinkerListEndSelection(ChoiceResult, HandlerParameters) Export
	If TypeOf(ChoiceResult) <> Type("ValueList") Then
		Return;
	EndIf;
	Form = HandlerParameters.Form;
	
	ItemIdentificator = HandlerParameters.ItemIdentificator;
	
	DCUsersSetting = FindElementsUsersSetup(Form, ItemIdentificator);
	AdditionalSettings = FindAdditionalItemSettings(Form, ItemIdentificator);
	
	// Import selected values in 2 lists.
	ValueListInDAS = New ValueList;
	If Not AdditionalSettings.LimitChoiceWithSpecifiedValues Then
		AdditionalSettings.ValuesForSelection = New ValueList;
	EndIf;
	For Each ListItemInForm IN ChoiceResult Do
		ValueInForm = ListItemInForm.Value;
		If Not AdditionalSettings.LimitChoiceWithSpecifiedValues Then
			If AdditionalSettings.ValuesForSelection.FindByValue(ValueInForm) <> Undefined Then
				Continue;
			EndIf;
			FillPropertyValues(AdditionalSettings.ValuesForSelection.Add(), ListItemInForm, "Value,Presentation");
		EndIf;
		If ListItemInForm.Check Then
			If TypeOf(ValueInForm) = Type("TypeDescription") Then
				ValueInDAS = ValueInForm.Types()[0];
			Else
				ValueInDAS = ValueInForm;
			EndIf;
			ReportsClientServer.AddUniqueValueInList(ValueListInDAS, ValueInDAS, ListItemInForm.Presentation, True);
		EndIf;
	EndDo;
	If TypeOf(DCUsersSetting) = Type("DataCompositionFilterItem") Then
		DCUsersSetting.RightValue = ValueListInDAS;
	Else
		DCUsersSetting.Value = ValueListInDAS;
	EndIf;
	
	// Select the Use check box.
	DCUsersSetting.Use = True;
	
	Form.UserSettingsModified = True;
	#If WebClient Then
		Form.RefreshDataRepresentation();
	#EndIf
EndProcedure

Function FindElementsUsersSetup(Form, ItemIdentificator) Export
	// For custom settings, data composition IDs are stored as they can not be stored as a reference (value copy is in progress).
	SettingsComposer = ReportsClientServer.SettingsComposer(Form);
	DCIdentifier = Form.FastSearchOfUserSettings.Get(ItemIdentificator);
	If DCIdentifier = Undefined Then
		Return Undefined;
	Else
		Return SettingsComposer.UserSettings.GetObjectByID(DCIdentifier);
	EndIf;
EndFunction

Function FindAdditionalItemSettings(Form, ItemIdentificator) Export
	// For custom settings, data composition IDs are stored as they can not be stored as a reference (value copy is in progress).
	SettingsComposer = ReportsClientServer.SettingsComposer(Form);
	AllAdditionalSettings = CommonUseClientServer.StructureProperty(SettingsComposer.UserSettings.AdditionalProperties, "FormItems");
	If AllAdditionalSettings = Undefined Then
		Return Undefined;
	Else
		Return AllAdditionalSettings[ItemIdentificator];
	EndIf;
EndFunction

#EndRegion