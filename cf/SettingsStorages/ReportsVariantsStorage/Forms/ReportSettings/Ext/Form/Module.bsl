&AtClient
Var ClientVariables;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENTS

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("SettingsComposer", SettingsComposer) Then
		Raise NStr("en='The SettingsLinker service parameter has not been passed.';ru='Не передан служебный параметр ""КомпоновщикНастроек"".'");
	EndIf;
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("en='The ReportSettings service parameter has not been passed.';ru='Не передан служебный параметр ""НастройкиОтчета"".'");
	EndIf;
	If Not Parameters.Property("OptionName", OptionName) Then
		Raise NStr("en='The VariantName service parameter has not been passed.';ru='Не передан служебный параметр ""ВариантНаименование"".'");
	EndIf;
	Parameters.Property("CurrentCDHostIdentifier", CurrentCDHostIdentifier);
	If CurrentCDHostIdentifier <> Undefined Then
		VariantNodeChangingMode = True;
		Height = 0;
		WindowOptionsKey = String(CurrentCDHostIdentifier);
		If Not Parameters.Property("Title", Title) Then
			Raise NStr("en='The Title service parameter has not been passed.';ru='Не передан служебный параметр ""Заголовок"".'");
		EndIf;
		If Not Parameters.Property("CurrentCDHostType", CurrentCDHostType) Then
			Raise NStr("en='The CurrentDCNode service parameter has not been passed.';ru='Не передан служебный параметр ""ТипТекущегоУзлаКД"".'");
		EndIf;
	Else
		If Not ValueIsFilled(OptionName) Then
			OptionName = ReportSettings.Description;
		EndIf;
		Title = NStr("en='Report settings';ru='Настройки отчета'") + " """ + OptionName + """";
	EndIf;
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	If VariantNodeChangingMode Then
		PageName = "PageGroupingContent";
		ExtendedMode = 1;
	Else
		ExtendedMode = CommonUseClientServer.StructureProperty(ReportSettings, "SettingsFormExtendedMode", 0);
		PageName = CommonUseClientServer.StructureProperty(ReportSettings, "SettingsFormPageName", "PageFilters");
	EndIf;
	Page = Items.Find(PageName);
	If Page <> Undefined Then
		Items.SettingPages.CurrentPage = Page;
	EndIf;
	
	InactiveTableValuesColor = StyleColors.InaccessibleDataColor;
	
	// Registration of the commands and the form attributes that are not deleted during the refill of quick settings.
	AttributesSet = GetAttributes();
	For Each Attribute IN AttributesSet Do
		ConstantAttributes.Add(AttributeFullName(Attribute));
	EndDo;
	For Each Command IN Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("Event", New Structure);
	FillingParameters.Event.Insert("Name", "OnCreateAtServer");
	If Not VariantNodeChangingMode AND ExtendedMode = 1 Then
		FillingParameters.Insert("UpdateVariantSettings", True);
	EndIf;
	QuickSettingsFill(FillingParameters);
	
	AddConditionalDesign();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ClientVariables = New Structure;
EndProcedure

&AtClient
Procedure OnClose()
	If Not SelectionResultGenerated Then
		If OnCloseNotifyDescription <> Undefined Then
			ExecuteNotifyProcessing(OnCloseNotifyDescription, ChoiceResult(False));
		EndIf;
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// ITEMS EVENTS

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ExtendedModeOnChange(Item)
	FillingParameters = New Structure;
	FillingParameters.Insert("Event", New Structure("Name", "ExtendedModeOnChange"));
	If ExtendedMode = 1 Then
		FillingParameters.Insert("UpdateVariantSettings", True);
	Else
		FillingParameters.Insert("ResetUserSettings", True);
	EndIf;
	QuickSettingsFillClient(FillingParameters);
EndProcedure

&AtClient
Procedure CurrentCDHostChartTypeOnChange(Item)
	RootDCNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
	If TypeOf(RootDCNode) = Type("DataCompositionNestedObjectSettings") Then
		RootDCNode = RootDCNode.Settings;
	EndIf;
	SetOutputParameter(RootDCNode, "ChartType", CurrentCDHostChartType);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure ToolTipThereAreNestedReportsDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	StandardProcessing = False;
	
	FormParameters = New Structure(FormOwner.ParametersForm);
	FormParameters.Insert("Variant",                               SettingsComposer.Settings);
	FormParameters.Insert("VariantKey",                          String(FormOwner.CurrentVariantKey));
	FormParameters.Insert("UserSettings",             SettingsComposer.UserSettings);
	FormParameters.Insert("VariantPresentation",                 OptionName);
	FormParameters.Insert("UserSettingsPresentation", "");
	
	Handler = New NotifyDescription("VariantFormEnd", ThisObject);
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm(ReportSettings.FullName + ".VariantForm", FormParameters, ThisObject, , , , Handler, Mode);
EndProcedure

&AtClient
Procedure VariantFormEnd(Result, ExecuteParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	QuickSettingsFill(Result);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached

&AtClient
Procedure Attachable_CheckboxUsing_OnChange(Item)
	FlagName = Item.Name;
	ItemIdentificator = Right(FlagName, 32);
	Type = Left(FlagName, Find(FlagName, "_")-1);
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	
	If Type = "FilterItem" Or Type = "ParameterValue" Then
		TableName = Type + "_ValueList_" + ItemIdentificator;
		FormTable = Items.Find(TableName);
		If FormTable <> Undefined Then
			FormTable.TextColor = ?(DCUsersSetting.Use, New Color, InactiveTableValuesColor);
		EndIf;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		Found = FindVariantSetting(ThisObject, ItemIdentificator);
		If Found <> Undefined Then
			Found.KDItem.Use = DCUsersSetting.Use;
			VariantModified = True;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_InputField_OnChange(Item)
	ItemIdentificator = Right(Item.Name, 32);
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		Value = DCUsersSetting.Value;
	ElsIf TypeOf(DCUsersSetting) = Type("DataCompositionFilterItem") Then
		Value = DCUsersSetting.RightValue;
	Else
		Return;
	EndIf;
	
	If ValueIsFilled(Value) Then
		DCUsersSetting.Use = True;
	EndIf;
	
	If DCUsersSetting.Use Then // Clear values during value change.
		Found = DisabledLinks.FindRows(New Structure("LeadingIdentifierInForm", ItemIdentificator));
		For Each Link IN Found Do
			If Not ValueIsFilled(Link.SubordinateIdentifierInForm) Then
				Continue;
			EndIf;
			If Link.LinkType = "ParametersSelect" Then
				If Link.SubordinatedAction <> LinkedValueChangeMode.Clear Then
					Continue;
				EndIf;
			Else
				Continue;
			EndIf;
			SubordinateAdditionally = ReportsClient.FindAdditionalItemSettings(ThisObject, Link.SubordinateIdentifierInForm);
			If SubordinateAdditionally <> Undefined Then
				If SubordinateAdditionally.DisplayCheckbox Then
					SubordinateDCSetting = ReportsClient.FindElementsUsersSetup(ThisObject, Link.SubordinateIdentifierInForm);
					If SubordinateDCSetting <> Undefined Then
						SubordinateDCSetting.Use = False;
					EndIf;
				EndIf;
				If Not SubordinateAdditionally.LimitChoiceWithSpecifiedValues Then
					SubordinateAdditionally.ValuesForSelection.Clear();
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ValueCheckbox_OnChange(Item)
	ItemIdentificator = Right(Item.Name, 32);
	Value = ThisObject[Item.Name];
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_LinkerList_Value_StartChoice(Item, ChoiceData, StandardProcessing)
	ReportsClient.LinkerListSelectionBegin(ThisObject, Item, ChoiceData, StandardProcessing);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached - Standard period.

&AtClient
Procedure Attachable_StandardPeriod_Kind_OnChange(Item)
	PeriodKindName = Item.Name;
	ItemIdentificator  = Right(PeriodKindName, 32);
	SettingPropertiesType = Left(PeriodKindName, Find(PeriodKindName, "_Kind_")-1);
	
	PagesName      = SettingPropertiesType + "_Pages_"      + ItemIdentificator;
	ValueName      = SettingPropertiesType + "_Value_"      + ItemIdentificator;
	AuthorPresentationActualName = SettingPropertiesType + "_Presentation_" + ItemIdentificator;
	RandomNamePage = SettingPropertiesType + "_PageRandom_" + ItemIdentificator;
	StandardNamePage  = SettingPropertiesType + "_PageStandard_"  + ItemIdentificator;
	
	Value = ThisObject[ValueName];
	
	PeriodKind = ThisObject[PeriodKindName];
	
	If ValueIsFilled(PeriodKind) Then
		RandomSelected = PeriodKind = PredefinedValue("Enum.AvailableReportPeriods.Custom");
	Else
		PeriodKind = PredefinedValue("Enum.AvailableReportPeriods.Custom");
		ThisObject[PeriodKindName] = PeriodKind;
		RandomSelected = True;
	EndIf;
	
	If RandomSelected Then
		
		// Switch page.
		Items[PagesName].CurrentPage = Items[RandomNamePage];
		
		Value.Variant = StandardPeriodVariant.Custom;
		
	Else
		
		// Switch page.
		Items[PagesName].CurrentPage = Items[StandardNamePage];
		
		// Adjust period values in terms of the selected kind.
		SessionDate = BegOfDay(CommonUseClient.SessionDate());
		BeginOfPeriod = BegOfDay(Value.StartDate);
		EndOfPeriod = EndOfDay(Value.EndDate);
		If Not ValueIsFilled(BeginOfPeriod)
			Or (SessionDate >= BeginOfPeriod AND SessionDate <= EndOfPeriod) Then
			BeginOfPeriod = SessionDate;
		EndIf;
		BeginOfPeriod = ReportsClientServer.ReportPeriodStart(PeriodKind, BeginOfPeriod);
		EndOfPeriod  = ReportsClientServer.ReportEndOfPeriod(PeriodKind, BeginOfPeriod);
		
		Value.StartDate    = BeginOfPeriod;
		Value.EndDate = EndOfPeriod;
		
	EndIf;
	
	Presentation = ReportsClientServer.PresentationStandardPeriod(Value, PeriodKind);
	ThisObject[AuthorPresentationActualName] = Presentation;
	ThisObject[ValueName]      = Value;
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	DCUsersSetting.Use = True;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_Value_StartChoice(Item, StandardProcessing)
	StandardProcessing = False;
	
	// Generate information about an item.
	AuthorPresentationActualName = Item.Name;
	ItemIdentificator  = Right(AuthorPresentationActualName, 32);
	SettingPropertiesType = Left(AuthorPresentationActualName, Find(AuthorPresentationActualName, "_Presentation_")-1);
	
	ValueName   = SettingPropertiesType + "_Value_"      + ItemIdentificator;
	PeriodKindName = SettingPropertiesType + "_Kind_"           + ItemIdentificator;
	
	Value   = ThisObject[ValueName];
	PeriodKind = ThisObject[PeriodKindName];
	
	BeginOfPeriod = Value.StartDate;
	If BeginOfPeriod = '00010101' Then
		BeginOfPeriod = ReportsClientServer.ReportPeriodStart(PeriodKind, CommonUseClient.SessionDate());
	EndIf;
	
	// Parameters for reading from handlers:
	ChoiceParameters = New Structure;
	// To select value:
	ChoiceParameters.Insert("Value",               Value);
	ChoiceParameters.Insert("Item",                Item);
	// To import value:
	ChoiceParameters.Insert("ItemIdentificator",  ItemIdentificator);
	ChoiceParameters.Insert("AuthorPresentationActualName", AuthorPresentationActualName);
	ChoiceParameters.Insert("ValueName",      ValueName);
	ChoiceParameters.Insert("PeriodKind",  PeriodKind);
	ChoiceParameters.Insert("IsParameter", SettingPropertiesType = "SettingsParameterValue");
	
	SelectPeriodFromDropdownList(-1, ChoiceParameters);
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_BeginOfPeriod_OnChange(Item)
	// Generate information about an item.
	BeginOfPeriodName = Item.Name;
	ItemIdentificator  = Right(BeginOfPeriodName, 32);
	SettingPropertiesType = Left(BeginOfPeriodName, Find(BeginOfPeriodName, "_Begin_")-1);
	ValueName = SettingPropertiesType + "_Value_" + ItemIdentificator;
	
	Value = ThisObject[ValueName];
	
	If Value.StartDate <> '00010101' Then
		Value.StartDate = BegOfDay(Value.StartDate);
	EndIf;
	
	// Write a value to custom settings of the data template.
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	If Value.StartDate <> '00010101' Then
		DCUsersSetting.Use = True;
	EndIf;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_EndOfPeriod_OnChange(Item)
	// Generate information about an item.
	EndOfPeriodName = Item.Name;
	ItemIdentificator  = Right(EndOfPeriodName, 32);
	SettingPropertiesType = Left(EndOfPeriodName, Find(EndOfPeriodName, "_End_")-1);
	
	ValueName = SettingPropertiesType + "_Value_" + ItemIdentificator;
	
	Value = ThisObject[ValueName];
	
	If Value.EndDate <> '00010101' Then
		Value.EndDate = EndOfDay(Value.EndDate);
	EndIf;
	
	// Write a value to custom settings of the data template.
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	If Value.EndDate <> '00010101' Then
		DCUsersSetting.Use = True;
	EndIf;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_Value_Clearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached - Values list with the Selection button.

&AtClient
Procedure Attachable_ListWithSelection_OnChange(FormTable)
	// Update values in the DLS data.
	ItemIdentificator = Right(FormTable.Name, 32);
	
	ValuesListInForm = ThisObject[FormTable.Name];
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	AdditionalSettings = FindAdditionalItemSettings(ItemIdentificator);
	
	ValueListInDAS = New ValueList;
	If Not AdditionalSettings.LimitChoiceWithSpecifiedValues Then
		AdditionalSettings.ValuesForSelection = New ValueList;
	EndIf;
	For Each ListItemInForm IN ValuesListInForm Do
		ValueInForm = ListItemInForm.Value;
		If Not AdditionalSettings.LimitChoiceWithSpecifiedValues Then
			If AdditionalSettings.ValuesForSelection.FindByValue(ValueInForm) <> Undefined Then
				Continue;
			EndIf;
			FillPropertyValues(AdditionalSettings.ValuesForSelection.Add(), ListItemInForm);
		EndIf;
		If ListItemInForm.Check Then
			If TypeOf(ValueInForm) = Type("TypeDescription") Then
				ValueInDAS = ValueInForm.Types()[0];
			Else
				ValueInDAS = ValueInForm;
			EndIf;
			ValueListInDAS.Add(ValueInDAS);
		EndIf;
	EndDo;
	If TypeOf(DCUsersSetting) = Type("DataCompositionFilterItem") Then
		DCUsersSetting.RightValue = ValueListInDAS;
	Else
		DCUsersSetting.Value = ValueListInDAS;
	EndIf;
	
	// Select the Use check box.
	DCUsersSetting.Use = True;
	FormTable.TextColor = ?(DCUsersSetting.Use, New Color, InactiveTableValuesColor);
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_Value_AutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	If Parameters = Undefined Then
		Return;
	EndIf;
	
	ItemIdentificator = Right(Item.Name, 32);
	
	// Insert dynamic selection parameters (from leading).
	Found = DisabledLinks.FindRows(New Structure("SubordinateIdentifierInForm", ItemIdentificator));
	For Each Link IN Found Do
		If Not ValueIsFilled(Link.LeadingIdentifierInForm)
			Or Not ValueIsFilled(Link.SubordinateNameParameter) Then
			Continue;
		EndIf;
		LeaderDASetting = FindElementsUsersSetup(Link.LeadingIdentifierInForm);
		If Not LeaderDASetting.Use Then
			Continue;
		EndIf;
		If TypeOf(LeaderDASetting) = Type("DataCompositionFilterItem") Then
			LeaderValue = LeaderDASetting.RightValue;
		Else
			LeaderValue = LeaderDASetting.Value;
		EndIf;
		If Link.LinkType = "ParametersSelect" Then
			KeyArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Link.SubordinateNameParameter, ".", True, True);
			UBound = KeyArray.UBound();
			Context = Parameters;
			For IndexOf = 0 To UBound Do
				Key = KeyArray[IndexOf];
				If IndexOf = UBound Then
					Context.Insert(Key, LeaderValue);
				Else
					InsertedContext = CommonUseClientServer.StructureProperty(Context, Key);
					If InsertedContext = Undefined Then
						InsertedContext = Context.Insert(Key, New Structure);
					ElsIf TypeOf(InsertedContext) <> Type("Structure") Then
						Break;
					EndIf;
					Context = InsertedContext;
				EndIf;
			EndDo;
		ElsIf Link.LinkType = "ByType" Then
			LeadingType = TypeOf(LeaderValue);
			AdditionalSettings = FindAdditionalItemSettings(ItemIdentificator);
			If AdditionalSettings <> Undefined
				AND AdditionalSettings.TypeDescription.ContainsType(LeadingType)
				AND AdditionalSettings.TypeDescription.Types().Count() > 1 Then
				TypeArray = New Array;
				TypeArray.Add(LeadingType);
				Item.AvailableTypes = New TypeDescription(TypeArray);
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_Use_OnChange(Item)
	// Select the Usage check box if a user selected the check box in the row of the table.
	ColumnUsageName = Item.Name;
	ItemIdentificator   = Right(ColumnUsageName, 32);
	SettingPropertiesType    = Left(ColumnUsageName, Find(ColumnUsageName, "_Column_Usage_")-1);
	
	TableName       = SettingPropertiesType + "_ValueList_" + ItemIdentificator;
	
	ListItemInForm = Items[TableName].CurrentData;
	If ListItemInForm <> Undefined AND ListItemInForm.Check Then
		// Select the Use check box.
		DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
		DCUsersSetting.Use = True;
		
		// Rows design.
		FormTable = Items.Find(TableName);
		FormTable.TextColor = ?(DCUsersSetting.Use, New Color, InactiveTableValuesColor);
		
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_BeforeStartChanging(Item, Cancel)
	RowIdentifier = Item.CurrentRow;
	If RowIdentifier = Undefined Then
		Return;
	EndIf;
	
	ValuesListInForm = ThisObject[Item.Name];
	ListItemInForm = ValuesListInForm.FindByID(RowIdentifier);
	
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	ListItemPriorToChange = New Structure("Identifier, Mark, Value, Presentation");
	FillPropertyValues(ListItemPriorToChange, ListItemInForm);
	ListItemPriorToChange.ID = RowIdentifier;
	ClientVariables.Insert("ListItemPriorToChange", ListItemPriorToChange);
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_BeforeEditEnd(Item, NewRow, CancelStartEditing, CancelEndEditing)
	If CancelStartEditing Then
		Return;
	EndIf;
	
	RowIdentifier = Item.CurrentRow;
	If RowIdentifier = Undefined Then
		Return;
	EndIf;
	ItemIdentificator = Right(Item.Name, 32);
	ValuesListInForm  = ThisObject[Item.Name];
	ListItemInForm   = ValuesListInForm.FindByID(RowIdentifier);
	
	Value = ListItemInForm.Value;
	If Value = Undefined
		Or Value = Type("Undefined")
		Or Value = New TypeDescription("Undefined")
		Or Not ValueIsFilled(Value) Then
		CancelEndEditing = True; // Prevent null values.
	Else
		For Each ListItemDoubleInForm IN ValuesListInForm Do
			If ListItemDoubleInForm.Value = Value AND ListItemDoubleInForm <> ListItemInForm Then
				Status(NStr("en='Found duplicate records. Editing canceled.';ru='Обнаружены дублирующиеся записи. Редактирование отменено.'"));
				CancelEndEditing = True; // Deny duplicates.
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	ListItemPriorToChange = CommonUseClientServer.StructureProperty(ClientVariables, "ListItemPriorToChange");
	HasInformation = (ListItemPriorToChange <> Undefined AND ListItemPriorToChange.ID = RowIdentifier);
	If Not CancelEndEditing AND HasInformation AND ListItemPriorToChange.Value <> Value Then
		AdditionalSettings = ReportsClient.FindAdditionalItemSettings(ThisObject, ItemIdentificator);
		If AdditionalSettings.LimitChoiceWithSpecifiedValues Then
			CancelEndEditing = True;
		Else
			ListItemInForm.Presentation = ""; // AutoFill of presentation.
			ListItemInForm.Check = True; // Select check box.
		EndIf;
	EndIf;
	
	If CancelEndEditing Then
		// Values rollback.
		If HasInformation Then
			FillPropertyValues(ListItemInForm, ListItemPriorToChange);
		EndIf;
		// Restart the BeforeEditingEnd event with CancelEditingBegin = True.
		Item.EndEditRow(True);
	Else
		If NewRow Then
			ListItemInForm.Check = True; // Select check box.
		EndIf;
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_Pick(Command)
	CompleteNameButton = Command.Name;
	
	ItemIdentificator  = Right(CompleteNameButton, 32);
	SettingPropertiesType = Left(CompleteNameButton, Find(CompleteNameButton, "_Pick_")-1);
	
	TableName         = SettingPropertiesType + "_ValueList_"   + ItemIdentificator;
	ValueNameColumn = SettingPropertiesType + "_Column_Value_" + ItemIdentificator;
	CompleteNameButton    = SettingPropertiesType + "_Pick_"  + ItemIdentificator;//PagReplace(ItemNameTemplate, %1, Selection);
	
	TableValue = ThisObject[TableName];
	ElementValueColumn = Items[ValueNameColumn];
	
	TypeDescription = TableValue.ValueType;
	
	ItemParameters = New Structure;
	ItemParameters.Insert("ItemIdentificator",  ItemIdentificator);
	ItemParameters.Insert("SelectedType",           Undefined);
	ItemParameters.Insert("ElementValueColumn", ElementValueColumn);
	ItemParameters.Insert("ItemTable",         Items[TableName]);
	ItemParameters.Insert("CaseOnlyOfGroups",       ElementValueColumn.ChoiceFoldersAndItems = FoldersAndItems.Folders);
	ItemParameters.Insert("ChoiceParameters",        New Array);
	
	Found = DisabledLinks.FindRows(New Structure("SubordinateIdentifierInForm", ItemIdentificator));
	For Each Link IN Found Do
		If Not ValueIsFilled(Link.LeadingIdentifierInForm)
			Or Not ValueIsFilled(Link.SubordinateNameParameter) Then
			Continue;
		EndIf;
		LeaderDASetting = FindElementsUsersSetup(Link.LeadingIdentifierInForm);
		If Not LeaderDASetting.Use Then
			Continue;
		EndIf;
		If TypeOf(LeaderDASetting) = Type("DataCompositionFilterItem") Then
			LeaderValue = LeaderDASetting.RightValue;
		Else
			LeaderValue = LeaderDASetting.Value;
		EndIf;
		If Link.LinkType = "ParametersSelect" Then
			ItemParameters.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateNameParameter, LeaderValue));
		ElsIf Link.LinkType = "ByType" Then
			LeaderType = TypeOf(LeaderValue);
			If TypeDescription.ContainsType(LeaderType) Then
				ItemParameters.SelectedType = LeaderType;
			EndIf;
		EndIf;
	EndDo;
	
	If ItemParameters.SelectedType <> Undefined Then // Type is defined as a leading one.
		Attachable_ListWithSelection_Pick_OpenChoiceForm(-1, ItemParameters);
		Return;
	EndIf;
	
	// Select type from list.
	ChoiceList = New ValueList;
	
	SimpleTypes = New Map;
	SimpleTypes.Insert(Type("String"), True);
	SimpleTypes.Insert(Type("Date"),   True);
	SimpleTypes.Insert(Type("Number"),  True);
	
	TypeArray = TypeDescription.Types();
	For Each Type IN TypeArray Do
		// Exclude types for which there are no groups.
		If ItemParameters.CaseOnlyOfGroups Then
			MetadataObjectName = QuickSearchMetadataObjectName.Get(Type);
			MetadataObjectKind = Upper(Left(MetadataObjectName, Find(MetadataObjectName, ".")-1));
			If MetadataObjectKind <> "CATALOG" AND MetadataObjectKind <> "CHARTOFCHARACTERISTICTYPES" AND MetadataObjectKind <> "CHARTOFACCOUNTS" Then
				Continue;
			EndIf;
		EndIf;
		// Exclude simple types.
		If SimpleTypes[Type] = True Then
			Continue;
		EndIf;
		// Add type to a selection list.
		ChoiceList.Add(Type, String(Type));
	EndDo;
	
	If ChoiceList.Count() = 0 Then
		ItemParameters.ItemTable.AddLine();
		Return;
	ElsIf ChoiceList.Count() = 1 Then
		// One type - selection is not required.
		ItemParameters.SelectedType = ChoiceList[0].Value;
		Attachable_ListWithSelection_Pick_OpenChoiceForm(-1, ItemParameters);
	Else
		// More than one type.
		Handler = New NotifyDescription("Attachable_ListWithSelection_Pick_OpenChoiceForm", ThisObject, ItemParameters);
		ShowChooseFromMenu(Handler, ChoiceList, Items[CompleteNameButton]);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_Pick_OpenChoiceForm(SelectedItem, ItemParameters) Export
	If SelectedItem = Undefined Then
		Return;
	ElsIf SelectedItem <> -1 Then
		ItemParameters.SelectedType = SelectedItem.Value;
	EndIf;
	
	ElementValueColumn = ItemParameters.ElementValueColumn;
	
	// Full name of a selection form.
	// The ChoiceForm property is unavailable on client
	//   even for read, that is why to store the preset selection form names, the MetadataObjectsNamesQuickSearch collection is used.
	PathToForm = QuickSearchMetadataObjectName.Get(ItemParameters.ItemIdentificator);
	If Not ValueIsFilled(PathToForm) Then
		MetadataObjectName = QuickSearchMetadataObjectName.Get(ItemParameters.SelectedType);
		If ItemParameters.CaseOnlyOfGroups Then
			MetadataObjectKind = Upper(Left(MetadataObjectName, Find(MetadataObjectName, ".")-1));
			If MetadataObjectKind = "CATALOG" Or MetadataObjectKind = "CHARTOFCHARACTERISTICTYPES" Then
				PathToForm = MetadataObjectName + ".GroupChoiceForm";
			Else
				PathToForm = MetadataObjectName + ".ChoiceForm";
			EndIf;
		Else
			PathToForm = MetadataObjectName + ".ChoiceForm";
		EndIf;
	EndIf;
	
	ChoiceFoldersAndItems = ReportsClientServer.AdjustValueToTypeOfFoldersAndItemsUse(ElementValueColumn.ChoiceFoldersAndItems);
	
	ChoiceFormParameters = New Structure;
	// Standard form parameters.
	ChoiceFormParameters.Insert("CloseOnChoice",            False);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("Filter",                         New Structure);
	// Standard selection form parameters (see Extension of a managed form for a dynamic list).
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems",          ChoiceFoldersAndItems);
	ChoiceFormParameters.Insert("Multiselect",            True);
	ChoiceFormParameters.Insert("ChoiceMode",                   True);
	// Estimated attributes.
	ChoiceFormParameters.Insert("WindowOpeningMode",             FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("EnableStartDrag", False);
	
	// Add the fixed selection parameters.
	For Each ChoiceParameter IN ElementValueColumn.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If ValueIsFilled(ChoiceParameter.Name) Then
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				ChoiceFormParameters.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	// Insert dynamic selection parameters (from leading). For the backward compatibility.
	For Each ChoiceParameterLink IN ElementValueColumn.ChoiceParameterLinks Do
		If IsBlankString(ChoiceParameterLink.Name) Then
			Continue;
		EndIf;
		LeaderValue = ThisObject[ChoiceParameterLink.DataPath];
		If Upper(Left(ChoiceParameterLink.Name, 6)) = Upper("Filter.") Then
			ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameterLink.Name, 7), LeaderValue);
		Else
			ChoiceFormParameters.Insert(ChoiceParameterLink.Name, LeaderValue);
		EndIf;
	EndDo;
	
	// Insert dynamic selection parameters (from leading).
	For Each ChoiceParameter IN ItemParameters.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		If ValueIsFilled(ChoiceParameter.Name) Then
			If Upper(Left(ChoiceParameter.Name, 6)) = Upper("Filter.") Then
				ChoiceFormParameters.Filter.Insert(Mid(ChoiceParameter.Name, 7), ChoiceParameter.Value);
			Else
				ChoiceFormParameters.Insert(ChoiceParameter.Name, ChoiceParameter.Value);
			EndIf;
		EndIf;
	EndDo;
	
	OpenForm(PathToForm, ChoiceFormParameters, ItemParameters.ItemTable);
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_ChoiceProcessing(Item, ChoiceResult, StandardProcessing)
	StandardProcessing = False;
	
	// Lists in form data.
	TableName = Item.Name;
	ItemIdentificator = Right(Item.Name, 32);
	ValuesListInForm  = ThisObject[Item.Name];
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		ValueListInDAS = DCUsersSetting.Value;
	Else
		ValueListInDAS = DCUsersSetting.RightValue;
	EndIf;
	ValueListInDAS = ReportsClientServer.ValueList(ValueListInDAS);
	
	// Add selected items with uniqueness control.
	If TypeOf(ChoiceResult) = Type("Array") Then
		For Each Value IN ChoiceResult Do
			ReportsClientServer.AddUniqueValueInList(ValuesListInForm, Value, Undefined, True);
			ReportsClientServer.AddUniqueValueInList(ValueListInDAS,   Value, Undefined, True);
		EndDo;
	Else
		ReportsClientServer.AddUniqueValueInList(ValuesListInForm, ChoiceResult, Undefined, True);
		ReportsClientServer.AddUniqueValueInList(ValueListInDAS,   ChoiceResult, Undefined, True);
	EndIf;
	
	// Select the Use check box.
	DCUsersSetting.Use = True;
	
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value       = ValueListInDAS;
	Else
		DCUsersSetting.RightValue = ValueListInDAS;
	EndIf;
	
	// Rows design.
	FormTable = Items.Find(TableName);
	FormTable.TextColor = ?(DCUsersSetting.Use, New Color, InactiveTableValuesColor);
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_InsertFromBuffer(Command)
	InsertNameButton = Command.Name;
	
	ItemIdentificator    = Right(InsertNameButton, 32);
	SettingPropertiesType = Left(InsertNameButton, Find(InsertNameButton, "_")-1);
	
	TableName         = SettingPropertiesType + "_ValueList_"   + ItemIdentificator;
	ValueNameColumn = SettingPropertiesType + "_Column_Value_" + ItemIdentificator;
	
	List = ThisObject[TableName];
	ListItem = Items[TableName];
	ElementValueColumn = Items[ValueNameColumn];
	
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", TypeDescriptionsDeletePrimitive(List.ValueType));
	SearchParameters.Insert("ChoiceParameters", ElementValueColumn.ChoiceParameters);
	SearchParameters.Insert("FieldPresentation", ListItem.Title);
	SearchParameters.Insert("Script", "InsertionFromClipboard");
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ItemIdentificator", ItemIdentificator);
	ExecuteParameters.Insert("TableName", TableName);
	Handler = New NotifyDescription("Attachable_ListWithSelection_InsertFromBuffer_End", ThisObject, ExecuteParameters);
	
	ModuleDataLoadFromFileClient = CommonUseClient.CommonModule("DataLoadFromFileClient");
	ModuleDataLoadFromFileClient.ShowRefsFillingForm(SearchParameters, Handler);
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_InsertFromBuffer_End(FoundObjects, ExecuteParameters) Export
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	
	ItemIdentificator = ExecuteParameters.ItemIdentificator;
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	AdditionalSettings = FindAdditionalItemSettings(ItemIdentificator);
	
	List = ThisObject[ExecuteParameters.TableName];
	If TypeOf(DCUsersSetting) = Type("DataCompositionFilterItem") Then
		marked = DCUsersSetting.RightValue;
	Else
		marked = DCUsersSetting.Value;
	EndIf;
	For Each Value IN FoundObjects Do
		ReportsClientServer.AddUniqueValueInList(List, Value, Undefined, True);
		ReportsClientServer.AddUniqueValueInList(marked, Value, Undefined, True);
	EndDo;
	
	// Select the Use check box.
	DCUsersSetting.Use = True;
	
	// Rows design.
	FormTable = Items.Find(ExecuteParameters.TableName);
	FormTable.TextColor = ?(DCUsersSetting.Use, New Color, InactiveTableValuesColor);
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Procedure Attachable_ListWithSelection_Add(Command)
	
	CompleteNameButton = Command.Name;
	
	ItemIdentificator  = Right(CompleteNameButton, 32);
	SettingPropertiesType = Left(CompleteNameButton, Find(CompleteNameButton, "_Pick_") - 1);
	
	TableName = SettingPropertiesType + "_ValueList_" + ItemIdentificator;
	
	Items[TableName].AddLine();
	
EndProcedure

&AtClient
Procedure Attachable_FixedList_BeforeAddingBegin(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure Attachable_FixedList_BeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS Sorting

#Region FormTableItemsEventsHandlersSorting

&AtClient
Procedure SortSelection(Item, RowIdentifier, Field, StandardProcessing)
	StandardProcessing = False;
	ColumnName = Field.Name;
	If ColumnName = "SortPresentation" Then // Change a field
		FieldsTablesChange("Sort", RowIdentifier);
	ElsIf ColumnName = "SortDirection" Then // Change order.
		FieldsTablesChangeSortingDirection(Item.Name, Undefined);
	EndIf;
EndProcedure

&AtClient
Procedure SortBeforeBeginToAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
	Handler = New NotifyDescription("SortingAfterFieldSelection", ThisObject);
	FieldsTablesShowFieldSelection("Sort", Handler);
EndProcedure

&AtClient
Procedure SortingAfterFieldSelection(AvailableDCField, ExecuteParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldsTablesInsert("Sort", Type("DataCompositionOrderItem"), 0, Undefined);
	
	KDItem = Result.KDItem;
	KDItem.Use     = True;
	KDItem.Field              = AvailableDCField.Field;
	KDItem.OrderType = DataCompositionSortDirection.Asc;
	
	TableRow = Result.TableRow;
	TableRow.Use = KDItem.Use;
	TableRow.Presentation = AvailableDCField.Title;
	TableRow.Direction   = KDItem.OrderType;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure SortBeforeDelete(Item, Cancel)
	FieldsTablesBeforeDeleting(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure SortUseOnChange(Item)
	FieldsTablesChangeUsage("Sort");
EndProcedure

&AtClient
Procedure Sort_Descending(Command)
	FieldsTablesChangeSortingDirection("Sort", DataCompositionSortDirection.Desc);
EndProcedure

&AtClient
Procedure Sort_Ascending(Command)
	FieldsTablesChangeSortingDirection("Sort", DataCompositionSortDirection.Asc);
EndProcedure

&AtClient
Procedure Sort_MoveUp(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "Sort");
	Script.Insert("Direction", -1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure Sort_MoveDown(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "Sort");
	Script.Insert("Direction", 1);
	
	RunScript(Undefined, Script);
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS SelectedFields

#Region FormTableItemsEventsHandlersSelectedFields

&AtClient
Procedure SelectedFieldsChoice(Item, RowIdentifier, Field, StandardProcessing)
	StandardProcessing = False;
	ColumnName = Field.Name;
	If ColumnName = "SelectedFieldsPresentation" Then // Change order.
		TableRow = Items.SelectedFields.CurrentData;
		If TableRow = Undefined Then
			Return;
		EndIf;
		If TableRow.IsFolder Then
			FieldsTablesChangeGroup("SelectedFields", RowIdentifier, TableRow);
		Else
			FieldsTablesChange("SelectedFields", RowIdentifier);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeBeginAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
	Handler = New NotifyDescription("SelectedFieldsAfterFieldSelection", ThisObject);
	FieldsTablesShowFieldSelection("SelectedFields", Handler);
EndProcedure

&AtClient
Procedure SelectedFieldsAfterFieldSelection(AvailableDCField, ExecuteParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldsTablesInsert("SelectedFields", Type("DataCompositionSelectedField"), 0, Undefined);
	
	KDItem = Result.KDItem;
	KDItem.Use = True;
	KDItem.Field          = AvailableDCField.Field;
	
	TableRow = Result.TableRow;
	TableRow.Use  = KDItem.Use;
	TableRow.Presentation  = AvailableDCField.Title;
	TableRow.IsFolder      = False;
	TableRow.PictureIndex = 3;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	RefreshForm(Undefined, Undefined);
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeDelete(Item, Cancel)
	FieldsTablesBeforeDeleting(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure SelectedFieldsUseOnChange(Item)
	FieldsTablesChangeUsage("SelectedFields");
EndProcedure

&AtClient
Procedure SelectedFields_MoveUp(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "SelectedFields");
	Script.Insert("Direction", -1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure SelectedFields_MoveDown(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "SelectedFields");
	Script.Insert("Direction", 1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure SelectedFields_Group(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, InputTitle, FieldsTablesGroup, UpdateForm");
	Script.Insert("Action", "Group");
	Script.Insert("TableName", "SelectedFields");
	Script.Insert("DCGroupType", Type("DataCompositionSelectedFieldGroup"));
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure SelectedFields_Ungroup(Command)
	FieldsTablesUngroup("SelectedFields");
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS Filters

#Region FormTableItemsEventsHandlersFilters

&AtClient
Procedure FiltersChoice(Item, RowIdentifier, Field, StandardProcessing)
	StandardProcessing = False;
	ColumnName = Field.Name;
	If ExtendedMode <> 1 Then
		Return;
	EndIf;
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.ThisIsSection Then
		Return;
	EndIf;
	
	If ColumnName = "FiltersPresentation" Then // Change order.
		
		If TableRow.IsParameter Then
			Return;
		EndIf;
		If TableRow.IsFolder Then
			FieldsTablesChangeGroup("Filters", RowIdentifier, TableRow);
		Else
			FieldsTablesChange("Filters", RowIdentifier);
		EndIf;
		
	ElsIf ColumnName = "FiltersAccessPictureIndex" Then // Change quick access to filter.
		
		FiltersSelectAccessLevel("Filters", RowIdentifier, TableRow);
		
	ElsIf ColumnName = "FiltersValue" Then
		
		If TableRow.IsFolder Then
			Return;
		EndIf;
		If TableRow.Condition = DataCompositionComparisonType.Filled
			Or TableRow.Condition = DataCompositionComparisonType.NotFilled Then
			Return;
		EndIf;
		
		IsPeriod = (TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods"));
		If IsPeriod Then
			FiltersShowReriodSelection(TableRow);
		Else
			If TableRow.EnterByList Then
				FiltersShowListWithCheckBoxes(TableRow);
			Else
				StandardProcessing = True;
			EndIf;
		EndIf;
		
	ElsIf ColumnName = "FiltersValuePresentation" Then
		
		FilterSelectValueFromList(TableRow);
		
	ElsIf ColumnName = "FiltersCondition" Then
		
		If TableRow.IsFolder Then
			Return;
		EndIf;
		IsPeriod = (TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods"));
		If IsPeriod Then
			FiltersShowReriodSelection(TableRow);
		Else
			FiltersSelectComparisonType(TableRow);
		EndIf;
		
	ElsIf ColumnName = "FiltersTitle" Then
		
		StandardProcessing = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersBeforeAdditionBegin(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	
	If Not VariantNodeChangingMode Then
		CurrentRow = Items.Filters.CurrentData;
		If (CurrentRow = Undefined)
			Or (CurrentRow.IsParameter)
			Or (CurrentRow.ThisIsSection AND CurrentRow.DCIdentifier = "DataParameters") Then
			CurrentRow = Filters.GetItems()[1];
			Items.Filters.CurrentRow = CurrentRow.GetID();
		EndIf;
	EndIf;
	
	Handler = New NotifyDescription("FiltersAfterFieldSelection", ThisObject);
	FieldsTablesShowFieldSelection("Filters", Handler);
EndProcedure

&AtClient
Procedure FiltersAfterFieldSelection(AvailableKDSelectionField, ExecuteParameters) Export
	If AvailableKDSelectionField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldsTablesInsert("Filters", Type("DataCompositionFilterItem"), 0, Undefined);
	
	KDItem = Result.KDItem;
	KDItem.Use = True;
	KDItem.LeftValue = AvailableKDSelectionField.Field;
	KDItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	KDItem.UserSettingID = String(New UUID());
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	RefreshForm(Undefined, Undefined);
EndProcedure

&AtClient
Procedure FiltersBeforeDelete(Item, Cancel)
	TableRow = Item.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.ThisIsSection
		Or TableRow.IsParameter Then
		Cancel = True;
		Return;
	EndIf;
	FieldsTablesBeforeDeleting(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure Filters_Group(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesGroup, UpdateForm");
	Script.Insert("Action", "Group");
	Script.Insert("TableName", "Filters");
	Script.Insert("DCGroupType", Type("DataCompositionFilterItemGroup"));
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure Filters_Ungroup(Command)
	FieldsTablesUngroup("Filters");
EndProcedure

&AtClient
Procedure Filters_MoveUp(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "Filters");
	Script.Insert("Direction", -1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure Filters_MoveDown(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "Filters");
	Script.Insert("Direction", 1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure FiltersUseOnChange(Item)
	FieldsTablesChangeUsage("Filters");
EndProcedure

&AtClient
Procedure FiltersValueOnChange(Item)
	FieldsTablesChangeValue("Filters");
EndProcedure

&AtClient
Procedure FiltersTitleOnChange(Item)
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(TableRow.Title) Then
		TableRow.Title = TableRow.Presentation;
	EndIf;
	TableRow.TitlePredefined = (TableRow.Title <> TableRow.Presentation);
	
	If Not TableRow.IsParameter Then
		If TableRow.AccessPictureIndex = 1 Or TableRow.AccessPictureIndex = 3 Then
			KDItem.Presentation = "1";
		Else
			KDItem.Presentation = "";
		EndIf;
	EndIf;
	If TableRow.TitlePredefined Then
		KDItem.UserSettingPresentation = TableRow.Title;
	Else
		KDItem.UserSettingPresentation = "";
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersOnActivateRow(Item)
	TableRow = Items.Filters.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CanDeleteAndMove = True;
	If TableRow.ThisIsSection
		Or TableRow.IsParameter Then
		CanDeleteAndMove = False;
	EndIf;
	
	Items.Filters_Delete.Enabled  = CanDeleteAndMove;
	Items.Filters_Delete1.Enabled = CanDeleteAndMove;
	Items.Filters_Group.Enabled  = CanDeleteAndMove;
	Items.Filters_Group1.Enabled = CanDeleteAndMove;
	Items.Filters_Ungroup.Enabled  = CanDeleteAndMove;
	Items.Filters_Ungroup1.Enabled = CanDeleteAndMove;
	Items.Filters_MoveUp.Enabled  = CanDeleteAndMove;
	Items.Filters_MoveUp1.Enabled = CanDeleteAndMove;
	Items.Filters_MoveDown.Enabled  = CanDeleteAndMove;
	Items.Filters_MoveDown1.Enabled = CanDeleteAndMove;
	
	If Not TableRow.ThisIsSection AND Not TableRow.IsFolder Then
		If TableRow.Condition = DataCompositionComparisonType.InList
			Or TableRow.Condition = DataCompositionComparisonType.InListByHierarchy
			Or TableRow.Condition = DataCompositionComparisonType.NotInList
			Or TableRow.Condition = DataCompositionComparisonType.NotInListByHierarchy Then
			Items.FiltersValue.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		ElsIf TableRow.Condition = DataCompositionComparisonType.InHierarchy
			Or TableRow.Condition = DataCompositionComparisonType.NotInHierarchy Then
			Items.FiltersValue.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		ElsIf TableRow.ChoiceFoldersAndItems <> Undefined Then
			Items.FiltersValue.ChoiceFoldersAndItems = TableRow.ChoiceFoldersAndItems;
		Else
			Items.FiltersValue.ChoiceFoldersAndItems = FoldersAndItems.Auto;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS VariantStructure

#Region FormTableItemsEventsHandlersVariantStructure

&AtClient
Procedure VariantStructureOnActivateRow(Item)
	TableRow = Items.VariantStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CanAddInserted = True;
	CanGroup = True;
	CanOpen = True;
	CanDeleteAndMove = True;
	CanAddTablesAndCharts = False;
	
	Parent = TableRow.GetParent();
	CanMoveParent = (Parent <> Undefined
		AND Parent.Type <> "Settings"
		AND Parent.Type <> "StructureTableItemsCollection"
		AND Parent.Type <> "ChartStructureItemsCollection");
	HasAdjacent = TreeRowItems(VariantStructure, Parent).Count() > 1;
	
	AreSubordinates = (TableRow.GetItems().Count() > 0);
	If TableRow.Type = "Table"
		Or TableRow.Type = "Chart"
		Or TableRow.Type = "NestedObjectSettings" Then
		CanOpen = False;
		CanAddInserted = False;
	ElsIf TableRow.Type = "Settings"
		Or TableRow.Type = "StructureTableItemsCollection"
		Or TableRow.Type = "ChartStructureItemsCollection" Then
		CanOpen = False;
		CanDeleteAndMove = False;
		CanGroup = False;
	ElsIf TableRow.Type = "NestedObjectSettings" Then
		CanOpen = False;
		CanGroup = False;
	EndIf;
	
	If TableRow.Type = "Settings" Or TableRow.Type = "Group" Then
		CanAddTablesAndCharts = True;
	EndIf;
	
	Items.VariantStructure_Add.Enabled  = CanAddInserted;
	Items.VariantStructure_Add1.Enabled = CanAddInserted;
	Items.VariantStructure_Change.Enabled  = CanOpen;
	Items.VariantStructure_Change1.Enabled = CanOpen;
	Items.VariantStructure_AddTable.Enabled  = CanAddTablesAndCharts;
	Items.VariantStructure_AddTable1.Enabled = CanAddTablesAndCharts;
	Items.VariantStructure_AddChart.Enabled  = CanAddTablesAndCharts;
	Items.VariantStructure_AddChart1.Enabled = CanAddTablesAndCharts;
	Items.VariantStructure_Delete.Enabled  = CanDeleteAndMove;
	Items.VariantStructure_Delete1.Enabled = CanDeleteAndMove;
	Items.VariantStructure_Group.Enabled  = CanGroup;
	Items.VariantStructure_Group1.Enabled = CanGroup;
	Items.VariantStructure_MoveUpAndLeft.Enabled  = CanDeleteAndMove AND CanMoveParent AND CanAddInserted AND CanGroup;
	Items.VariantStructure_MoveUpAndLeft1.Enabled = CanDeleteAndMove AND CanMoveParent AND CanAddInserted AND CanGroup;
	Items.VariantStructure_MoveDownAndRight.Enabled  = CanDeleteAndMove AND AreSubordinates AND CanAddInserted AND CanGroup;
	Items.VariantStructure_MoveDownAndRight1.Enabled = CanDeleteAndMove AND AreSubordinates AND CanAddInserted AND CanGroup;
	Items.VariantStructure_MoveUp.Enabled  = CanDeleteAndMove AND HasAdjacent;
	Items.VariantStructure_MoveUp1.Enabled = CanDeleteAndMove AND HasAdjacent;
	Items.VariantStructure_MoveDown.Enabled  = CanDeleteAndMove AND HasAdjacent;
	Items.VariantStructure_MoveDown1.Enabled = CanDeleteAndMove AND HasAdjacent;
	
EndProcedure

&AtClient
Procedure VariantStructureSelection(Item, RowIdentifier, Field, StandardProcessing)
	StandardProcessing = False;
	If ExtendedMode <> 1 Then
		Return;
	EndIf;
	TableRow = Items.VariantStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.Type = "StructureTableItemsCollection"
		Or TableRow.Type = "ChartStructureItemsCollection"
		Or TableRow.Type = "Settings" Then
		Return;
	EndIf;
	ColumnName = Field.Name;
	If ColumnName = "VariantStructurePresentation" Then
		If TableRow.Type = "Table"
			Or TableRow.Type = "NestedObjectSettings" Then
			Return;
		EndIf;
		FieldsTablesChangeNodeVariantStructure("VariantStructure", RowIdentifier, TableRow);
	Else
		StandardProcessing = True;
	EndIf;
EndProcedure

&AtClient
Procedure VariantStructureBeforeBeginToAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
	If ExtendedMode = 0 Then
		Return;
	EndIf;
	If Not Items.VariantStructure_Add.Enabled Then
		Return;
	EndIf;
	
	VariantStructureAddGrouping(True);
EndProcedure

&AtClient
Procedure VariantStructure_Group(Command)
	If Not Items.VariantStructure_Group.Enabled Then
		Return;
	EndIf;
	VariantStructureAddGrouping(False);
EndProcedure

&AtClient
Procedure VariantStructureAddGrouping(InsideCurrent)
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("InsideCurrent", InsideCurrent);
	ExecuteParameters.Insert("Wrap", True);
	
	SettingsNodeID = Undefined;
	TableRow = Items.VariantStructure.CurrentData;
	If TableRow <> Undefined Then
		If Not InsideCurrent Then
			TableRow = TableRow.GetParent();
		EndIf;
		If InsideCurrent Then
			If TableRow.Type = "Settings" AND Not TableRow.CheckBoxAvailable Then
				ExecuteParameters.Wrap = False;
			ElsIf TableRow.GetItems().Count() > 1 Then
				ExecuteParameters.Wrap = False;
			EndIf;
		EndIf;
		While TableRow <> Undefined Do
			If TableRow.Type = "Settings"
				Or TableRow.Type = "NestedObjectSettings"
				Or TableRow.Type = "Group"
				Or TableRow.Type = "TableGrouping"
				Or TableRow.Type = "ChartGrouping" Then
				SettingsNodeID = TableRow.DCIdentifier;
				Break;
			EndIf;
			TableRow = TableRow.GetParent();
		EndDo;
	EndIf;
	
	Handler = New NotifyDescription("VariantStructureAddGroupingAfterFieldSelection", ThisObject, ExecuteParameters);
	FieldsTablesShowFieldSelection("VariantStructure", Handler, Undefined, SettingsNodeID);
EndProcedure

&AtClient
Procedure VariantStructureAddGroupingAfterFieldSelection(AvailableDCField, ExecuteParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	CurrentRow = Items.VariantStructure.CurrentData;
	
	RowsMovedToNewGrouping = New Array;
	If ExecuteParameters.Wrap Then
		If ExecuteParameters.InsideCurrent Then
			Found = CurrentRow.GetItems();
			For Each TransferredRow IN Found Do
				RowsMovedToNewGrouping.Add(TransferredRow);
			EndDo;
		Else
			RowsMovedToNewGrouping.Add(CurrentRow);
		EndIf;
	EndIf;
	
	// Add new grouping.
	Result = FieldsTablesInsert("VariantStructure", Type("DataCompositionGroup"), CurrentRow, ExecuteParameters.InsideCurrent);
	
	KDItem = Result.KDItem;
	KDItem.Use = True;
	KDItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	KDItem.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	If AvailableDCField = "<>" Then
		// Detailed records - you do not need to add a field.
		Presentation = NStr("en='<Detailed records>';ru='<Детальные записи>'");
	Else
		DCGroupingField = KDItem.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		DCGroupingField.Use = True;
		DCGroupingField.Field = AvailableDCField.Field;
		Presentation = String(AvailableDCField.Title);
	EndIf;
	
	TableRow = Result.TableRow;
	TableRow.Use = KDItem.Use;
	TableRow.Presentation = Presentation;
	TableRow.PictureIndex = 1;
	TableRow.CheckBoxAvailable = True;
	TableRow.Type = ReportsClientServer.RowSettingType(TypeOf(KDItem));
	
	If Not ExecuteParameters.InsideCurrent Then
		TableRow.Title = CurrentRow.Title;
		VariantStructureUpdateItemTitleInLinker(TableRow);
		CurrentRow.Title = "";
		VariantStructureUpdateItemTitleInLinker(CurrentRow);
	EndIf;
	
	// Move current grouping to a new one.
	For Each TransferredRow IN RowsMovedToNewGrouping Do
		Result = FieldsTablesMove("VariantStructure", TransferredRow, TableRow, Undefined, False);
	EndDo;
	
	// Bows.
	Items.VariantStructure.Expand(TableRow.GetID(), True);
	Items.VariantStructure.CurrentRow = TableRow.GetID();
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure VariantStructure_AddTable(Command)
	If Not Items.VariantStructure_AddTable.Enabled Then
		Return;
	EndIf;
	GetTableOrChart(Type("DataCompositionTable"));
EndProcedure

&AtClient
Procedure VariantStructure_AddChart(Command)
	If Not Items.VariantStructure_AddChart.Enabled Then
		Return;
	EndIf;
	GetTableOrChart(Type("DataCompositionChart"));
EndProcedure

&AtClient
Procedure GetTableOrChart(PointType)
	CurrentRow = Items.VariantStructure.CurrentData;
	
	Result = FieldsTablesInsert("VariantStructure", PointType, CurrentRow, True);
	
	If PointType = Type("DataCompositionChart") Then
		KDItem = Result.KDItem;
		KDItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
		SetOutputParameter(KDItem, "ChartType.ValuesConnectionBySeries", ChartValuesBySeriesConnectionType.EdgesConnection);
		SetOutputParameter(KDItem, "ChartType.ValuesConnectingLinesBySeries");
		SetOutputParameter(KDItem, "ChartType.ValuesBySeriesLinkColor", WebColors.Gainsboro);
		SetOutputParameter(KDItem, "ChartType.AntialiasingMode", ChartSplineMode.SmoothCurve);
		SetOutputParameter(KDItem, "ChartType.TranslucencyMode", ChartSemitransparencyMode.Use);
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	RefreshForm(Undefined, Undefined);
EndProcedure

&AtClient
Procedure VariantStructureDragAndDropStart(Item, DragParameters, StandardProcessing)
	// Check common conditions.
	If ExtendedMode = 0 Then
		StandardProcessing = False;
		Return;
	EndIf;
	// Check source.
	TableRow = VariantStructure.FindByID(DragParameters.Value);
	If TableRow = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	If TableRow.Type = "ChartStructureItemsCollection"
		Or TableRow.Type = "StructureTableItemsCollection"
		Or TableRow.Type = "Settings" Then
		StandardProcessing = False;
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure VariantStructureDragAndDropCheck(Item, DragParameters, StandardProcessing, RecipientIdentifier, Field)
	// Check common conditions.
	If RecipientIdentifier = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Check source.
	TableRow = VariantStructure.FindByID(DragParameters.Value);
	If TableRow = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Receiver check.
	NewParent = VariantStructure.FindByID(RecipientIdentifier);
	If NewParent = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	If NewParent.Type = "Table"
		Or NewParent.Type = "Chart" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	// Check the compatibility of source with receiver.
	AllowedOnlyGroupsPresence = False;
	If NewParent.Type = "StructureTableItemsCollection"
		Or NewParent.Type = "ChartStructureItemsCollection"
		Or NewParent.Type = "TableGrouping"
		Or NewParent.Type = "ChartGrouping" Then
		AllowedOnlyGroupsPresence = True;
	EndIf;
	
	If AllowedOnlyGroupsPresence
		AND TableRow.Type <> "Group"
		AND TableRow.Type <> "TableGrouping"
		AND TableRow.Type <> "ChartGrouping" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	CollectionsCollections = New Array;
	CollectionsCollections.Add(TableRow.GetItems());
	Quantity = 1;
	While Quantity > 0 Do
		Collection = CollectionsCollections[0];
		Quantity = Quantity - 1;
		CollectionsCollections.Delete(0);
		For Each InsertedTableRow IN Collection Do
			If InsertedTableRow = NewParent Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			If AllowedOnlyGroupsPresence
				AND InsertedTableRow.Type <> "Group"
				AND InsertedTableRow.Type <> "TableGrouping"
				AND InsertedTableRow.Type <> "ChartGrouping" Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			CollectionsCollections.Add(InsertedTableRow.GetItems());
			Quantity = Quantity + 1;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure VariantStructureDragAndDrop(Item, DragParameters, StandardProcessing, RecipientIdentifier, Field)
	// All checks are passed.
	StandardProcessing = False;
	
	TableRow = VariantStructure.FindByID(DragParameters.Value);
	
	KDNode    = FieldsTablesFindNode(ThisObject, "VariantStructure", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	
	OldParent = TableRow.GetParent();
	NewParent = VariantStructure.FindByID(RecipientIdentifier);
	If OldParent = NewParent Then
		Return; // Work is complete.
	EndIf;
	
	If OldParent = Undefined Then
		RowOldParent = VariantStructure.GetItems();
		OldDCParent = KDNode;
	Else
		RowOldParent = OldParent.GetItems();
		OldDCParent = KDNode.GetObjectByID(OldParent.DCIdentifier);
	EndIf;
	
	If TypeOf(OldDCParent) = Type("DataCompositionChartStructureItemCollection")
		Or TypeOf(OldDCParent) = Type("DataCompositionTableStructureItemCollection") Then
		DCRowOldParent = OldDCParent;
	Else
		DCRowOldParent = OldDCParent.Structure;
	EndIf;
	
	NewRowParent = NewParent.GetItems();
	NewDCParent = KDNode.GetObjectByID(NewParent.DCIdentifier);
	If TypeOf(NewDCParent) = Type("DataCompositionChartStructureItemCollection")
		Or TypeOf(NewDCParent) = Type("DataCompositionTableStructureItemCollection") Then
		DCRowNewParent = NewDCParent;
	Else
		DCRowNewParent = NewDCParent.Structure;
	EndIf;
	
	Result = FieldsTablesCopyRecursively(KDNode, TableRow, NewRowParent, KDItem, DCRowNewParent);
	
	If DragParameters.Action = DragAction.Move Then
		RowOldParent.Delete(TableRow);
		DCRowOldParent.Delete(KDItem);
	EndIf;
	
	Items.VariantStructure.Expand(NewParent.GetID(), True);
	Items.VariantStructure.CurrentRow = Result.TreeRow.GetID(); //NewTableRow.GetID();
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure VariantStructureUseOnChange(Item)
	FieldsTablesChangeUsage("VariantStructure");
EndProcedure

&AtClient
Procedure VariantStructureTitleOnChange(Item)
	TableRow = Items.VariantStructure.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	VariantStructureUpdateItemTitleInLinker(TableRow);
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure VariantStructure_MoveUp(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "VariantStructure");
	Script.Insert("Direction", -1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure VariantStructure_MoveDown(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "VariantStructure");
	Script.Insert("Direction", 1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure VariantStructure_Change(Command)
	ItemTable = Items.VariantStructure;
	Field = ItemTable.CurrentItem;
	StandardProcessing = True;
	RowIdentifier = ItemTable.CurrentRow;
	VariantStructureSelection(ItemTable, RowIdentifier, Field, StandardProcessing);
EndProcedure

&AtClient
Procedure VariantStructureBeforeDelete(Item, Cancel)
	Cancel = True;
	If ExtendedMode = 0 Or Not Items.VariantStructure_Delete.Enabled Then
		Return;
	EndIf;
	
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesDeleteRows, UpdateForm");
	Script.Insert("Action", "Delete");
	Script.Insert("TableName", "VariantStructure");
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure VariantStructure_MoveUpAndLeft(Command)
	If Not Items.VariantStructure_MoveUpAndLeft.Enabled Then
		Return;
	EndIf;
	TableRowUp = Items.VariantStructure.CurrentData;
	If TableRowUp = Undefined Then
		Return;
	EndIf;
	TableRowDown = TableRowUp.GetParent();
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("Mode",              "UpAndLeft");
	ExecuteParameters.Insert("TableRowUp", TableRowUp);
	ExecuteParameters.Insert("TableRowDown",  TableRowDown);
	VariantStructure_Move(-1, ExecuteParameters);
EndProcedure

&AtClient
Procedure VariantStructure_MoveDownAndRight(Command)
	If Not Items.VariantStructure_MoveDownAndRight.Enabled Then
		Return;
	EndIf;
	TableRowDown = Items.VariantStructure.CurrentData;
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("Mode",              "DownAndRight");
	ExecuteParameters.Insert("TableRowUp", Undefined);
	ExecuteParameters.Insert("TableRowDown",  TableRowDown);
	
	SubordinateRows = TableRowDown.GetItems();
	Quantity = SubordinateRows.Count();
	If Quantity = 0 Then
		Return;
	ElsIf Quantity = 1 Then
		ExecuteParameters.TableRowUp = SubordinateRows[0];
		VariantStructure_Move(-1, ExecuteParameters);
	Else
		List = New ValueList;
		For LineNumber = 1 To Quantity Do
			SubordinatedRow = SubordinateRows[LineNumber-1];
			List.Add(SubordinatedRow.GetID(), SubordinatedRow.Presentation);
		EndDo;
		Handler = New NotifyDescription("VariantStructure_Move", ThisObject, ExecuteParameters);
		ShowChooseFromList(Handler, List);
	EndIf;
	
EndProcedure

&AtClient
Procedure VariantStructure_Move(Result, ExecuteParameters) Export
	If Result <> -1 Then
		If TypeOf(Result) <> Type("ValueListItem") Then
			Return;
		EndIf;
		TableRowUp = VariantStructure.FindByID(Result.Value);
	Else
		TableRowUp = ExecuteParameters.TableRowUp;
	EndIf;
	TableRowDown = ExecuteParameters.TableRowDown;
	
	// 0. Remember before which item you should insert an upper row.
	RowsDown = TableRowDown.GetItems();
	IndexOf = RowsDown.IndexOf(TableRowUp);
	RowsIDsArrayDown = New Array;
	For Each TableRow IN RowsDown Do
		If TableRow = TableRowUp Then
			Continue;
		EndIf;
		RowsIDsArrayDown.Add(TableRow.GetID());
	EndDo;
	
	// 1. Move the bottom row to the level with the top row.
	Result1 = FieldsTablesMove("VariantStructure", TableRowUp, TableRowDown.GetParent(), TableRowDown, False);
	TableRowUp = Result1.TreeRow;
	
	// 2. Remember what rows should be moved.
	RowsUp = TableRowUp.GetItems();
	
	// 3. Rows exchange.
	For Each TableRow IN RowsUp Do
		Result2 = FieldsTablesMove("VariantStructure", TableRow, TableRowDown, Undefined, False);
	EndDo;
	For Each TableRowID IN RowsIDsArrayDown Do
		TableRow = VariantStructure.FindByID(TableRowID);
		Result3 = FieldsTablesMove("VariantStructure", TableRow, TableRowUp, Undefined, False);
	EndDo;
	
	// 4. Move an upper row to a lower one.
	RowsUp = TableRowUp.GetItems();
	If RowsUp.Count() - 1 < IndexOf Then
		InsertBeforeWhat = Undefined;
	Else
		InsertBeforeWhat = RowsUp[IndexOf];
	EndIf;
	Result4 = FieldsTablesMove("VariantStructure", TableRowDown, TableRowUp, InsertBeforeWhat, False);
	TableRowDown = Result4.TreeRow;
	
	// Bows.
	If ExecuteParameters.Mode = "DownAndRight" Then
		CurrentRow = TableRowDown;
	Else
		CurrentRow = TableRowUp;
	EndIf;
	CurrentStringIdentifier = CurrentRow.GetID();
	Items.VariantStructure.Expand(CurrentStringIdentifier, True);
	Items.VariantStructure.CurrentRow = CurrentStringIdentifier;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS GroupsContent

#Region FormTableItemsEventsHandlersGroupingContent

&AtClient
Procedure GroupingContentSelection(Item, RowIdentifier, Field, StandardProcessing)
	ColumnName = Field.Name;
	If ColumnName = "GroupingContentPresentation" Then
		StandardProcessing = False;
		TableRow = Items.GroupingContent.CurrentData;
		If TableRow = Undefined Then
			Return;
		EndIf;
		FieldsTablesChange("GroupingContent", RowIdentifier);
	EndIf;
EndProcedure

&AtClient
Procedure GroupingContentBeforeBeginToAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	Cancel = True;
	Handler = New NotifyDescription("GroupingContentAfterFieldSelection", ThisObject);
	FieldsTablesShowFieldSelection("GroupingContent", Handler);
EndProcedure

&AtClient
Procedure GroupingContentAfterFieldSelection(AvailableDCField, ExecuteParameters) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	Result = FieldsTablesInsert("GroupingContent", Type("DataCompositionGroupField"), 0, False);
	
	KDItem = Result.KDItem;
	KDItem.Use = True;
	KDItem.Field          = AvailableDCField.Field;
	
	TableRow = Result.TableRow;
	TableRow.Use  = KDItem.Use;
	TableRow.Presentation  = AvailableDCField.Title;
	TableRow.GroupType = KDItem.GroupType;
	TableRow.AdditionType  = KDItem.AdditionType;
	TableRow.Picture       = PictureLib.Attribute;
	
	If AvailableDCField.Resource Then
		TableRow.Picture = PictureLib.Resource;
	ElsIf AvailableDCField.Table Then
		TableRow.Picture = PictureLib.NestedTable;
	ElsIf AvailableDCField.Folder Then
		TableRow.Picture = PictureLib.Folder;
	Else
		TableRow.Picture = PictureLib.Attribute;
	EndIf;
	
	TypeInformation = ReportsClientServer.TypesAnalysis(AvailableDCField.ValueType, False);
	If TypeInformation.ContainsTypePeriod Or TypeInformation.ContainsTypeDate Then
		TableRow.ShowAdditionType = True;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure GroupingContentGroupTypeOnChange(Item)
	FieldsTablesChangeGroupType("GroupingContent");
EndProcedure

&AtClient
Procedure GroupingContentAdditionTypeOnChange(Item)
	FieldsTablesChangeGroupType("GroupingContent");
EndProcedure

&AtClient
Procedure GroupingContentBeforeDelete(Item, Cancel)
	FieldsTablesBeforeDeleting(Item.Name, Cancel);
EndProcedure

&AtClient
Procedure GroupingContent_MoveUp(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "GroupingContent");
	Script.Insert("Direction", -1);
	
	RunScript(Undefined, Script);
EndProcedure

&AtClient
Procedure GroupingContent_MoveDown(Command)
	Script = New Structure;
	Script.Insert("Steps", "FieldsTablesDefineSelectedRows, FieldsTablesMoveRows");
	Script.Insert("Action", "Move");
	Script.Insert("TableName", "GroupingContent");
	Script.Insert("Direction", 1);
	
	RunScript(Undefined, Script);
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// BUTTONS EVENTS

#Region FormCommandsHandlers

&AtClient
Procedure CloseAndGenerate(Command)
	WriteAndClose(True);
EndProcedure

&AtClient
Procedure CloseWithoutGenerating(Command)
	WriteAndClose(False);
EndProcedure

&AtClient
Procedure DefaultSettings(Command)
	FillingParameters = New Structure;
	FillingParameters.Insert("Event", New Structure);
	FillingParameters.Event.Insert("Name", "DefaultSettings");
	FillingParameters.Insert("UserSettingsModified", True);
	FillingParameters.Insert("ResetUserSettings", True);
	QuickSettingsFillClient(FillingParameters);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Enabled commands

&AtClient
Procedure Attachable_Command(Command)
	// Extension mechanisms.
	Result = False;
	If CommonUseClient.SubsystemExists("StandardSubsystems.ReportsMailing") Then
		ModuleReportSendingClient = CommonUseClient.CommonModule("ReportMailingClient");
		ModuleReportSendingClient.ReportFormCommandHandler(ThisObject, Command, Result);
	EndIf;
	ReportsClientOverridable.CommandHandler(ThisObject, Command, Result);
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure WriteAndClose(Regenerate)
	NotifyChoice(ChoiceResult(Regenerate));
EndProcedure

&AtClient
Function ChoiceResult(Regenerate)
	SelectionResultGenerated = True;
	
	If VariantNodeChangingMode AND Not Regenerate Then
		Return Undefined;
	EndIf;
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("Event", New Structure("Name", "SettingsForm"));
	ChoiceResult.Insert("Regenerate", Regenerate);
	ChoiceResult.Insert("VariantModified", False);
	ChoiceResult.Insert("UserSettingsModified", False);
	ChoiceResult.Insert("SettingsFormExtendedMode", ExtendedMode);
	ChoiceResult.Insert("SettingsFormPageName", Items.SettingPages.CurrentPage.Name);
	
	If VariantModified Then
		ChoiceResult.VariantModified = True;
		ChoiceResult.Insert("DCSettings", SettingsComposer.Settings);
	EndIf;
	
	If VariantModified Or UserSettingsModified Then
		ChoiceResult.UserSettingsModified = True;
		ChoiceResult.Insert("DCUserSettings", SettingsComposer.UserSettings);
	EndIf;
	
	If VariantModified AND ExtendedMode = 1 Then
		ChoiceResult.Insert("ResetUserSettings", True);
	EndIf;
	
	Return ChoiceResult;
EndFunction

&AtClient
Procedure SelectPeriodFromDropdownList(Result, ChoiceParameters) Export
	If Result = Undefined Then
		Return; // Cancel selection.
	EndIf;
	
	If Result = -1 Then // Start of selection.
		// Read parameters for generating a list from the saved period value.
		ChoiceParameters.Insert("BeginOfPeriod", ChoiceParameters.Value.StartDate);
		ChoiceParameters.Insert("Variant",       ChoiceParameters.Value.Variant);
		InitialValueIndex = Undefined;
	ElsIf TypeOf(Result.Value) = Type("Structure") Then
		// Read parameters to generate list from the selected value.
		ChoiceParameters.Insert("BeginOfPeriod", Result.Value.BeginOfPeriod);
		ChoiceParameters.Insert("Variant",       Result.Value.Variant);
		InitialValueIndex = Result.Value.InitialValueIndex;
	Else
		// Import selection result.
		ImportPeriodSelectionResultFromDropdownList(Result, ChoiceParameters);
		Return;
	EndIf;
	
	// Generate a selection list.
	If ChoiceParameters.Variant = Undefined Or ChoiceParameters.Variant = StandardPeriodVariant.Custom Then
		
		PeriodsList = ReportsClientServer.FixedPeriodsList(ChoiceParameters.BeginOfPeriod, ChoiceParameters.PeriodKind);
		
		If InitialValueIndex = Undefined Then
			InitialValueIndex = PeriodsList.FindByValue(ChoiceParameters.BeginOfPeriod);
		EndIf;
		
		NavigationItemDescription = New Structure;
		NavigationItemDescription.Insert("BeginOfPeriod",            PeriodsList[0].Value);
		NavigationItemDescription.Insert("Variant",                  Undefined);
		NavigationItemDescription.Insert("InitialValueIndex", 0);
		PeriodsList[0].Value = NavigationItemDescription;
		
		NavigationItemDescription = New Structure;
		NavigationItemDescription.Insert("BeginOfPeriod",            PeriodsList[8].Value);
		NavigationItemDescription.Insert("Variant",                  Undefined);
		NavigationItemDescription.Insert("InitialValueIndex", 8);
		PeriodsList[8].Value = NavigationItemDescription;
		
		If Not ChoiceParameters.Property("StandardPeriodVariantType") Then
			ChoiceParameters.Insert("StandardPeriodVariantType", ReportsClientServer.SetPeriodKindToStandard(ChoiceParameters.PeriodKind));
		EndIf;
		
		NavigationItemDescription = New Structure;
		NavigationItemDescription.Insert("BeginOfPeriod",            ChoiceParameters.BeginOfPeriod);
		NavigationItemDescription.Insert("Variant",                  ChoiceParameters.StandardPeriodVariantType);
		NavigationItemDescription.Insert("InitialValueIndex", Undefined);
		PeriodsList.Add(NavigationItemDescription, NStr("en='Relative...';ru='Относительный...'"));
		
	Else
		
		PeriodsList = ReportsClientServer.CalculatingPeriodsList(ChoiceParameters.PeriodKind);
		
		If InitialValueIndex = Undefined Then
			InitialValueIndex = PeriodsList.FindByValue(ChoiceParameters.Variant);
		EndIf;
		
		NavigationItemDescription = New Structure;
		NavigationItemDescription.Insert("BeginOfPeriod",            ChoiceParameters.BeginOfPeriod);
		NavigationItemDescription.Insert("Variant",                  Undefined);
		NavigationItemDescription.Insert("InitialValueIndex", Undefined);
		PeriodsList.Add(NavigationItemDescription, NStr("en='Fixed...';ru='Фиксированный...'"));
		
	EndIf;
	
	If InitialValueIndex = Undefined Then
		InitialValueIndex = PeriodsList.Count() - 1;
	EndIf;
	
	ClientVariables.Insert("SelectPeriodFromDropdownList", New Structure);
	ClientVariables.SelectPeriodFromDropdownList.Insert("ChoiceParameters", ChoiceParameters);
	ClientVariables.SelectPeriodFromDropdownList.Insert("PeriodsList", PeriodsList);
	ClientVariables.SelectPeriodFromDropdownList.Insert("InitialValueIndex", InitialValueIndex);
	If Result = -1 Then
		BeginPeriodSelectionFromDropdownList();
	Else
		AttachIdleHandler("BeginPeriodSelectionFromDropdownList", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure BeginPeriodSelectionFromDropdownList()
	If ClientVariables.Property("SelectPeriodFromDropdownList") Then
		Context = ClientVariables.SelectPeriodFromDropdownList;
		ClientVariables.Delete("SelectPeriodFromDropdownList");
		Handler = New NotifyDescription("SelectPeriodFromDropdownList", ThisObject, Context.ChoiceParameters);
		ShowChooseFromList(Handler, Context.PeriodsList, Context.ChoiceParameters.Item, Context.InitialValueIndex);
	EndIf;
EndProcedure

&AtClient
Procedure ImportPeriodSelectionResultFromDropdownList(Result, ChoiceParameters)
	Value = ChoiceParameters.Value;
	
	// Write the selection result to the form data and DC custom settings.
	If TypeOf(Result.Value) = Type("StandardPeriodVariant") Then
		ThisObject[ChoiceParameters.AuthorPresentationActualName] = ?(IsBlankString(Result.Presentation), String(Result.Value), Result.Presentation);
		Value.Variant = Result.Value;
	Else
		BeginOfPeriod = ReportsClientServer.ReportPeriodStart(ChoiceParameters.PeriodKind, Result.Value);
		EndOfPeriod  = ReportsClientServer.ReportEndOfPeriod(ChoiceParameters.PeriodKind, Result.Value);
		
		ThisObject[ChoiceParameters.AuthorPresentationActualName] = Result.Presentation;
		
		Value.Variant = StandardPeriodVariant.Custom;
		Value.StartDate    = BeginOfPeriod;
		Value.EndDate = EndOfPeriod;
	EndIf;
	
	ThisObject[ChoiceParameters.ValueName] = Value;
	
	DCUsersSetting = FindElementsUsersSetup(ChoiceParameters.ItemIdentificator);
	If ChoiceParameters.IsParameter Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	DCUsersSetting.Use = True;
	
	UserSettingsModified = True;
EndProcedure

&AtClient
Function FindElementsUsersSetup(ItemIdentificator)
	// For custom settings, data composition IDs
	//  are stored as they can not be stored as a reference (value copy is in progress).
	If ItemIdentificator = "Sort" Then
		If VariantNodeChangingMode Then
			RootNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
			Return RootNode.Order;
		ElsIf ExtendedMode = 1 Then
			Return SettingsComposer.Settings.Order;
		Else
			ItemIdentificator = ItemIdentificator;
		EndIf;
	ElsIf ItemIdentificator = "SelectedFields" Then
		If VariantNodeChangingMode Then
			RootNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
			Return RootNode.Selection;
		ElsIf ExtendedMode = 1 Then
			Return SettingsComposer.Settings.Selection;
		Else
			ItemIdentificator = ItemIdentificator;
		EndIf;
	ElsIf ItemIdentificator = "Filters" Then
		If VariantNodeChangingMode Then
			RootNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
			Return RootNode.Filter;
		ElsIf ExtendedMode = 1 Then
			Return SettingsComposer.Settings.Filter;
		Else
			ItemIdentificator = ItemIdentificator;
		EndIf;
	ElsIf ItemIdentificator = "VariantStructure" Then
		If ExtendedMode = 1 Then
			Return SettingsComposer.Settings;
		Else
			Return SettingsComposer.UserSettings;
		EndIf;
	EndIf;
	DCIdentifier = FastSearchOfUserSettings.Get(ItemIdentificator);
	Return SettingsComposer.UserSettings.GetObjectByID(DCIdentifier);
EndFunction

&AtClient
Function FindAdditionalItemSettings(ItemIdentificator)
	// For custom settings, data composition IDs
	//  are stored as they can not be stored as a reference (value copy is in progress).
	AllAdditionalSettings = CommonUseClientServer.StructureProperty(SettingsComposer.UserSettings.AdditionalProperties, "FormItems");
	If AllAdditionalSettings = Undefined Then
		Return Undefined;
	Else
		Return AllAdditionalSettings[ItemIdentificator];
	EndIf;
EndFunction

&AtClient
Procedure QuickSettingsFillClient(FillingParameters)
	ErrorInfo = Undefined;
	Try
		QuickSettingsFill(FillingParameters);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		ErrorPresentation = ReportsClientServer.BriefErrorDescriptionOfReportFormation(ErrorInfo);
		ShowMessageBox(, ErrorPresentation);
	EndIf;
EndProcedure

&AtClient
Procedure SetOutputParameter(KDItem, Name, Value = Undefined, Use = True)
	DCParameter = KDItem.OutputParameters.FindParameterValue(New DataCompositionParameter(Name));
	If DCParameter = Undefined Then
		Return;
	EndIf;
	If Value <> Undefined Then
		DCParameter.Value = Value;
	EndIf;
	If Use <> Undefined Then
		DCParameter.Use = Use;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - Script execution.

&AtClient
Procedure RunScript(CaseUser, Script) Export
	// Advantages of a script execution:
	//   Isolation of handlers.
	//     The current step may have no information about the next or the previous step.
	//   Single notification handler.
	//     Min client application interface of a form.
	//     Allows not to "expand" stack invertedly
	//     after closing the dialog with user.
	//   User-friendly code grouping.
	//     Code that calls the dialog and processes response is located in one function.
	//   A simple sequence of steps.
	//   User-friendly steps disabling.
	
	If Not Script.Property("CurrentStep") Then
		If TypeOf(Script.Steps) = Type("String") Then
			Script.Steps = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Script.Steps, ",", True, True);
		EndIf;
		Script.Insert("StepsToBorder", Script.Steps.UBound());
		Script.Insert("NextStepIndex", 0);
		Script.Insert("CurrentStep", Undefined);
		Script.Insert("CurrentStepRefiner", "");
		Script.Insert("WasStopping", False);
		Script.Insert("Handler", New NotifyDescription("RunScript", ThisObject, Script));
		Script.Insert("ErrorText", "");
		FindNextStep(Script);
	EndIf;
	
	While ExecuteStep(CaseUser, Script) Do
		If Not FindNextStep(Script) Then
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(Script.ErrorText) Then
		ShowMessageBox(, Script.ErrorText);
		Script.ErrorText = "";
	EndIf;
EndProcedure

&AtClient
Function FindNextStep(Script)
	If Script.NextStepIndex > Script.StepsToBorder Then
		Return False;
	EndIf;
	Script.CurrentStep = Script.Steps.Get(Script.NextStepIndex);
	Script.CurrentStepRefiner = "";
	Script.NextStepIndex = Script.NextStepIndex + 1;
	Return True;
EndFunction

&AtClient
Function ExecuteStep(CaseUser, Script)
	
	If Script.CurrentStep = "FieldsTablesDefineSelectedRows" Then
		Return FieldsTablesDefineSelectedRows(CaseUser, Script);
	
	ElsIf Script.CurrentStep = "InputTitle" Then
		Return InputTitle(CaseUser, Script);
	
	ElsIf Script.CurrentStep = "GroupFieldsTables" Then
		Return GroupFieldsTables(CaseUser, Script);
	
	ElsIf Script.CurrentStep = "FieldsTablesShiftRows" Then
		Return FieldsTablesShiftRows(CaseUser, Script);
	
	ElsIf Script.CurrentStep = "FieldsTablesDeleteRows" Then
		Return FieldsTablesDeleteRows(CaseUser, Script);
	
	ElsIf Script.CurrentStep = "RefreshForm" Then
		Return RefreshForm(CaseUser, Script);
	
	Else
		Script.ErrorText = StrReplace(NStr("en='Error in script: Unknown step % 1.';ru='Ошибка в сценарии: Неизвестный шаг ""%1"".'"), "%1", Script.CurrentStep);
		Return False;
	
	EndIf;
	
	// Alternatives to these conditions branches:
	//  Compute() - it is unacceptable to use only for code minimizing;
	//  PerformNotificationProcessing() - not profitable as only procedures
	//      are supported and therefore the next step should be launched from the previous step;
	//      T.e. disappears such advantage as handlers isolation from the asynchronous logic.
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client - Steps of a script execution.

&AtClient
Function RefreshForm(CaseUser, Script)
	FillingParameters = New Structure("Event", New Structure("Name", "AfterVariantContentChange"));
	Result = QuickSettingsFill(FillingParameters);
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	Return True; // Continue script.
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client - Tables of fields (script execution supported).

&AtClient
Function FieldsTablesDefineSelectedRows(CaseUser, Script)
	ItemTable = Items[Script.TableName];
	TableAttribute = ThisObject[Script.TableName];
	Script.Insert("TreeRows", New Array);
	If Script.Action = "Move" Or Script.Action = "Group" Then
		Script.Insert("CurrentParent", -1);
	EndIf;
	SelectedRows = SortArray(ItemTable.SelectedRows, SortDirection.Asc);
	For Each RowIdentifier IN SelectedRows Do
		TreeRow = TableAttribute.FindByID(RowIdentifier);
		If Script.TableName = "Filters" Then
			If TreeRow.ThisIsSection Then
				Return False; // Pause script.
			ElsIf TreeRow.IsParameter Then
				If Script.Action = "Move" Then
					Script.ErrorText = StrReplace(NStr("en='Parameters can not be transferred.';ru='Параметры не могут быть перемещены.'"), "%1", TreeRow.Presentation);
				ElsIf Script.Action = "Group" Then
					Script.ErrorText = NStr("en='Parameters can not be group participants.';ru='Параметры не могут быть участниками групп.'");
				ElsIf Script.Action = "Delete" Then
					Script.ErrorText = NStr("en='Parameters can not be deleted.';ru='Параметры не могут быть удалены.'");
				EndIf;
				Return False; // Pause script.
			EndIf;
		EndIf;
		If Script.Action = "Move" Or Script.Action = "Group" Then
			Parent = TreeRow.GetParent();
			If Script.CurrentParent = -1 Then
				Script.CurrentParent = Parent;
			ElsIf Script.CurrentParent <> Parent Then
				If Script.Action = "Move" Then
					Script.ErrorText = NStr("en='Selected items can not be transferred as they belong to different parents.';ru='Выбранные элементы не могут быть перемещены, поскольку они принадлежат разным родителям.'");
				ElsIf Script.Action = "Group" Then
					Script.ErrorText = NStr("en='Selected items can not be grouped as they belong to different parents.';ru='Выбранные элементы не могут быть сгруппированы, поскольку они принадлежат разным родителям.'");
				EndIf;
				Return False; // Pause script.
			EndIf;
		EndIf;
		Script.TreeRows.Add(TreeRow);
	EndDo;
	
	If Script.TreeRows.Count() = 0 Then
		Script.ErrorText = NStr("en='Select items.';ru='Выберите элементы.'");
		Return False; // Pause script.
	EndIf;
	
	Return True; // Continue script.
EndFunction

&AtClient
Function InputTitle(CaseUser, Script)
	
	If Script.CurrentStepRefiner = "" Then // First call
		
		ShowInputString(Script.Handler, , NStr("en='Group name';ru='Название группы'"), 100, False);
		Script.CurrentStepRefiner = "RowInput";
		Return False; // Pause script.
		
	ElsIf Script.CurrentStepRefiner = "RowInput" Then // Handler of answer to a question.
		
		If TypeOf(CaseUser) = Type("String") Then
			Script.Insert("GroupDescription", CaseUser);
			Return True; // Continue script.
		Else
			Return False; // Cancel a script
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function GroupFieldsTables(CaseUser, Script)
	CurrentParent = Script.CurrentParent;
	ItemTable = Items[Script.TableName];
	KDNode = FieldsTablesFindNode(ThisObject, Script.TableName, Undefined);
	
	If Script.CurrentParent = Undefined Then
		TableAttribute = ThisObject[Script.TableName];
		If Script.TableName = "Filters" AND Not VariantNodeChangingMode Then
			CurrentParent = TableAttribute.GetItems()[1];
		Else
			CurrentParent = TableAttribute;
		EndIf;
		CurrentDCParent = KDNode;
	ElsIf TypeOf(CurrentParent.DCIdentifier) <> Type("DataCompositionID") Then
		CurrentDCParent = KDNode;
	Else
		CurrentDCParent = KDNode.GetObjectByID(CurrentParent.DCIdentifier);
	EndIf;
	ParentRows = CurrentParent.GetItems();
	DCParentRows = CurrentDCParent.Items;
	
	// Checks are complete. Add group to parent's parent.
	Groups = FieldsTablesInsert(Script.TableName, Script.DCGroupType, 0, False);
	
	DCGroup = Groups.KDItem;
	DCGroup.Use = True;
	NewDCItemsCollection = DCGroup.Items;
	
	TreeGroup = Groups.TableRow;
	TreeGroup.Use = DCGroup.Use;
	TreeGroup.IsFolder = True;
	TreeRowsNewCollection = TreeGroup.GetItems();
	
	If Script.TableName = "Filters" Then
		TreeGroup.Presentation = String(DCGroup.GroupType);
		TreeGroup.PictureIndex = -1;
		TreeGroup.AccessPictureIndex = 5;
		TreeGroup.Title = TreeGroup.Presentation;
	Else
		DCGroup.Title = Script.GroupDescription;
		TreeGroup.Presentation = Script.GroupDescription;
		TreeGroup.PictureIndex = 0;
	EndIf;
	
	For Each OldTreeRow IN Script.TreeRows Do
		OldDCItem = KDNode.GetObjectByID(OldTreeRow.DCIdentifier);
		FieldsTablesCopyRecursively(KDNode, OldTreeRow, TreeRowsNewCollection, OldDCItem, NewDCItemsCollection);
		ParentRows.Delete(OldTreeRow);
		DCParentRows.Delete(OldDCItem);
	EndDo;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	Return True; // Continue script.
EndFunction

&AtClient
Function FieldsTablesShiftRows(CaseUser, Script)
	CurrentParent = Script.CurrentParent;
	ItemTable = Items[Script.TableName];
	KDNode = FieldsTablesFindNode(ThisObject, Script.TableName, Undefined);
	
	If Script.CurrentParent = Undefined Then
		TableAttribute = ThisObject[Script.TableName];
		If Script.TableName = "Filters" AND Not VariantNodeChangingMode Then
			CurrentParent = TableAttribute.GetItems()[1];
		Else
			CurrentParent = TableAttribute;
		EndIf;
		CurrentDCParent = KDNode;
	ElsIf TypeOf(CurrentParent.DCIdentifier) <> Type("DataCompositionID") Then
		CurrentDCParent = KDNode;
	Else
		CurrentDCParent = KDNode.GetObjectByID(CurrentParent.DCIdentifier);
	EndIf;
	ParentRows = CurrentParent.GetItems();
	DCParentRows = DCObjectItems(KDNode, CurrentDCParent);
	
	RowsUpperBorder = ParentRows.Count() - 1;
	RowsHighlighted = Script.TreeRows.Count();
	
	// Array of the highlighted rows towards the movement:
	//  If you move the rows to +, then bypass from big to small;
	//  If in -, then upwards is required.
	MoveAscending = (Script.Direction < 0);
	
	For Number = 1 To RowsHighlighted Do
		If MoveAscending Then 
			IndexInArray = Number - 1;
		Else
			IndexInArray = RowsHighlighted - Number;
		EndIf;
		
		TreeRow = Script.TreeRows[IndexInArray];
		KDItem = KDNode.GetObjectByID(TreeRow.DCIdentifier);
		
		IndexInTree = ParentRows.IndexOf(TreeRow);
		WhereRowWillBe = IndexInTree + Script.Direction;
		If WhereRowWillBe < 0 Then // Move "to the end".
			ParentRows.Move(IndexInTree, RowsUpperBorder - IndexInTree);
			DCParentRows.Move(KDItem, RowsUpperBorder - IndexInTree);
		ElsIf WhereRowWillBe > RowsUpperBorder Then // Move "to the beginning".
			ParentRows.Move(IndexInTree, -IndexInTree);
			DCParentRows.Move(KDItem, -IndexInTree);
		Else
			ParentRows.Move(IndexInTree, Script.Direction);
			DCParentRows.Move(KDItem, Script.Direction);
		EndIf;
	EndDo;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	Return True; // Continue script.
EndFunction

&AtClient
Function FieldsTablesDeleteRows(CaseUser, Script)
	
	TableAttribute = ThisObject[Script.TableName];
	
	For Each TableRow IN Script.TreeRows Do
		
		KDNode = FieldsTablesFindNode(ThisObject, Script.TableName, TableRow);
		KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
		
		ParentRow = TableRow.GetParent();
		DCParent = FindDCObject(KDNode, ParentRow);
		
		DeleteFromTo = TreeRowItems(TableAttribute, ParentRow);
		DeleteFromTo.Delete(TableRow);
		
		FromToDeleteDC = DCObjectItems(KDNode, DCParent);
		FromToDeleteDC.Delete(KDItem);
		
	EndDo;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	Return True; // Continue script.
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client - Table of parameters and filters.

&AtClient
Procedure FiltersSelectAccessLevel(TableName, RowIdentifier, TableRow)
	Context = New Structure("TableName, RowIdentifier", TableName, RowIdentifier);
	Handler = New NotifyDescription("FiltersAccessLevelSelectionEnd", ThisObject, Context);
	
	List = New ValueList;
	List.Add(2, NStr("en='In the report header';ru='В шапке отчета'"), , PictureLib.QuickAccess);
	If Not TableRow.IsParameter Then
		List.Add(1, NStr("en='Only a check box in the record header';ru='Только флажок в шапке отчета'"), , PictureLib.RapidAccessWithCheckBox);
	EndIf;
	List.Add(4, NStr("en='In the report settings';ru='В настройках отчета'"), , PictureLib.Attribute);
	If Not TableRow.IsParameter Then
		List.Add(3, NStr("en='Only a check box in the report settings';ru='Только флажок в настройках отчета'"), , PictureLib.UsualAccessWithCheckBox);
	EndIf;
	List.Add(5, NStr("en='Do not show';ru='Не показывать'"), , PictureLib.ReportHiddenSetting);
	
	ShowChooseFromMenu(Handler, List, Items[TableName]);
EndProcedure

&AtClient
Procedure FiltersAccessLevelSelectionEnd(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, Context.TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.AccessPictureIndex = Result.Value;
	
	If Result.Value = 1 Or Result.Value = 2 Then
		KDItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	ElsIf Result.Value = 3 Or Result.Value = 4 Then
		KDItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	Else
		KDItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If Not TableRow.IsParameter Then
		If Result.Value = 1 Or Result.Value = 3 Then
			KDItem.Presentation = "1";
		Else
			KDItem.Presentation = "";
		EndIf;
	EndIf;
	
	
	If KDItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		KDItem.UserSettingID = "";
	ElsIf Not ValueIsFilled(KDItem.UserSettingID) Then
		KDItem.UserSettingID = New UUID;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersShowReriodSelection(TableRow)
	Context = New Structure;
	Context.Insert("RowIdentifier", TableRow.GetID());
	Handler = New NotifyDescription("FiltersPeriodSelectionEnd", ThisObject, Context);
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = TableRow.Value;
	Dialog.Show(Handler);
EndProcedure

&AtClient
Procedure FiltersPeriodSelectionEnd(Period, Context) Export
	If Period = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Value = Period;
	TableRow.Condition = ReportsClientServer.GetKindOfStandardPeriod(TableRow.Value);
	
	If TableRow.IsParameter Then
		KDItem.Value = TableRow.Value;
	Else
		KDItem.RightValue = TableRow.Value;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersShowListWithCheckBoxes(TableRow)
	AdditionalSettings = TableRow.Additionally;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("RowIdentifier", TableRow.GetID());
	Handler = New NotifyDescription("FiltersEndInputInListWithCheckBoxes", ThisObject, HandlerParameters);
	
	FormParameters = New Structure("Marked,
		|ValuesForSelection, LimitSelectionWithSpecifiedValues,
		|TypeDescription, SelectionParameters, Presentation");
	FormParameters.marked = ReportsClientServer.ValueList(TableRow.Value);
	FormParameters.Presentation = TableRow.Presentation;
	
	FormParameters.Insert("UniqueKey", KDItem.UserSettingID);
	
	FillPropertyValues(FormParameters, AdditionalSettings, , "ChoiceParameters");
	
	FormParameters.ChoiceParameters = New Array;
	
	// Add the fixed selection parameters.
	For Each ChoiceParameter IN AdditionalSettings.ChoiceParameters Do
		If IsBlankString(ChoiceParameter.Name) Then
			Continue;
		EndIf;
		FormParameters.ChoiceParameters.Add(ChoiceParameter);
	EndDo;
	
	Links = DisabledLinks.FindRows(New Structure("SubordinateIdentifierInForm", HandlerParameters.RowIdentifier));
	For Each Link IN Links Do
		RowLeading = Filters.FindByID(Link.LeadingIdentifierInForm);
		If RowLeading = Undefined Then
			Continue;
		EndIf;
		If Not RowLeading.Use Then
			Continue;
		EndIf;
		If Link.LinkType = "ByType" AND RowLeading.Condition = DataCompositionComparisonType.Equal Then
			FormParameters.Insert("TypeRestriction", TypeOf(RowLeading.Value));
		ElsIf Link.LinkType = "ParametersSelect" Then
			FormParameters.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateNameParameter, RowLeading.Value));
		ElsIf Link.LinkType = "ByMetadata" Then
			If Not Link.LeadingType.ContainsType(TypeOf(RowLeading.Value)) Then
				Continue;
			EndIf;
			FormParameters.ChoiceParameters.Add(New ChoiceParameter(Link.SubordinateNameParameter, RowLeading.Value));
		EndIf;
	EndDo;
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("CommonForm.EnterValuesListWithCheckBoxes", FormParameters, ThisObject, , , , Handler, Block);
	
EndProcedure

&AtClient
Procedure FiltersEndInputInListWithCheckBoxes(ChoiceResult, Context) Export
	If TypeOf(ChoiceResult) <> Type("ValueList") Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	AdditionalSettings = TableRow.Additionally;
	
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
			FillPropertyValues(AdditionalSettings.ValuesForSelection.Add(), ListItemInForm);
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
	If TypeOf(KDItem) = Type("DataCompositionFilterItem") Then
		KDItem.RightValue = ValueListInDAS;
	Else
		KDItem.Value = ValueListInDAS;
	EndIf;
	TableRow.Value = ValueListInDAS;
	
	// Select the Use check box.
	KDItem.Use = True;
	TableRow.Use = True;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersSelectComparisonType(TableRow)
	If TableRow.IsParameter Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowIdentifier", TableRow.GetID());
	Handler = New NotifyDescription("FiltersComparisonTypeSelectionEnd", ThisObject, Context);
	
	TypeInformation = ReportsClientServer.TypesAnalysis(TableRow.ValueType, False);
	
	List = New ValueList;
	
	If TypeInformation.LimitedLength Then
		
		List.Add(DataCompositionComparisonType.Equal);
		List.Add(DataCompositionComparisonType.NotEqual);
		
		List.Add(DataCompositionComparisonType.InList);
		List.Add(DataCompositionComparisonType.NotInList);
		
		If TypeInformation.ContainsObjectTypes Then
			
			List.Add(DataCompositionComparisonType.InListByHierarchy); // NStr("en='In list including subordinate';ru='В списке включая подчиненные'")
			List.Add(DataCompositionComparisonType.NotInListByHierarchy); // NStr("en='Not in the list including subordinate';ru='Не в списке включая подчиненные'").
			
			List.Add(DataCompositionComparisonType.InHierarchy); // NStr("en='In group';ru='В группе'")
			List.Add(DataCompositionComparisonType.NotInHierarchy); // NStr("en='Not in the group';ru='Не в группе'")
			
		EndIf;
		
		If TypeInformation.PrimitiveTypesQuantity > 0 Then
			
			List.Add(DataCompositionComparisonType.Less);
			List.Add(DataCompositionComparisonType.LessOrEqual);
			
			List.Add(DataCompositionComparisonType.Greater);
			List.Add(DataCompositionComparisonType.GreaterOrEqual);
			
		EndIf;
		
	EndIf;
	
	If TypeInformation.ContainsTypeOfRow Then
		
		List.Add(DataCompositionComparisonType.Contains);
		List.Add(DataCompositionComparisonType.NotContains);
		
		List.Add(DataCompositionComparisonType.Like);
		List.Add(DataCompositionComparisonType.NotLike);
		
		List.Add(DataCompositionComparisonType.BeginsWith);
		List.Add(DataCompositionComparisonType.NotBeginsWith);
		
	EndIf;
	
	If TypeInformation.LimitedLength Then
		
		List.Add(DataCompositionComparisonType.Filled);
		List.Add(DataCompositionComparisonType.NotFilled);
		
	EndIf;
	
	ShowChooseFromMenu(Handler, List, Items.Filters);
	
EndProcedure

&AtClient
Procedure FiltersComparisonTypeSelectionEnd(Result, Context) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Condition  = Result.Value;
	KDItem.ComparisonType = Result.Value;
	
	WasInputInList = TableRow.EnterByList;
	BecameInputInList = False;
	If TableRow.Condition = DataCompositionComparisonType.InList
		Or TableRow.Condition = DataCompositionComparisonType.InListByHierarchy
		Or TableRow.Condition = DataCompositionComparisonType.NotInList
		Or TableRow.Condition = DataCompositionComparisonType.NotInListByHierarchy Then
		Items.FiltersValue.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		BecameInputInList = True;
	ElsIf TableRow.Condition = DataCompositionComparisonType.InHierarchy
		Or TableRow.Condition = DataCompositionComparisonType.NotInHierarchy Then
		Items.FiltersValue.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Else
		Items.FiltersValue.ChoiceFoldersAndItems = TableRow.ChoiceFoldersAndItems;
	EndIf;
	
	If WasInputInList <> BecameInputInList Then
		TableRow.EnterByList = BecameInputInList;
		If WasInputInList Then
			If TypeOf(KDItem.RightValue) = Type("ValueList")
				AND KDItem.RightValue.Count() > 0 Then
				KDItem.RightValue = KDItem.RightValue[0].Value;
			Else
				KDItem.RightValue = Undefined;
			EndIf;
		Else
			KDItem.RightValue = ReportsClientServer.ValueList(KDItem.RightValue);
		EndIf;
		TableRow.Value = KDItem.RightValue;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FilterSelectValueFromList(TableRow)
	If TableRow.Additionally = Undefined Then
		Return;
	EndIf;
	ValuesForSelection = CommonUseClientServer.StructureProperty(TableRow.Additionally, "ValuesForSelection");
	If TypeOf(ValuesForSelection) <> Type("ValueList") Or ValuesForSelection.Count() = 0 Then
		Return;
	EndIf;
	Context = New Structure;
	Context.Insert("RowIdentifier", TableRow.GetID());
	Handler = New NotifyDescription("FiltersEndValuesFromListSelection", ThisObject, Context);
	ShowChooseFromMenu(Handler, ValuesForSelection, Items.Filters);
EndProcedure

&AtClient
Procedure FiltersEndValuesFromListSelection(Result, Context) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	TableRow = Filters.FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, "Filters", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	// Reflect changes on value.
	If TypeOf(KDItem) = Type("DataCompositionFilterItem") Then
		KDItem.RightValue = Result.Value;
	Else
		KDItem.Value = Result.Value;
	EndIf;
	TableRow.ValuePresentation = Result.Presentation;
	
	// Select the Use check box.
	KDItem.Use = True;
	TableRow.Use = True;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client - Fields tables (functional part).

&AtClient
Procedure FieldsTablesUngroup(TableName)
	ItemTable = Items[TableName];
	TableAttribute = ThisObject[TableName];
	SelectedRows = ItemTable.SelectedRows;
	SelectedRows = CommonUseClientServer.CollapseArray(SelectedRows); // For a platform.
	If SelectedRows.Count() <> 1 Then
		ShowMessageBox(, NStr("en='Select one group.';ru='Выберите одну группу.'"));
		Return;
	EndIf;
	
	TreeGroup = TableAttribute.FindByID(SelectedRows[0]);
	If TreeGroup = Undefined Or Not TreeGroup.IsFolder Then
		ShowMessageBox(, NStr("en='Select group.';ru='Выберите группу.'"));
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, Undefined);
	DCGroup = KDNode.GetObjectByID(TreeGroup.DCIdentifier);
	
	Parent = TreeGroup.GetParent();
	If Parent = Undefined Then
		Parent = TableAttribute;
	EndIf;
	TreeRowsNewCollection = Parent.GetItems();
	
	DCParent = DCGroup.Parent;
	If DCParent = Undefined Then
		DCParent = KDNode;
	EndIf;
	NewDCItemsCollection = DCParent.Items;
	
	IndexOf = TreeRowsNewCollection.IndexOf(TreeGroup);
	DCIndex = NewDCItemsCollection.IndexOf(DCGroup);
	
	CurrentRow = Undefined;
	
	ParentRows = TreeGroup.GetItems();
	DCParentRows = DCGroup.Items;
	For Each OldTreeRow IN ParentRows Do
		OldDCItem = KDNode.GetObjectByID(OldTreeRow.DCIdentifier);
		BrokenLines = FieldsTablesCopyRecursively(KDNode, OldTreeRow, TreeRowsNewCollection, OldDCItem, NewDCItemsCollection, IndexOf, DCIndex);
		If CurrentRow = Undefined Then
			CurrentRow = BrokenLines.TreeRow;
		EndIf;
	EndDo;
	
	TreeRowsNewCollection.Delete(TreeGroup);
	NewDCItemsCollection.Delete(DCGroup);
	
	If CurrentRow <> Undefined Then
		ItemTable.CurrentRow = CurrentRow.GetID();
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesBeforeDeleting(TableName, Cancel)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem <> Undefined Then
		KDNode.Items.Delete(KDItem);
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChange(TableName, RowIdentifier)
	Context = New Structure("TableName, RowIdentifier", TableName, RowIdentifier);
	Handler = New NotifyDescription("FieldsTablesChangeEnd", ThisObject, Context);
	
	Table = ThisObject[TableName];
	TableRow = Table.FindByID(RowIdentifier);
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	
	FieldsTablesShowFieldSelection(TableName, Handler, ?(TableName = "Filters", KDItem.LeftValue, KDItem.Field));
EndProcedure

&AtClient
Procedure FieldsTablesChangeEnd(AvailableDCField, Context) Export
	If AvailableDCField = Undefined Then
		Return;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, Context.TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	TableRow.Presentation = AvailableDCField.Title;
	If Context.TableName = "Filters" Then
		KDItem.LeftValue = AvailableDCField.Field;
	Else
		KDItem.Field = AvailableDCField.Field;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
	
	RefreshForm(Undefined, Undefined);
EndProcedure

&AtClient
Procedure FieldsTablesChangeUsage(TableName)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	If CommonUseClientServer.StructureProperty(TableRow, "DisplayCheckbox") = False Then
		TableRow.Use = True;
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	KDItem.Use = TableRow.Use;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChangeValue(TableName)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	If TableRow.IsParameter Then
		KDItem.Value = TableRow.Value;
	Else
		KDItem.RightValue = TableRow.Value;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChangeGroupType(TableName)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	If TableRow.ShowAdditionType Then
		KDItem.AdditionType = TableRow.AdditionType;
	Else
		KDItem.GroupType = TableRow.GroupType;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChangeGroup(TableName, RowIdentifier, TableRow)
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	
	Context = New Structure("TableName, RowIdentifier", TableName, RowIdentifier);
	Handler = New NotifyDescription("FieldsTablesChangeGroupEnd", ThisObject, Context);
	
	If TableName = "Filters" Then
		List = New ValueList;
		ReportsClientServer.AddUniqueValueInList(List, DataCompositionFilterItemsGroupType.AndGroup, "", False);
		ReportsClientServer.AddUniqueValueInList(List, DataCompositionFilterItemsGroupType.OrGroup, "", False);
		ReportsClientServer.AddUniqueValueInList(List, DataCompositionFilterItemsGroupType.NotGroup, "", False);
		ShowChooseFromMenu(Handler, List);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("TitleGroups", KDItem.Title);
		FormParameters.Insert("Location", KDItem.Placement);
		
		Block = FormWindowOpeningMode.LockOwnerWindow;
		
		OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectedFieldsGroup", FormParameters, ThisObject, True, , , Handler, Block);
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChangeGroupEnd(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	TableRow = ThisObject[Context.TableName].FindByID(Context.RowIdentifier);
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, Context.TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	If Context.TableName = "Filters" Then
		KDItem.GroupType = Result.Value;
		TableRow.Presentation = String(Result.Value);
		If Not TableRow.TitlePredefined Then
			TableRow.Title = TableRow.Presentation;
		EndIf;
	Else
		KDItem.Title = Result.TitleGroups;
		KDItem.Placement = Result.Location;
		TableRow.Presentation = KDItem.Title;
		If KDItem.Placement <> DataCompositionFieldPlacement.Auto Then
			TableRow.Presentation = TableRow.Presentation + " (" + String(KDItem.Placement) + ")";
		EndIf;
	EndIf;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		VariantModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure FieldsTablesChangeNodeVariantStructure(TableName, RowIdentifier, TableRow)
	Context = New Structure("TableName, RowIdentifier", TableName, RowIdentifier);
	Handler = New NotifyDescription("FieldsTablesChangeVariantStructureNodeEnd", ThisObject, Context);
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", SettingsComposer);
	FormParameters.Insert("OptionName", OptionName);
	FormParameters.Insert("CurrentCDHostIdentifier", TableRow.DCIdentifier);
	FormParameters.Insert("CurrentCDHostType", TableRow.Type);
	If TableRow.Type = "Chart" Then
		FormParameters.Insert("Title", NStr("en='Set the %2 report chart.';ru='Настройка диаграммы отчета ""%2""'"));
	Else
		FormParameters.Insert("Title", NStr("en='Set %1 grouping of the %2 report.';ru='Настройка группировки ""%1"" отчета ""%2""'"));
	EndIf;
	FormParameters.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		FormParameters.Title,
		TableRow.Presentation,
		OptionName
	);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ReportSettings", FormParameters, ThisObject, , , , Handler);
EndProcedure

&AtClient
Procedure FieldsTablesChangeVariantStructureNodeEnd(Result, Context) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	ClientResult = QuickSettingsFill(Result);
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, ClientResult);
EndProcedure

&AtClient
Function FieldsTablesInsert(TableName, PointType, CurrentRow, ReturnRows)
	If CurrentRow = Undefined Then
		Return Undefined;
	EndIf;
	
	ItemTable  = Items[TableName];
	TableAttribute = ThisObject[TableName];
	KDNode = FieldsTablesFindNode(ThisObject, TableName);
	
	If CurrentRow = 0 Then
		CurrentRow = ItemTable.CurrentData;
	EndIf;
	
	If CurrentRow = Undefined Then
		
		WhereInsert = TableAttribute.GetItems();
		IndexOf = Undefined;
		KDItem = Undefined;
		WhereToInsertDC = DCObjectItems(KDNode, CurrentRow);
		DCIndex = Undefined;
		
	Else
		
		KDItem = FindDCObject(KDNode, CurrentRow);
		If ReturnRows = Undefined Then
			ReturnRows = CommonUseClientServer.StructureProperty(CurrentRow, "IsFolder", False);
		EndIf;
		
		If KDItem = Undefined Then
			ReturnRows = True;
		EndIf;
		
		If ReturnRows Then
			WhereInsert = CurrentRow.GetItems();
			IndexOf = Undefined;
			WhereToInsertDC = DCObjectItems(KDNode, KDItem);
			DCIndex = Undefined
		Else // Insertion to one level with a row.
			ParentRow = CurrentRow.GetParent();
			If ParentRow = Undefined Then
				WhereInsert = TableAttribute.GetItems();
			Else
				WhereInsert = ParentRow.GetItems();
			EndIf;
			IndexOf = WhereInsert.IndexOf(CurrentRow) + 1;
			DCParent = FindDCObject(KDNode, ParentRow);
			WhereToInsertDC = DCObjectItems(KDNode, DCParent);
			DCIndex = WhereToInsertDC.IndexOf(KDItem) + 1;
		EndIf;
		
	EndIf;
	
	If IndexOf = Undefined Then
		NewRow = WhereInsert.Add();
	Else
		NewRow = WhereInsert.Insert(IndexOf);
	EndIf;
	
	If ReportsClientServer.OnAddToCollectionNeedToSpecifyPointType(TypeOf(WhereToInsertDC)) Then
		If IndexOf = Undefined Then
			NewDCItem = WhereToInsertDC.Add(PointType);
		Else
			NewDCItem = WhereToInsertDC.Insert(IndexOf, PointType);
		EndIf;
	Else
		If IndexOf = Undefined Then
			NewDCItem = WhereToInsertDC.Add();
		Else
			NewDCItem = WhereToInsertDC.Insert(IndexOf);
		EndIf;
	EndIf;
	ItemTable.CurrentRow = NewRow.GetID();
	NewRow.DCIdentifier = KDNode.GetIDByObject(NewDCItem);
	
	Result = New Structure("TableRow, KDItem");
	Result.TableRow = NewRow;
	Result.KDItem = NewDCItem;
	Return Result;
EndFunction

&AtClient
Function FieldsTablesMove(TableName, TableRow, Parent, InsertBeforeWhat, KeepCopy)
	ItemTable = Items[TableName];
	TableAttribute = ThisObject[TableName];
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	
	If Parent = Undefined Then
		Parent = TableAttribute;
		DCParent = KDNode;
	Else
		DCParent = KDNode.GetObjectByID(Parent.DCIdentifier);
	EndIf;
	
	WhereInsert = Parent.GetItems();
	WhereToInsertDC = DCObjectItems(KDNode, DCParent);
	
	If InsertBeforeWhat = Undefined Then
		IndexOf   = Undefined;
		DCIndex = Undefined;
	Else
		BeforeWhatInsertDC = KDNode.GetObjectByID(InsertBeforeWhat.DCIdentifier);
		IndexOf   = WhereInsert.IndexOf(InsertBeforeWhat);
		DCIndex = WhereToInsertDC.IndexOf(BeforeWhatInsertDC);
	EndIf;
	
	Result = New Structure("TreeRow, DCRow");
	
	DCItemsSearch = New Map;
	Result.DCRow = ReportsClientServer.CopyRecursive(KDNode, KDItem, WhereToInsertDC, DCIndex, DCItemsSearch);
	
	TablesRowsSearch = New Map;
	Result.TreeRow = ReportsClientServer.CopyRecursive(Undefined, TableRow, WhereInsert, IndexOf, TablesRowsSearch);
	
	For Each KeyAndValue IN TablesRowsSearch Do
		OldRow = KeyAndValue.Key;
		NewRow = KeyAndValue.Value;
		NewRow.DCIdentifier = DCItemsSearch.Get(OldRow.DCIdentifier);
	EndDo;
	
	If Not KeepCopy Then
		OldParent = TableRow.GetParent();
		If OldParent = Undefined Then
			RowOldParent = TableAttribute.GetItems();
			OldDCParent = KDNode;
		Else
			RowOldParent = OldParent.GetItems();
			OldDCParent = KDNode.GetObjectByID(OldParent.DCIdentifier);
		EndIf;
		
		DCRowOldParent = DCObjectItems(KDNode, OldDCParent);
		
		RowOldParent.Delete(TableRow);
		DCRowOldParent.Delete(KDItem);
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function FindDCObject(KDNode, TableRow)
	If TableRow = Undefined Or TypeOf(TableRow.DCIdentifier) <> Type("DataCompositionID") Then
		Return Undefined;
	Else
		Return KDNode.GetObjectByID(TableRow.DCIdentifier);
	EndIf;
EndFunction

&AtClient
Function DCObjectItems(KDNode, DCObject)
	If DCObject = Undefined Then
		DCObject = KDNode;
	EndIf;
	ObjectType = TypeOf(DCObject);
	If ObjectType = Type("DataCompositionSettings")
		Or ObjectType = Type("DataCompositionGroup")
		Or ObjectType = Type("DataCompositionTableGroup")
		Or ObjectType = Type("DataCompositionChartGroup") Then
		Return DCObject.Structure;
	ElsIf ObjectType = Type("DataCompositionTableStructureItemCollection")
		Or ObjectType = Type("DataCompositionChartStructureItemCollection") Then
		Return DCObject;
	Else
		Return DCObject.Items;
	EndIf;
EndFunction

&AtClient
Function TreeRowItems(FormTree, TreeRow)
	If TreeRow = Undefined Then
		TreeRow = FormTree;
	EndIf;
	Return TreeRow.GetItems();
EndFunction

&AtClient
Procedure FieldsTablesChangeSortingDirection(TableName, Direction)
	TableRow = Items[TableName].CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	KDNode = FieldsTablesFindNode(ThisObject, TableName, TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	// Fill in optional parameters.
	If Direction = Undefined Then
		If KDItem.OrderType = DataCompositionSortDirection.Asc Then
			Direction = DataCompositionSortDirection.Desc;
		Else
			Direction = DataCompositionSortDirection.Asc;
		EndIf;
	EndIf;
	
	// Change sorting direction.
	KDItem.OrderType = Direction;
	TableRow.Direction = Direction;
	
	UserSettingsModified = True;
	If Not ValueIsFilled(KDNode.UserSettingID) Then
		VariantModified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FieldsTablesShowFieldSelection(TableName, Handler, DCField = Undefined, DCNodeIdentifier = Undefined)
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", SettingsComposer);
	FormParameters.Insert("Mode", TableName);
	FormParameters.Insert("DCField", DCField);
	FormParameters.Insert("CurrentCDHostIdentifier", ?(DCNodeIdentifier = Undefined, CurrentCDHostIdentifier, DCNodeIdentifier));
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ReportFieldSelection", FormParameters, ThisObject, True, , , Handler, Block);
EndProcedure

&AtClient
Function FieldsTablesCopyRecursively(KDNode, WhatCopy, WhereInsert, WhatToCopyDC, WhereToInsertDC, IndexOf = Undefined, DCIndex = Undefined)
	Result = New Structure("TreeRow, DCRow");
	
	DCItemsSearch = New Map;
	Result.DCRow = ReportsClientServer.CopyRecursive(KDNode, WhatToCopyDC, WhereToInsertDC, DCIndex, DCItemsSearch);
	
	TablesRowsSearch = New Map;
	Result.TreeRow = ReportsClientServer.CopyRecursive(Undefined, WhatCopy, WhereInsert, IndexOf, TablesRowsSearch);
	
	For Each KeyAndValue IN TablesRowsSearch Do
		OldRow = KeyAndValue.Key;
		NewRow = KeyAndValue.Value;
		NewRow.DCIdentifier = DCItemsSearch.Get(OldRow.DCIdentifier);
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure VariantStructureUpdateItemTitleInLinker(TableRow)
	KDNode = FieldsTablesFindNode(ThisObject, "VariantStructure", TableRow);
	KDItem = KDNode.GetObjectByID(TableRow.DCIdentifier);
	If KDItem = Undefined Then
		Return;
	EndIf;
	
	UseTitle = ValueIsFilled(TableRow.Title);
	
	DCParameterValue = KDItem.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If DCParameterValue <> Undefined Then
		DCParameterValue.Use = True;
		If UseTitle Then
			DCParameterValue.Value = DataCompositionTextOutputType.Output;
		Else
			DCParameterValue.Value = DataCompositionTextOutputType.DontOutput;
		EndIf;
	EndIf;
	
	DCParameterValue = KDItem.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If DCParameterValue <> Undefined Then
		DCParameterValue.Use = True;
		DCParameterValue.Value = TableRow.Title;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client or server

&AtClientAtServerNoContext
Function IsFolder(PointType)
	If PointType = Type("DataCompositionSelectedFieldGroup")
		Or PointType = Type("DataCompositionFilterItemGroup")
		Or PointType = Type("DataCompositionGroup")
		Or PointType = Type("DataCompositionNestedObjectSettings")
		Or PointType = Type("DataCompositionTableStructureItemCollection")
		Or PointType = Type("DataCompositionChartStructureItemCollection") Then
		Return True;
	EndIf;
	Return False;
EndFunction

&AtClientAtServerNoContext
Function TypeDescriptionsDeletePrimitive(InitialTypeDescription)
	DeductionTypes = New Array;
	If InitialTypeDescription.ContainsType(Type("String")) Then
		DeductionTypes.Add(Type("String"));
	EndIf;
	If InitialTypeDescription.ContainsType(Type("Date")) Then
		DeductionTypes.Add(Type("Date"));
	EndIf;
	If InitialTypeDescription.ContainsType(Type("Number")) Then
		DeductionTypes.Add(Type("Number"));
	EndIf;
	If DeductionTypes.Count() = 0 Then
		Return InitialTypeDescription;
	EndIf;
	Return New TypeDescription(InitialTypeDescription, , DeductionTypes);
EndFunction

&AtClientAtServerNoContext
Function FieldsTablesFindNode(ThisObject, TableName, TableRow = Undefined, DCNodeIdentifier = Undefined)
	If ThisObject.ExtendedMode = 1 Then
		If DCNodeIdentifier = Undefined Then
			DCNodeIdentifier = ThisObject.CurrentCDHostIdentifier;
		EndIf;
		If DCNodeIdentifier = Undefined Then
			RootNode = ThisObject.SettingsComposer.Settings;
		Else
			RootNode = ThisObject.SettingsComposer.Settings.GetObjectByID(DCNodeIdentifier);
			If TypeOf(RootNode) = Type("DataCompositionNestedObjectSettings") Then
				RootNode = RootNode.Settings;
			EndIf;
		EndIf;
		If TableName = "Sort" Then
			Return RootNode.Order;
		ElsIf TableName = "SelectedFields" Then
			Return RootNode.Selection;
		ElsIf TableName = "Filters" Then
			If TableRow = Undefined Or Not TableRow.IsParameter Then
				Return RootNode.Filter;
			Else
				Return RootNode.DataParameters;
			EndIf;
		ElsIf TableName = "GroupingContent" Then
			Return RootNode.GroupFields;
		ElsIf TableName = "Appearance" Then
			Return RootNode.ConditionalAppearance;
		ElsIf TableName = "VariantStructure" Then
			Return RootNode;
		Else
			Raise StrReplace(NStr("en='Changing the %1 table nodes is not supported.';ru='Изменение узлов таблицы ""%1"" не поддерживается.'"), "%1", TableName);
		EndIf;
	Else
		If TableName = "VariantStructure" Then
			Return ThisObject.SettingsComposer.UserSettings;
		EndIf;
		DCIdentifier = ThisObject.FastSearchOfUserSettings.Get(TableName);
		If DCIdentifier = Undefined Then
			Return Undefined;
		Else
			Return ThisObject.SettingsComposer.UserSettings.GetObjectByID(DCIdentifier);
		EndIf;
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function SortArray(SourceArray, SortDirection = Undefined)
	List = New ValueList;
	List.LoadValues(SourceArray);
	List.SortByValue(SortDirection);
	Return List.UnloadValues();
EndFunction

&AtClientAtServerNoContext
Function FindVariantSetting(ThisObject, ItemIdentificator)
	VariantSettingSearch = ThisObject.QuickSearchVariantSettings.Get(ItemIdentificator);
	If VariantSettingSearch = Undefined Then
		Return Undefined;
	EndIf;
	RootDCNode = ThisObject.SettingsComposer.Settings.GetObjectByID(VariantSettingSearch.DCNodeIdentifier);
	Result = New Structure("DCNode, KDItem");
	Result.KDNode = RootDCNode[VariantSettingSearch.CollectionName];
	Result.KDItem = Result.KDNode.GetObjectByID(VariantSettingSearch.DCItemID);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Function QuickSettingsFill(Val FillingParameters)
	
	// Insert default values for mandatory keys of the filling parameters.
	QuickSettingsFinishFillingParameters(FillingParameters);
	
	// Call a predefined module.
	If ReportSettings.Events.BeforeFillingQuickSettingsPanel Then
		ReportObject = ReportsServer.ReportObject(ReportSettings);
		ReportObject.BeforeFillingQuickSettingsPanel(ThisObject, FillingParameters);
	Else
		ReportsOverridable.BeforeFillingQuickSettingsPanel(ThisObject, FillingParameters);
	EndIf;
	
	// Save state before the beginning of change.
	QuickSettingsRememberState(FillingParameters);
	
	// Write new variant settings and custom settings in the linker.
	QuickSettingsLoadSettingsToLinker(FillingParameters);
	
	// Receive information from DC
	OutputConditions = New Structure;
	OutputConditions.Insert("OnlyCustom", ExtendedMode = 0);
	OutputConditions.Insert("OnlyQuick",          False);
	OutputConditions.Insert("CurrentCDHostIdentifier", CurrentCDHostIdentifier);
	Information = ReportsServer.ExtendedInformationAboutSettings(SettingsComposer, ThisObject, OutputConditions);
	
	// Delete items of old settings.
	QuickSettingsDeleteOldItemsAndCommands(FillingParameters);
	
	// Add items of actual settings and import values.
	QuickSettingsCreateControlItemsAndLoadValues(FillingParameters, Information);
	
	// Add items of actual settings and import values.
	AdvancedSettingsLoadValues(FillingParameters, Information);
	
	// Links.
	RegisterDisabledLinks(Information);
	
	// Save state before the beginning of change.
	QuickSettingsRestoreState(FillingParameters);
	
	// Title and items properties.
	VisibleEnabledCorrectness(FillingParameters.Event.Name);
	
	// Call a predefined module.
	If ReportSettings.Events.AfterFillingQuickSettingsPanel Then
		ReportObject = ReportsServer.ReportObject(ReportSettings);
		ReportObject.AfterFillingQuickSettingsPanel(ThisObject, FillingParameters);
	Else
		ReportsOverridable.AfterFillingQuickSettingsPanel(ThisObject, FillingParameters);
	EndIf;
	
	If ReportSettings.Property("ReportObject") Then
		ReportSettings.Delete("ReportObject");
	EndIf;
	
	Return FillingParameters.Result;
EndFunction

&AtServer
Procedure VisibleEnabledCorrectness(EventName = "")
	
	// Items visible.
	Items.VariantStructureCommands_Add.Visible  = (ExtendedMode = 1);
	Items.VariantStructureCommands_Add1.Visible = (ExtendedMode = 1);
	Items.VariantStructureCommands_Change.Visible  = (ExtendedMode = 1);
	Items.VariantStructureCommands_Change1.Visible = (ExtendedMode = 1);
	Items.VariantStructureCommands_MovementByHierarchy.Visible  = (ExtendedMode = 1);
	Items.VariantStructureCommands_MovementByHierarchy1.Visible = (ExtendedMode = 1);
	Items.VariantStructureCommands_MovementInsideParent.Visible  = (ExtendedMode = 1);
	Items.VariantStructureCommands_MovementInsideParent1.Visible = (ExtendedMode = 1);
	Items.VariantStructure.ChangeRowSet  = (ExtendedMode = 1);
	Items.VariantStructure.ChangeRowOrder = (ExtendedMode = 1);
	Items.VariantStructure.EnableStartDrag = (ExtendedMode = 1);
	Items.VariantStructure.EnableDrag       = (ExtendedMode = 1);
	Items.VariantStructure.Header              = (ExtendedMode = 1);
	Items.VariantStructureTitle.Visible = (ExtendedMode = 1);
	
	Items.PageMain.Visible = (ExtendedMode = 0);
	
	If EventName = "OnCreateAtServer" Then
		If VariantNodeChangingMode Then
			Items.PageVariantStructure.Visible = False;
			Items.ExtendedMode.Visible = False;
			Items.CloseAndGenerate.Title = NStr("en='Complete';ru='Закончить редактирование'");
			Items.Close.Title = NStr("en='Cancel';ru='Отменить'");
			Items.Move(Items.PageFilters, Items.SettingPages, Items.PageAppearance);
		EndIf;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function ReportObject()
	Return CommonUse.ObjectByDescriptionFull(ReportSettings.FullName);
EndFunction

&AtServer
Procedure AddConditionalDesign()
	// Filters.
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filters.TitlePredefined", False);
	Instruction.Fields = "FiltersTitle";
	Instruction.Appearance.Insert("TextColor", StyleColors.UnavailableCellTextColor);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filter.OutputCheckBox", False);
	Instruction.Fields = "FiltersUsing";
	Instruction.Appearance.Insert("Visible", False);
	Instruction.Appearance.Insert("Show", False);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filters.ThisIsSection", True);
	Instruction.Fields = "FiltersCondition, FiltersValue, FiltersValuePresentation, FiltersAccessPictureIndex, FiltersTitle";
	Instruction.Appearance.Insert("ReadOnly", True);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filters.IsFolder", True);
	Instruction.Fields = "FiltersCondition, FiltersValue, FiltersValuePresentation";
	Instruction.Appearance.Insert("ReadOnly", True);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filters.OutputValuePresentation", False);
	Instruction.Fields = "FiltersValuePresentation";
	Instruction.Appearance.Insert("Visible", False);
	Instruction.Appearance.Insert("Show", False);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Filters.Insert("Filters.OutputValuePresentation", True);
	Instruction.Fields = "FiltersValue";
	Instruction.Appearance.Insert("Visible", False);
	Instruction.Appearance.Insert("Show", False);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	// Grouping content.
	If VariantNodeChangingMode Then
		Instruction = ReportsVariants.ConditionalDesignInstruction();
		Instruction.Filters.Insert("GroupingContent.ShowAdditionType", True);
		Instruction.Fields = "GroupingContentGroupType";
		Instruction.Appearance.Insert("Visible", False);
		Instruction.Appearance.Insert("Show", False);
		ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
		
		Instruction = ReportsVariants.ConditionalDesignInstruction();
		Instruction.Filters.Insert("GroupingContent.ShowAdditionType", False);
		Instruction.Fields = "GroupingContentAdditionType";
		Instruction.Appearance.Insert("Visible", False);
		Instruction.Appearance.Insert("Show", False);
		ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	EndIf;
	
EndProcedure

&AtServer
Procedure QuickSettingsFinishFillingParameters(FillingParameters)
	If Not FillingParameters.Property("Event") Then
		FillingParameters.Insert("Event", New Structure("Name", ""));
	EndIf;
	If Not FillingParameters.Property("VariantModified") Then
		FillingParameters.Insert("VariantModified", False);
	EndIf;
	If Not FillingParameters.Property("UserSettingsModified") Then
		FillingParameters.Insert("UserSettingsModified", False);
	EndIf;
	If Not FillingParameters.Property("Result") Then
		FillingParameters.Insert("Result", New Structure);
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsRememberState(FillingParameters)
	If FillingParameters.Event.Name = "OnCreateAtServer" Then
		Return; // You do not need to restore anything.
	EndIf;
	
	SelectedRows = New Structure;
	FillingParameters.Insert("SelectedRows", SelectedRows);
	
	TablesNames = "Filters, SelectedFields, Sort, " + ?(VariantNodeChangingMode, "VariantStructure", "GroupingContent");
	TablesNames = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TablesNames, ",", True, True);
	For Each TableName IN TablesNames Do
		SelectedRows.Insert(TableName, ReportsServer.RememberSelectedRows(ThisObject, TableName, "DCIdentifier"));
		StandardSubsystemsClientServer.CollapseTreeNodes(FillingParameters.Result, TableName, "*", True);
	EndDo;
EndProcedure

&AtServer
Procedure QuickSettingsRestoreState(FillingParameters)
	SelectedRows = CommonUseClientServer.StructureProperty(FillingParameters, "SelectedRows");
	If TypeOf(SelectedRows) = Type("Structure") Then
		For Each KeyAndValue IN SelectedRows Do
			ReportsServer.RecallSelectedRows(ThisObject, KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsLoadSettingsToLinker(FillingParameters)
	If FillingParameters.Property("DCSettingsComposer") Then
		SettingsComposer.LoadSettings(FillingParameters.DCSettingsComposer.Settings);
		SettingsComposer.LoadUserSettings(FillingParameters.DCSettingsComposer.UserSettings);
	EndIf;
	
	If FillingParameters.Property("DCSettings") Then
		SettingsComposer.LoadSettings(FillingParameters.DCSettings);
	EndIf;
	
	If FillingParameters.Property("DCUserSettings") Then
		SettingsComposer.LoadUserSettings(FillingParameters.DCUserSettings);
	EndIf;
	
	UpdateVariantSettings = CommonUseClientServer.StructureProperty(FillingParameters, "UpdateVariantSettings", False);
	If UpdateVariantSettings Then
		DCSettings = SettingsComposer.GetSettings();
		SettingsComposer.LoadSettings(DCSettings);
	EndIf;
	
	ResetUserSettings = CommonUseClientServer.StructureProperty(FillingParameters, "ResetUserSettings", False);
	If ResetUserSettings Then
		EmptyLinker = New DataCompositionSettingsComposer;
		SettingsComposer.LoadUserSettings(EmptyLinker.UserSettings);
	EndIf;
	
	If FillingParameters.VariantModified Then
		VariantModified = True;
	EndIf;
	If FillingParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsDeleteOldItemsAndCommands(FillingParameters)
	// Delete items.
	DeletedItems = New Array;
	AddChildItems(DeletedItems, Items.QuickFilters.ChildItems);
	AddChildItems(DeletedItems, Items.ConventionalFilters.ChildItems);
	AddChildItems(DeletedItems, Items.PageAdditionalHeader.ChildItems);
	AddChildItems(DeletedItems, Items.AdvancedPageGroups.ChildItems);
	AddChildItems(DeletedItems, Items.PageAdditionalFooter.ChildItems);
	For Each SettingsPage IN Items.SettingPages.ChildItems Do
		If SettingsPage <> Items.PageMain
			AND SettingsPage <> Items.PageFilters
			AND SettingsPage <> Items.PageSelectedFields
			AND SettingsPage <> Items.PageSort
			AND SettingsPage <> Items.PageGroupingContent
			AND SettingsPage <> Items.PageVariantStructure
			AND SettingsPage <> Items.PageAppearance
			AND SettingsPage <> Items.NotSorted Then
			AddChildItems(DeletedItems, SettingsPage.ChildItems);
			DeletedItems.Add(SettingsPage);
		EndIf;
	EndDo;
	For Each Item IN DeletedItems Do
		Items.Delete(Item);
	EndDo;
	
	// Delete commands
	DeletedCommands = New Array;
	For Each Command IN Commands Do
		If ConstantCommands.FindByValue(Command.Name) = Undefined Then
			DeletedCommands.Add(Command);
		EndIf;
	EndDo;
	For Each Command IN DeletedCommands Do
		Commands.Delete(Command);
	EndDo;
EndProcedure

&AtServer
Procedure AddChildItems(Where, From)
	For Each SubordinateItem IN From Do
		If TypeOf(SubordinateItem) = Type("FormGroup")
			Or TypeOf(SubordinateItem) = Type("FormTable") Then
			AddChildItems(Where, SubordinateItem.ChildItems);
		EndIf;
		Where.Add(SubordinateItem);
	EndDo;
EndProcedure

&AtServer
Procedure QuickSettingsCreateControlItemsAndLoadValues(FillingParameters, Information)
	// Caches for a quick search from a client.
	UserSettingsMap = New Map;
	MapMetadataObjectName   = Information.MapMetadataObjectName;
	DisablingLinksMap        = New Map;
	VariantsSettingsMatch         = New Map;
	
	// Delete attributes
	FillingParameters.Insert("Attributes", New Structure);
	FillingParameters.Attributes.Insert("Adding",  New Array);
	FillingParameters.Attributes.Insert("ToDelete",    New Array);
	FillingParameters.Attributes.Insert("Existing", New Map);
	TypeDescriptionValuesTable = New TypeDescription("ValueTable");
	AllAttributes = GetAttributes();
	For Each Attribute IN AllAttributes Do
		AttributeFullName = AttributeFullName(Attribute);
		If ConstantAttributes.FindByValue(AttributeFullName) = Undefined Then
			FillingParameters.Attributes.Existing.Insert(AttributeFullName, Attribute.ValueType);
			Subordinate = GetAttributes(AttributeFullName);
			If ReportsServer.TypeDescriptionsMatch(Attribute.ValueType, TypeDescriptionValuesTable) Then
				For Each subordinated IN Subordinate Do
					SubordinateFullName = AttributeFullName(subordinated);
					FillingParameters.Attributes.Existing.Insert(SubordinateFullName, subordinated.ValueType);
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	// Local variables for setting values and properties after creation of attributes.
	AddedInputFields          = New Structure;
	AddedValueLists     = New Array;
	AddedTablesWithFlags   = New Array;
	AddedStandardPeriods = New Array;
	
	// Links structure.
	Links = Information.Links;
	
	MainFormAttributesNames     = New Map;
	NamesOfElementsForLinksSetup = New Map;
	SettingsWithComparisonTypeEqual    = New Map;
	
	DCSettingsComposer       = SettingsComposer;
	DCUserSettings = DCSettingsComposer.UserSettings;
	DCSettings                 = DCSettingsComposer.Settings;
	
	AdditionalItemsSettings = CommonUseClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	OutputGroups = New Structure;
	OutputGroups.Insert("QuickFilters", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("ConventionalFilters", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("AdditionalHeader", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("AdditionalFooter", New Structure("Order, Size", New Array, 0));
	OutputGroups.Insert("AdditionalBookmarks", New ValueList);
	AdditionalBookmarksSearch = New Map;
	
	ReportObject = Undefined;
	
	HasDataLoadFromFile = CommonUse.SubsystemExists("StandardSubsystems.DataLoadFromFile");
	
	If VariantNodeChangingMode Then
		OutputSettings = New Array;
	Else
		OutputSettings = Information.UserSettings.Copy(New Structure("OutputAllowed", True));
		OutputSettings.Sort("IndexInCollection Asc");
	EndIf;
	
	OutputSettingsTypes = New Array;
	If ExtendedMode <> 1 Then
		OutputSettingsTypes.Add("FilterItem");
		OutputSettingsTypes.Add("FilterItemGroup");
		OutputSettingsTypes.Add("SettingsParameterValue");
	EndIf;
	OutputSettingsTypes.Add("ConditionalAppearanceItem");
	
	Other = New Structure;
	Other.Insert("Links",       Links);
	Other.Insert("ReportObject", Undefined);
	Other.Insert("FillingParameters",       FillingParameters);
	Other.Insert("PathToLinker",         "SettingsComposer");
	Other.Insert("HasDataLoadFromFile", HasDataLoadFromFile);
	Other.Insert("AdditionalItemsSettings",   AdditionalItemsSettings);
	Other.Insert("MainFormAttributesNames",       MainFormAttributesNames);
	Other.Insert("NamesOfElementsForLinksSetup",   NamesOfElementsForLinksSetup);
	Other.Insert("MapMetadataObjectName", MapMetadataObjectName);
	Other.Insert("AddedInputFields",          AddedInputFields);
	Other.Insert("AddedStandardPeriods", AddedStandardPeriods);
	Other.Insert("AddedValueLists",     AddedValueLists);
	
	For Each SettingProperty IN OutputSettings Do
		
		If (SettingProperty.Type = "SelectedFields"
				Or SettingProperty.Type = "Filter"
				Or SettingProperty.Type = "Order")
			AND SettingProperty.TreeRow = Information.VariantTreeRootRow Then
			// Registration in the information about custom settings.
			TableName = SettingProperty.Type;
			If TableName = "Order" Then
				TableName = "Sort";
			EndIf;
			UserSettingsMap.Insert(TableName, SettingProperty.DCIdentifier);
			Continue; // Output is not required.
		EndIf;
		
		If OutputSettingsTypes.Find(SettingProperty.Type) = Undefined Then
			Continue;
		EndIf;
		
		UserSettingsMap.Insert(SettingProperty.ItemIdentificator, SettingProperty.DCIdentifier);
		
		If SettingProperty.VariantSetting <> Undefined Then
			VariantSettingSearch = New Structure;
			VariantSettingSearch.Insert("DCNodeIdentifier",     SettingProperty.TreeRow.DCIdentifier);
			VariantSettingSearch.Insert("CollectionName",            SettingProperty.VariantSetting.CollectionName);
			VariantSettingSearch.Insert("DCItemID", SettingProperty.VariantSetting.DCIdentifier);
			VariantsSettingsMatch.Insert(SettingProperty.ItemIdentificator, VariantSettingSearch);
		EndIf;
		
		// Define a group for output.
		If SettingProperty.Type = "ConditionalAppearanceItem" Then
			// Define section.
			VariantTreeRootRow = Undefined;
			CurrentRow = SettingProperty.TreeRow;
			While CurrentRow <> Undefined Do
				If ValueIsFilled(CurrentRow.Title) AND CurrentRow.KDNode <> DCSettings Then
					VariantTreeRootRow = CurrentRow;
				EndIf;
				CurrentRow = CurrentRow.Parent;
			EndDo;
			If VariantTreeRootRow = Undefined Then // The section is not found. Output to the main part.
				OutputGroup = OutputGroups.AdditionalFooter;
			Else // Section is found. Output to the group on the Additionally bookmark:
				BookmarkTitle = VariantTreeRootRow.Title;
				OutputGroup = AdditionalBookmarksSearch.Get(BookmarkTitle);
				If OutputGroup = Undefined Then
					OutputGroup = New Structure("Order, Size", New Array, 0);
					OutputGroup.Insert("Title", BookmarkTitle);
					OutputGroup.Insert("FlagName", "");
					OutputGroups.AdditionalBookmarks.Add(OutputGroup, BookmarkTitle);
					AdditionalBookmarksSearch.Insert(BookmarkTitle, OutputGroup);
				EndIf;
			EndIf;
		Else
			If SettingProperty.Quick Then
				OutputGroup = OutputGroups.QuickFilters;
			Else
				OutputGroup = OutputGroups.ConventionalFilters;
			EndIf;
		EndIf;
		
		////////////////////////////////////////////////////////////////////////////////
		// Generator
		
		ReportsServer.OutputSettingItems(ThisObject, Items, SettingProperty, OutputGroup, Other);
		
	EndDo;
	
	ReportsServer.PutInOrder(ThisObject, OutputGroups.QuickFilters, Items.QuickFilters, 2, False);
	ReportsServer.PutInOrder(ThisObject, OutputGroups.ConventionalFilters, Items.ConventionalFilters, 2, False);
	ReportsServer.PutInOrder(ThisObject, OutputGroups.AdditionalHeader, Items.PageAdditionalHeader, 1);
	ReportsServer.PutInOrder(ThisObject, OutputGroups.AdditionalFooter, Items.PageAdditionalFooter, 1);
	
	AdditionalGroupNumber = 0;
	For Each BookmarkDescription IN OutputGroups.AdditionalBookmarks Do
		AdditionalGroupNumber = AdditionalGroupNumber + 1;
		OutputGroup = BookmarkDescription.Value;
		
		GroupName   = "SettingsGroup_" + String(AdditionalGroupNumber);
		ColumnsName  = "SettingsGroup_Columns_" + String(AdditionalGroupNumber);
		IndentName   = "SettingsGroup_Indent_" + String(AdditionalGroupNumber);
		
		CurrentGroup = Items.Add(GroupName, Type("FormGroup"), Items.AdvancedPageGroups);
		CurrentGroup.Type         = FormGroupType.UsualGroup;
		CurrentGroup.Group = ChildFormItemsGroup.Vertical;
		CurrentGroup.Title   = OutputGroup.Title;
		CurrentGroup.Representation = UsualGroupRepresentation.None;
		
		If OutputGroup.FlagName = "" Then
			CurrentGroup.ShowTitle = True;
		Else
			CurrentGroup.ShowTitle = False;
			CheckBox = Items[OutputGroup.FlagName];
			CheckBox.Title = OutputGroup.Title;
			Items.Move(CheckBox, CurrentGroup);
		EndIf;
		
		If OutputGroup.Size > 0 Then
			Columns = Items.Add(ColumnsName, Type("FormGroup"), CurrentGroup);
			Columns.Type                 = FormGroupType.UsualGroup;
			Columns.Group         = ChildFormItemsGroup.Horizontal;
			Columns.Representation         = UsualGroupRepresentation.None;
			Columns.ShowTitle = False;
			
			Indent = Items.Add(IndentName, Type("FormDecoration"), Columns);
			Indent.Type       = FormDecorationType.Label;
			Indent.Title = "    ";
			
			ReportsServer.PutInOrder(ThisObject, OutputGroup, Columns, 1);
		EndIf;
	EndDo;
	
	// Delete old and add new attributes.
	For Each KeyAndValue IN FillingParameters.Attributes.Existing Do
		FillingParameters.Attributes.ToDelete.Add(KeyAndValue.Key);
	EndDo;
	ChangeAttributes(FillingParameters.Attributes.Adding, FillingParameters.Attributes.ToDelete);
	
	// Input fields (set values and links).
	For Each KeyAndValue IN AddedInputFields Do
		AttributeName = KeyAndValue.Key;
		ThisObject[AttributeName] = KeyAndValue.Value;
		Items[AttributeName].DataPath = AttributeName;
	EndDo;
	
	// Standard periods (set values and links).
	For Each SettingProperty IN AddedStandardPeriods Do
		Additionally = SettingProperty.Additionally;
		ThisObject[Additionally.ValueName]      = SettingProperty.Value;
		ThisObject[Additionally.PeriodKindName]    = Additionally.PeriodKind;
		ThisObject[Additionally.AuthorPresentationActualName] = Additionally.Presentation;
		Items[Additionally.PeriodKindName].DataPath    = Additionally.PeriodKindName;
		Items[Additionally.AuthorPresentationActualName].DataPath = Additionally.AuthorPresentationActualName;
		Items[Additionally.BeginOfPeriodName].DataPath        = Additionally.ValueName + ".StartDate";
		Items[Additionally.EndOfPeriodName].DataPath     = Additionally.ValueName + ".EndDate";
	EndDo;
	
	// Selection field (set values and links).
	For Each SettingProperty IN AddedValueLists Do
		Additionally = SettingProperty.Additionally;
		TableName = Additionally.TableName;
		FormTable = Items[TableName];
		ColumnUse = Items[Additionally.ColumnNameUse];
		Column_Value = Items[Additionally.ColumnNameValue];
		ListWithCheckBoxes = New ValueList;
		
		TypeUndefined = Type("Undefined");
		TypeDescriptionUndefined = New TypeDescription("Undefined");
		Quantity = SettingProperty.MarkedValues.Count();
		For Number = 1 To Quantity Do
			ReverseIndex = Quantity - Number;
			ItemOfList = SettingProperty.MarkedValues[ReverseIndex];
			Value = ItemOfList.Value;
			If Not ValueIsFilled(ItemOfList.Presentation)
				AND (Value = Undefined
					Or Value = TypeUndefined
					Or Value = TypeDescriptionUndefined
					Or Not ValueIsFilled(Value)) Then
				SettingProperty.MarkedValues.Delete(ReverseIndex);
				Continue; // Prevent null values.
			EndIf;
			If TypeOf(Value) = Type("Type") Then
				TypeArray = New Array;
				TypeArray.Add(Value);
				Value = New TypeDescription(TypeArray);
			EndIf;
			If SettingProperty.LimitChoiceWithSpecifiedValues
				AND SettingProperty.ValuesForSelection.FindByValue(Value) = Undefined Then
				SettingProperty.MarkedValues.Delete(ReverseIndex);
				Continue; // Selected value is not included to the list of values available for selection.
			EndIf;
			ReportsClientServer.AddUniqueValueInList(ListWithCheckBoxes, Value, ItemOfList.Presentation, True);
		EndDo;
		
		For Each ItemOfList IN SettingProperty.ValuesForSelection Do
			ReportsClientServer.AddUniqueValueInList(ListWithCheckBoxes, ItemOfList.Value, ItemOfList.Presentation, False);
		EndDo;
		
		ListWithCheckBoxes.SortByPresentation(SortDirection.Asc);
		
		ThisObject[TableName] = ListWithCheckBoxes;
		ThisObject[TableName].ValueType = SettingProperty.TypeDescription;
		FormTable.DataPath         = TableName;
		Column_Value.DataPath      = TableName + ".Value";
		ColumnUse.DataPath = TableName + ".Check";
		
		// Some events handlers can be enabled only after setting links of items with data.
		FormTable.SetAction("BeforeStartChanging", "Attachable_ListWithSelection_BeforeStartChanging");
		FormTable.SetAction("BeforeEditEnd", "Attachable_ListWithSelection_BeforeEditingEnd");
		FormTable.SetAction("OnChange", "Attachable_ListWithPickup_OnChange");
		If SettingProperty.LimitChoiceWithSpecifiedValues Then
			FormTable.SetAction("BeforeAddingBegin", "Attachable_FixedList_BeforeAddingBegin");
			FormTable.SetAction("BeforeDelete", "Attachable_FixedList_BeforeDelete");
		Else
			FormTable.SetAction("ChoiceProcessing", "Attachable_ListWithSelection__ChoiceProcessing");
			Column_Value.SetAction("AutoPick", "Attachable_ListWithSelection_Value_AutoPick");
		EndIf;
		ColumnUse.SetAction("OnChange", "Attachable_ListWithSelection_Usage_OnChange");
	EndDo;
	
	// Set values and links of order tables with check boxes.
	For Each SettingProperty IN AddedTablesWithFlags Do
		Additionally = SettingProperty.Additionally;
		UserSetting = SettingProperty.DCUsersSetting;
		Table = ThisObject[Additionally.TableName];
		Table.Clear();
		
		If SettingProperty.Type = "Order" Then
			
			For Each OrderingItem IN UserSetting.Items Do
				If TypeOf(OrderingItem) = Type("DataCompositionOrderItem") Then
					AvailableField = ReportsClientServer.GetAvailableField(DCSettings.OrderAvailableFields, OrderingItem.Field);
					If AvailableField = Undefined Then
						Continue;
					EndIf;
					OrderRow = Table.Add();
					OrderRow.Use   = OrderingItem.Use;
					OrderRow.DCIdentifier = UserSetting.GetIDByObject(OrderingItem);
					OrderRow.Presentation   = AvailableField.Title;
					OrderRow.Direction     = OrderingItem.OrderType;
				EndIf;
			EndDo;
			
		ElsIf SettingProperty.Type = "SelectedFields" Then
			
			ReportsClientServer.AddSettingItems(
				ThisObject,
				Table,
				UserSetting,
				UserSetting,
				True);
			
		ElsIf SettingProperty.Type = "SettingsStructure" Then
			
			For Each StructureItem IN UserSetting.Structure Do
				Presentation = "";
				If TypeOf(StructureItem) = Type("DataCompositionGroup")
					OR TypeOf(StructureItem) = Type("DataCompositionTableGroup")
					OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
					For Each GroupingField IN StructureItem.GroupFields.Items Do
						If Not GroupingField.Use Then
							Continue;
						EndIf;
						AvailableField = ReportsClientServer.GetAvailableField(DCSettings.GroupAvailableFields, GroupingField.Field);
						If AvailableField = Undefined Then
							Presentation = String(GroupingField.Field);
						ElsIf AvailableField.Parent <> Undefined Then
							Presentation = Presentation + StrReplace(StrReplace(AvailableField.Title, AvailableField.Parent.Title, ""), ".", "")+ ", ";
						Else
							Presentation = Presentation + AvailableField.Title + ", ";
						EndIf;
					EndDo;
					Presentation = Left(Presentation, StrLen(Presentation) - 2);
				Else
					Presentation = NStr("en='Table / chart';ru='Таблица / диаграмма'");
				EndIf;
				GroupingRows = Table.Add();
				GroupingRows.ID = StructureItem.UserSettingID;
				GroupingRows.Use = StructureItem.Use;
				GroupingRows.Presentation = Presentation;
			EndDo;
		EndIf;
		
		If Table.Count() = 0 Then
			Items[SettingProperty.GroupName].Visible = False;
		Else
			Items[SettingProperty.TableName].DataPath = SettingProperty.TableName;
			Items[SettingProperty.ColumnNameUse].DataPath = SettingProperty.TableName + ".Use";
			Items[SettingProperty.ColumnNamePresentation].DataPath = SettingProperty.TableName + ".Presentation";
			If SettingProperty.Type = "Order" Then
				Items[SettingProperty.ColumnNameOrder].DataPath = SettingProperty.TableName + ".Direction";
				Items[SettingProperty.TableName].SetAction("Selection", "Attachable_TableOrder_Choice");
			EndIf;
		EndIf;
	EndDo;
	
	// Save matches for a quick search to a form data.
	FastSearchOfUserSettings = New FixedMap(UserSettingsMap);
	QuickSearchMetadataObjectName   = New FixedMap(MapMetadataObjectName);
	DisablingLinksFastSearch        = New FixedMap(DisablingLinksMap);
	QuickSearchVariantSettings         = New FixedMap(VariantsSettingsMatch);
	
	DCUserSettings.AdditionalProperties.Insert("FormItems", AdditionalItemsSettings);
EndProcedure

&AtServer
Function AttributeFullName(Attribute)
	Return ?(IsBlankString(Attribute.Path), "", Attribute.Path + ".") + Attribute.Name;
EndFunction

&AtServer
Procedure AdvancedSettingsLoadValues(FillingParameters, Information)
	If VariantNodeChangingMode Then
		Found = Information.VariantTree.Rows.FindRows(New Structure("DCIdentifier", CurrentCDHostIdentifier), True);
		RootRow = Found[0];
	Else
		RootRow = Information.VariantTreeRootRow;
	EndIf;
	Information.Insert("CurrentTreeRow", RootRow);
	Information.VariantSettings.Columns.Add("IdentifierInForm");
	
	If Not VariantNodeChangingMode AND RootRow.Type <> "NestedObjectSettings" Then
		ParentRows = VariantStructure.GetItems();
		ParentRows.Clear();
		RootRow.Title = "";
		RootRow.Presentation = NStr("en='Report';ru='Отчет'");
		RegisterReportStructureItem(RootRow, ParentRows);
		StandardSubsystemsClientServer.CollapseTreeNodes(FillingParameters.Result, "VariantStructure", "*", True);
	EndIf;
	
	If VariantNodeChangingMode AND CurrentCDHostType <> "Chart" Then
		GroupingContent.GetItems().Clear();
		RegisterGroupsContentItems();
	Else
		Items.PageGroupingContent.Visible = False;
	EndIf;
	
	If CurrentCDHostType <> "Chart" Then
		Sort.GetItems().Clear();
		RegisterSortingItems();
		StandardSubsystemsClientServer.CollapseTreeNodes(FillingParameters.Result, "Sort", "*", True);
	Else
		Items.PageSort.Visible = False;
	EndIf;
	
	SelectedFields.GetItems().Clear();
	RegisterSelectedFieldsItems();
	StandardSubsystemsClientServer.CollapseTreeNodes(FillingParameters.Result, "SelectedFields", "*", True);
	
	If ExtendedMode = 1 AND CurrentCDHostType <> "Chart" Then
		Filters.GetItems().Clear();
		RegisterParameters(Information);
		RegisterFilterItems(Information);
		StandardSubsystemsClientServer.CollapseTreeNodes(FillingParameters.Result, "Filters", "*", True);
		Items.PageFilters.Visible = True;
	Else
		Items.PageFilters.Visible = False;
	EndIf;
	
	If ExtendedMode = 1 AND Not VariantNodeChangingMode Then
		Found = Information.VariantTree.Rows.FindRows(New Structure("Type", "NestedObjectSettings"), True);
		HasInsertedReports = Found.Count() > 0;
		Items.GroupThereAreNestedReports.Visible = HasInsertedReports;
	Else
		Items.GroupThereAreNestedReports.Visible = False;
	EndIf;
	
	If Not VariantNodeChangingMode
		AND Items.PageFilters.Visible
		AND Not Items.GroupThereAreNestedReports.Visible Then
		Found = Information.VariantSettings.Rows.FindRows(New Structure("Type, Global", "FilterItem", False), True);
		HasInsertedFilters = Found.Count() > 0;
		Items.GroupThereAreNestedFilters.Visible = HasInsertedFilters;
	Else
		Items.GroupThereAreNestedFilters.Visible = False;
	EndIf;
	
	If CurrentCDHostType = "Chart" Then
		Items.CurrentCDHostChartType.Visible = True;
		Items.CurrentCDHostChartType.TypeRestriction = New TypeDescription("ChartType");
		
		RootDCNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
		If TypeOf(RootDCNode) = Type("DataCompositionNestedObjectSettings") Then
			RootDCNode = RootDCNode.Settings;
		EndIf;
		DCParameter = RootDCNode.OutputParameters.FindParameterValue(New DataCompositionParameter("ChartType"));
		If DCParameter = Undefined Then
			Items.CurrentCDHostChartType.Visible = False;
		Else
			CurrentCDHostChartType = DCParameter.Value;
		EndIf;
	Else
		Items.CurrentCDHostChartType.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure RegisterReportStructureItem(TreeRow, ParentRows)
	FormRow = ParentRows.Add();
	FillPropertyValues(FormRow, TreeRow, "DCIdentifier, Presentation, Title, Type, Subtype");
	
	FormRow.CheckBoxAvailable = True;
	If (ExtendedMode = 0 AND TreeRow.UserSetting = Undefined)
		Or TreeRow.Type = "ChartStructureItemsCollection"
		Or TreeRow.Type = "StructureTableItemsCollection"
		Or TreeRow.Type = "Settings" Then
		FormRow.CheckBoxAvailable = False;
	EndIf;
	
	If ExtendedMode = 0 AND ValueIsFilled(FormRow.Title) Then
		FormRow.Presentation = FormRow.Title;
		FormRow.Highlight = True;
	EndIf;
	
	FormRow.PictureIndex = -1;
	If TreeRow.Type = "Group"
		Or TreeRow.Type = "TableGrouping"
		Or TreeRow.Type = "ChartGrouping" Then
		FormRow.PictureIndex = 1;
	ElsIf TreeRow.Type = "Table" Then
		FormRow.PictureIndex = 2;
	ElsIf TreeRow.Type = "Chart" Then
		FormRow.PictureIndex = 3;
	ElsIf TreeRow.Type = "NestedObjectSettings" Then
		FormRow.PictureIndex = 4;
	EndIf;
	
	If FormRow.CheckBoxAvailable Then
		If ExtendedMode = 0 Then
			FormRow.DCIdentifier = TreeRow.UserSetting.DCIdentifier;
			FormRow.Use = TreeRow.UserSetting.DCUsersSetting.Use;
		Else
			FormRow.Use = TreeRow.KDNode.Use;
		EndIf;
	EndIf;
	
	ParentSubordinateRows = FormRow.GetItems();
	
	For Each SubordinateTreeRow IN TreeRow.Rows Do
		RegisterReportStructureItem(SubordinateTreeRow, ParentSubordinateRows);
	EndDo;
EndProcedure

&AtServer
Procedure RegisterSortingItems(KDNode = Undefined, KDRowsSet = Undefined, RowsSet = Undefined)
	If KDNode = Undefined Then
		KDNode = FieldsTablesFindNode(ThisObject, "Sort", Undefined);
		If KDNode = Undefined Then
			Items.PageSort.Visible = False;
			Return;
		EndIf;
	EndIf;
	If KDRowsSet = Undefined Then
		KDRowsSet = KDNode.Items;
	EndIf;
	If RowsSet = Undefined Then
		RowsSet = Sort.GetItems();
	EndIf;
	Items.PageSort.Visible = True;
	AvailableFields = KDNode.OrderAvailableFields;
	For Each KDItem IN KDRowsSet Do
		If TypeOf(KDItem) = Type("DataCompositionOrderItem") Then
			AvailableField = AvailableFields.FindField(KDItem.Field);
			If AvailableField = Undefined Then
				Continue;
			EndIf;
			OrderRow = RowsSet.Add();
			OrderRow.Use   = KDItem.Use;
			OrderRow.DCIdentifier = KDNode.GetIDByObject(KDItem);
			OrderRow.Presentation   = AvailableField.Title;
			OrderRow.Direction     = KDItem.OrderType;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure RegisterGroupsContentItems(KDNode = Undefined, KDRowsSet = Undefined, RowsSet = Undefined)
	If KDNode = Undefined Then
		KDNode = FieldsTablesFindNode(ThisObject, "GroupingContent", Undefined);
		If KDNode = Undefined Then
			Return;
		EndIf;
	EndIf;
	If KDRowsSet = Undefined Then
		KDRowsSet = KDNode.Items;
	EndIf;
	If RowsSet = Undefined Then
		RowsSet = GroupingContent.GetItems();
	EndIf;
	AvailableFields = KDNode.AvailableFieldsGroupFields;
	For Each KDItem IN KDRowsSet Do
		If TypeOf(KDItem) = Type("DataCompositionGroupField") Then
			AvailableField = AvailableFields.FindField(KDItem.Field);
			If AvailableField = Undefined Then
				Continue;
			EndIf;
			TableRow = RowsSet.Add();
			TableRow.Use   = KDItem.Use;
			TableRow.DCIdentifier = KDNode.GetIDByObject(KDItem);
			TableRow.Presentation   = AvailableField.Title;
			TableRow.GroupType  = KDItem.GroupType;
			TableRow.AdditionType   = KDItem.AdditionType;
			If AvailableField.Resource Then
				TableRow.Picture = PictureLib.Resource;
			ElsIf AvailableField.Table Then
				TableRow.Picture = PictureLib.NestedTable;
			ElsIf AvailableField.Folder Then
				TableRow.Picture = PictureLib.Folder;
			Else
				TableRow.Picture = PictureLib.Attribute;
			EndIf;
			TypeInformation = ReportsClientServer.TypesAnalysis(AvailableField.ValueType, False);
			If TypeInformation.ContainsTypePeriod Or TypeInformation.ContainsTypeDate Then
				TableRow.ShowAdditionType = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure RegisterSelectedFieldsItems(KDNode = Undefined, KDRowsSet = Undefined, RowsSet = Undefined, AvailableFields = Undefined)
	If KDNode = Undefined Then
		KDNode = FieldsTablesFindNode(ThisObject, "SelectedFields", Undefined);
		If KDNode = Undefined Then
			Items.PageSelectedFields.Visible = False;
			Return;
		EndIf;
	EndIf;
	If KDRowsSet = Undefined Then
		KDRowsSet = KDNode.Items;
	EndIf;
	If RowsSet = Undefined Then
		RowsSet = SelectedFields.GetItems();
	EndIf;
	If AvailableFields = Undefined Then
		AvailableFields = KDNode.SelectionAvailableFields;
	EndIf;
		Items.PageSelectedFields.Visible = True;
	For Each KDItem IN KDRowsSet Do
		If TypeOf(KDItem) = Type("DataCompositionAutoSelectedField") Then
			Continue;
		EndIf;
		If TypeOf(KDItem) = Type("DataCompositionSelectedField") Then
			IsFolder = False;
		ElsIf TypeOf(KDItem) = Type("DataCompositionSelectedFieldGroup") Then
			IsFolder = True;
		Else
			Continue;
		EndIf;
		Presentation = KDItem.Title;
		If ValueIsFilled(KDItem.Field) Then
			AvailableField = AvailableFields.FindField(KDItem.Field);
		Else
			AvailableField = Undefined;
		EndIf;
		If AvailableField = Undefined Then
			If Not IsFolder Then
				Continue;
			EndIf;
		ElsIf Presentation = "" Then
			Presentation = AvailableField.Title;
		EndIf;
		If IsFolder AND KDItem.Placement <> DataCompositionFieldPlacement.Auto Then
			Presentation = Presentation + " (" + String(KDItem.Placement) + ")";
		EndIf;
		
		FormRow = RowsSet.Add();
		FillPropertyValues(FormRow, KDItem);
		FormRow.Presentation   = Presentation;
		FormRow.DCIdentifier = KDNode.GetIDByObject(KDItem);
		FormRow.IsFolder       = IsFolder;
		If IsFolder Then
			FormRow.PictureIndex = 0;
			RegisterSelectedFieldsItems(KDNode, KDItem.Items, FormRow.GetItems(), AvailableFields);
		Else
			FormRow.PictureIndex = 3;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure RegisterParameters(Information)
	If VariantNodeChangingMode Then
		Return;
	EndIf;
	
	SearchConditions = New Structure("TreeRow, CollectionName", Information.CurrentTreeRow, "DataParameters");
	Found = Information.VariantSettings.Rows.FindRows(SearchConditions, False);
	If Found.Count() = 0 Then
		Return;
	EndIf;
	RowsSetVariant = Found[0].Rows;
	
	RowSection = Filters.GetItems().Add();
	RowSection.ThisIsSection = True;
	RowSection.Presentation = NStr("en='Parameters';ru='Параметры'");
	RowSection.PictureIndex = 2;
	RowSection.DCIdentifier = "DataParameters";
	RowsSet = RowSection.GetItems();
	
	For Each VariantSetting IN RowsSetVariant Do
		If Not VariantSetting.OutputAllowed Then
			Continue;
		EndIf;
		
		AvailableKDSetting = VariantSetting.AvailableKDSetting;
		KDItem = VariantSetting.KDItem;
		
		If ValueIsFilled(VariantSetting.AvailableKDSetting.Title) Then
			Presentation = VariantSetting.AvailableKDSetting.Title;
		Else
			Presentation = String(KDItem.Parameter);
		EndIf;
		
		TableRow = RowsSet.Add();
		TableRow.Use   = KDItem.Use;
		TableRow.Value        = VariantSetting.Value;
		TableRow.DCIdentifier = VariantSetting.DCIdentifier;
		TableRow.Presentation   = Presentation;
		TableRow.IsParameter     = True;
		TableRow.PictureIndex  = -1;
		TableRow.ValueType     = VariantSetting.AvailableKDSetting.ValueType;
		TableRow.EnterByList     = VariantSetting.EnterByList;
		TableRow.DisplayCheckbox  = VariantSetting.DisplayCheckbox;
		TableRow.ChoiceFoldersAndItems = VariantSetting.ChoiceFoldersAndItems;
		
		If VariantSetting.LimitChoiceWithSpecifiedValues
			AND TypeOf(VariantSetting.ValuesForSelection) = Type("ValueList") Then
			If TableRow.EnterByList
				AND TypeOf(TableRow.Value) = Type("ValueList") Then
				For Each ItemOfList IN TableRow.Value Do
					ItemForSelection = VariantSetting.ValuesForSelection.FindByValue(ItemOfList.Value);
					If ItemForSelection <> Undefined Then
						ItemOfList.Presentation = ItemForSelection.Presentation;
					EndIf;
				EndDo;
			Else
				TableRow.OutputValuePresentation = True;
				ItemForSelection = VariantSetting.ValuesForSelection.FindByValue(TableRow.Value);
				If ItemForSelection <> Undefined Then
					TableRow.ValuePresentation = ItemForSelection.Presentation;
				EndIf;
			EndIf;
		EndIf;
		
		VariantSetting.IdentifierInForm = TableRow.GetID();
		
		If TypeOf(TableRow.Value) = Type("StandardPeriod") Then
			TableRow.Condition = ReportsClientServer.GetKindOfStandardPeriod(TableRow.Value);
			TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods");
		Else
			TableRow.ConditionType = New TypeDescription("Undefined");
		EndIf;
		
		TableRow.Title = Presentation;
		If ValueIsFilled(KDItem.UserSettingID) Then
			If ValueIsFilled(KDItem.UserSettingPresentation) Then
				TableRow.Title = KDItem.UserSettingPresentation;
			EndIf;
			If KDItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
				TableRow.AccessPictureIndex = 2;
			ElsIf KDItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
				TableRow.AccessPictureIndex = 4;
			Else
				TableRow.AccessPictureIndex = 5;
			EndIf;
		Else
			TableRow.AccessPictureIndex = 5;
		EndIf;
		
		Additionally = New Structure("TypeDescription,
		|LimitSelectionWithSpecifiedValues, SelectionParameters, ValuesForSelection");
		FillPropertyValues(Additionally, VariantSetting);
		TableRow.Additionally = Additionally;
		
	EndDo;
EndProcedure

&AtServer
Procedure RegisterFilterItems(Information, RowsSetVariant = Undefined, FormRowsSet = Undefined)
	If RowsSetVariant = Undefined Then
		SearchConditions = New Structure("TreeRow, CollectionName", Information.CurrentTreeRow, "Filter");
		Found = Information.VariantSettings.Rows.FindRows(SearchConditions, False);
		If Found.Count() = 0 Then
			Return;
		EndIf;
		RowsSetVariant = Found[0].Rows;
	EndIf;
	If FormRowsSet = Undefined Then
		FormRowsSet = Filters.GetItems();
		If Not VariantNodeChangingMode Then
			RowSection = FormRowsSet.Add();
			RowSection.ThisIsSection = True;
			RowSection.Presentation = NStr("en='Filters';ru='Отборы'");
			RowSection.PictureIndex = 3;
			RowSection.DCIdentifier = "Filters";
			FormRowsSet = RowSection.GetItems();
		EndIf;
	EndIf;
	For Each VariantSetting IN RowsSetVariant Do
		If VariantSetting.Type = "FilterItemGroup" Then
			IsFolder = True;
			Presentation = String(VariantSetting.KDItem.GroupType);
		ElsIf VariantSetting.Type = "FilterItem" Then
			// QuickSelection, SelectGroupsAndItems, AvailableComparisonTypes, AvailableValues,
			// Mask, Field Folder, Resource, LinkByType, Table,
			// ChoiceForm, EditingForm, items GetSelectionParameters(), GetSelectionParametersLinks()
			If VariantSetting.AvailableKDSetting = Undefined Then
				Continue;
			EndIf;
			IsFolder = False;
			If ValueIsFilled(VariantSetting.AvailableKDSetting.Title) Then
				Presentation = VariantSetting.AvailableKDSetting.Title;
			Else
				Presentation = String(VariantSetting.KDItem.LeftValue);
			EndIf;
		Else
			Continue;
		EndIf;
		
		KDItem = VariantSetting.KDItem;
		
		TableRow = FormRowsSet.Add();
		TableRow.Use   = VariantSetting.KDItem.Use;
		TableRow.Presentation   = Presentation;
		TableRow.Title       = Presentation;
		TableRow.DCIdentifier = VariantSetting.DCIdentifier;
		TableRow.IsParameter     = False;
		TableRow.IsFolder       = IsFolder;
		TableRow.EnterByList     = VariantSetting.EnterByList;
		TableRow.DisplayCheckbox  = VariantSetting.DisplayCheckbox;
		TableRow.ChoiceFoldersAndItems = VariantSetting.ChoiceFoldersAndItems;
		
		VariantSetting.IdentifierInForm = TableRow.GetID();
		
		DisplayOnlyCheckBox = False;
		If ValueIsFilled(KDItem.Presentation) Then
			DisplayOnlyCheckBox = True;
			If KDItem.Presentation <> "1" Then
				TableRow.Title = KDItem.Presentation;
			EndIf;
		EndIf;
		If ValueIsFilled(KDItem.UserSettingPresentation) Then
			TableRow.Title = KDItem.UserSettingPresentation;
		EndIf;
		TableRow.TitlePredefined = (TableRow.Title <> TableRow.Presentation);
		
		If ValueIsFilled(KDItem.UserSettingID) Then
			If KDItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
				TableRow.AccessPictureIndex = ?(DisplayOnlyCheckBox, 1, 2);
			ElsIf KDItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
				TableRow.AccessPictureIndex = ?(DisplayOnlyCheckBox, 3, 4);
			Else
				TableRow.AccessPictureIndex = 5;
			EndIf;
		Else
			TableRow.AccessPictureIndex = 5;
		EndIf;
		
		If IsFolder Then
			TableRow.PictureIndex = -1;
			RegisterFilterItems(Information, VariantSetting.Rows, TableRow.GetItems());
		Else
			TableRow.Value = VariantSetting.Value;
			If VariantSetting.LimitChoiceWithSpecifiedValues
				AND TypeOf(VariantSetting.ValuesForSelection) = Type("ValueList") Then
				If TableRow.EnterByList
					AND TypeOf(TableRow.Value) = Type("ValueList") Then
					For Each ItemOfList IN TableRow.Value Do
						ItemForSelection = VariantSetting.ValuesForSelection.FindByValue(ItemOfList.Value);
						If ItemForSelection <> Undefined Then
							ItemOfList.Presentation = ItemForSelection.Presentation;
						EndIf;
					EndDo;
				Else
					TableRow.OutputValuePresentation = True;
					ItemForSelection = VariantSetting.ValuesForSelection.FindByValue(TableRow.Value);
					If ItemForSelection <> Undefined Then
						TableRow.ValuePresentation = ItemForSelection.Presentation;
					EndIf;
				EndIf;
			EndIf;
			TableRow.ValueType = VariantSetting.TypeDescription;
			TableRow.PictureIndex = -1;
			If TypeOf(TableRow.Value) = Type("StandardPeriod") Then
				TableRow.Condition = ReportsClientServer.GetKindOfStandardPeriod(TableRow.Value);
				TableRow.ConditionType = New TypeDescription("EnumRef.AvailableReportPeriods");
			Else
				TableRow.Condition = VariantSetting.ComparisonType;
				TableRow.ConditionType = New TypeDescription("DataCompositionComparisonType");
			EndIf;
		EndIf;
		
		Additionally = New Structure("TypeDescription,
		|LimitSelectionWithSpecifiedValues, SelectionParameters, ValuesForSelection");
		FillPropertyValues(Additionally, VariantSetting);
		TableRow.Additionally = Additionally;
		
	EndDo;
EndProcedure

&AtServer
Procedure RegisterDisabledLinks(Information)
	DisabledLinks.Clear();
	For Each LinkDescription IN Information.DisabledLinks Do
		Link = DisabledLinks.Add();
		FillPropertyValues(Link, LinkDescription);
		If ExtendedMode = 1 Then
			Link.LeadingIdentifierInForm     = LinkDescription.Leading.IdentifierInForm;
			Link.SubordinateIdentifierInForm = LinkDescription.subordinated.IdentifierInForm;
		Else
			Link.LeadingIdentifierInForm     = LinkDescription.Leading.ItemIdentificator;
			Link.SubordinateIdentifierInForm = LinkDescription.subordinated.ItemIdentificator;
		EndIf;
	EndDo;
EndProcedure

#EndRegion













