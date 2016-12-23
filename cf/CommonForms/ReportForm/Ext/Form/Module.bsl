// StandardSubsystems.PerformanceEstimation
&AtClient
Var OperationsStartTime;

&AtClient
Var PerformMeteringPerformance;
// End StandardSubsystems.PerformanceEstimation

&AtClient
Var HandlerParameters;

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
	
	PanelVariantsCurrentVariantKey = " - ";
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.CommandsMore.Width = 15;
	EndIf;
	
	// Form parameters.
	EncryptingMode = (Parameters.Property("Details") AND Parameters.Details <> Undefined);
	ReportVariantMode = (TypeOf(CurrentVariantKey) = Type("String") AND Not IsBlankString(CurrentVariantKey));
	OutputRight = AccessRight("Output", Metadata);
	
	ParametersForm = New Structure(
		"UsagePurposeKey,
		|UserSettingsKey, Decryption,
		|GenerateOnOpen, ReadOnly, FixedSettings, Section, Subsystem, SubsystemPresentation");
	FillPropertyValues(ParametersForm, Parameters);
	ParametersForm.Insert("Filter", New Structure);
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		CommonUseClientServer.ExpandStructure(ParametersForm.Filter, Parameters.Filter, True);
		Parameters.Filter.Clear();
	EndIf;
	ParametersForm = New FixedStructure(ParametersForm);
	
	// StandardSubsystems.PerformanceEstimation
	Try
		ReportObject 		= FormAttributeToValue("Report");
		ReportMetadata		= ReportObject.Metadata();
		PostFix			= ReportMetadata.Name + "_" + StrReplace(CurrentVariantKey, " ", "_");
		KeyOperation	= PredefinedValue("Catalog.KeyOperations.ReportCreation_" + Postfix); 
	Except
		KeyOperation = Undefined;
	EndTry;
	// End StandardSubsystems.PerformanceEstimation
	
	If ParametersForm.Subsystem = Undefined Then
		Items.OtherReports.Visible = False;
	EndIf;
	
	// Local variables.
	ReportObject = FormAttributeToValue("Report");
	ReportMetadata = ReportObject.Metadata();
	ReportSettings = ReportsClientServer.GetReportSettingsByDefault();
	SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, UUID);
	
	ReportSettings.Insert("SchemaURL", SchemaURL);
	ReportSettings.Insert("FullName", ReportMetadata.FullName());
	ReportSettings.Insert("Description", TrimAll(ReportMetadata.Presentation()));
	
	Information = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(ReportSettings.FullName);
	ReportSettings.Insert("ReportRef", Information.Report);
	ReportSettings.Insert("VariantRef", ReportsVariants.GetRef(ReportSettings.ReportRef, CurrentVariantKey));
	
	If ReportsVariantsReUse.ReportsWithSettings().Find(ReportSettings.ReportRef) <> Undefined Then
		ReportObject.DefineFormSettings(ThisObject, CurrentVariantKey, ReportSettings);
		AccordanceFrequencySettings = New Map;
		For Each KeyAndValue In ReportSettings.AccordanceFrequencySettings Do
			DCField = KeyAndValue.Key;
			If TypeOf(DCField) = Type("DataCompositionParameter") Then
				DCField = New DataCompositionField("DataParameters." + String(DCField));
			EndIf;
			AccordanceFrequencySettings.Insert(DCField, KeyAndValue.Value);
		EndDo;
		ReportSettings.Insert("AccordanceFrequencySettings", AccordanceFrequencySettings);
	EndIf;
	
	ReportSettings.Insert("ReadCheckBoxGenerateImmediatelyFromUserSettings", True);
	If Parameters.Property("GenerateOnOpen") AND Parameters.GenerateOnOpen = True Then
		Parameters.GenerateOnOpen = False;
		ReportSettings.FormImmediately = True;
		ReportSettings.ReadCheckBoxGenerateImmediatelyFromUserSettings = False;
	EndIf;
	
	ReportSettings.Insert("External", TypeOf(ReportSettings.ReportRef) = Type("String"));
	ReportSettings.Insert("PredefinedVariants", New ValueList);
	If ReportSettings.External AND ReportObject.DataCompositionSchema <> Undefined Then
		For Each Variant In ReportObject.DataCompositionSchema.SettingVariants Do
			ReportSettings.PredefinedVariants.Add(Variant.Name, Variant.Presentation);
		EndDo;
	EndIf;
	
	// Default parameters
	If ReportSettings.Property("OutputAmountSelectedCells") AND Not ReportSettings.OutputAmountSelectedCells Then
		Items.AutoSumGroup.Visible = False;
		Items.ReportSpreadsheetDocument.SetAction("OnActivateArea", "");
	EndIf;
	
	// Hide options commands
	If Not Parameters.Property("ReportVariantsCommandsVisible", ReportVariantsCommandsVisible) Then
		ReportVariantsCommandsVisible = ReportsVariantsReUse.AddRight();
		If ReportVariantsCommandsVisible // Commands are not enabled by the form opening parameters.
			AND Parameters.VariantKey = Undefined // Opened without context.
			AND ValueIsFilled(ReportSettings.VariantRef) Then // Option is registered.
			PredefinedVariant = CommonUse.ObjectAttributeValue(ReportSettings.VariantRef, "PredefinedVariant");
			If ValueIsFilled(PredefinedVariant) Then
				Disabled = ReportsVariantsReUse.DisabledApplicationOptions();
				If Disabled.Find(PredefinedVariant) <> Undefined Then // Option is disabled.
					Text = NStr("en='Context option ""%1"" of report ""%2"" is opened without context.';ru='Контекстный вариант ""%1"" отчета ""%2"" открыт без контекста.'");
					ReportsVariants.WarningByOption(ReportSettings.VariantRef, Text, ReportSettings.VariantRef, ReportSettings.ReportRef);
					ReportVariantsCommandsVisible = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	If Not ReportVariantsCommandsVisible Then
		AutoNavigationRef = False;
	EndIf;
	
	// Registration of the commands and the form attributes that are not deleted during the refill of quick settings.
	AttributesSet = GetAttributes();
	For Each Attribute In AttributesSet Do
		AttributeFullName = Attribute.Name + ?(IsBlankString(Attribute.Path), "", "." + Attribute.Path);
		ConstantAttributes.Add(AttributeFullName);
	EndDo;
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	// Reduce dependent form items to condition.
	VisibleEnabledCorrectness("");
	
	// Close integration with SSL subsystems.
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsMailing") Then
		ReportSendingModule = CommonUse.CommonModule("ReportMailing");
		ReportSendingModule.ReportFormAddCommands(ThisObject, Cancel, StandardProcessing);
	EndIf;
	
	// Events.
	ReportsOverridable.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	If ReportSettings.Events.OnCreateAtServer Then
		ReportObject.OnCreateAtServer(ThisObject, Cancel, StandardProcessing);
	EndIf;
	
	// If there is one command in submenu, then drop-down list is not displayed.
	If Items.GroupSend_Left.ChildItems.Count() = 1 Then
		Items.SendByEMail_Left.Title = Items.GroupSend_Left.Title + "...";
		Items.Move(Items.SendByEMail_Left, Items.CommandsLeft, Items.GroupSend_Left);
	EndIf;
	If Items.GroupSend.ChildItems.Count() = 1 Then
		Items.SendByEMail.Title = Items.GroupSend.Title + "...";
		Items.Move(Items.SendByEMail, Items.CommandsMore, Items.GroupSend);
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ClientVariables = New Structure;
	ClientVariables.Insert("WaitInterval", ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2));
	If Not Cancel Then
		FormIsOpened = True;
	EndIf;
	If ReportSettings.FormImmediately Then
		Report.SettingsComposer.UserSettings.AdditionalProperties.Insert("GenerateOnOpening", True);
		AttachIdleHandler("Generate", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure ChoiceProcessing(Result, SubordinateForm)
	ResultProcessed = False;
	
	// Receive result from the standard forms.
	If TypeOf(SubordinateForm) = Type("ManagedForm") Then
		SubordinateFormName = SubordinateForm.FormName;
		If SubordinateFormName = "SettingsStorage.ReportsVariantsStorage.Form.ReportSettings"
			Or SubordinateForm.OnCloseNotifyDescription <> Undefined Then
			ResultProcessed = True; // See AllSettingsEnd.
		ElsIf TypeOf(Result) = Type("Structure") Then
			DotPosition = StrLen(SubordinateFormName);
			While CharCode(SubordinateFormName, DotPosition) <> 46 Do // Not point.
				DotPosition = DotPosition - 1;
			EndDo;
			SourseFormSuffix = Upper(Mid(SubordinateFormName, DotPosition + 1));
			If SourseFormSuffix = Upper("ReportSettingsForm")
				Or SourseFormSuffix = Upper("SettingsForm")
				Or SourseFormSuffix = Upper("ReportVariantForm")
				Or SourseFormSuffix = Upper("VariantForm") Then
				QuickSettingsFill(Result);
				If Result.Property("Regenerate") AND Result.Regenerate Then
					ClearMessages();
					Generate();
				EndIf;
				ResultProcessed = True;
			EndIf;
		EndIf;
	EndIf;
	
	// Extension mechanisms.
	If CommonUseClient.SubsystemExists("StandardSubsystems.ReportsMailing") Then
		ModuleReportSendingClient = CommonUseClient.CommonModule("ReportMailingClient");
		ModuleReportSendingClient.ReportFormChoiceProcessing(ThisObject, Result, SubordinateForm, ResultProcessed);
	EndIf;
	ReportsClientOverridable.ChoiceProcessing(ThisObject, Result, SubordinateForm, ResultProcessed);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessed = False;
	If EventName = ReportsVariantsClientServer.EventNameOptionChanging() Then
		NotificationProcessed = True;
		PanelVariantsCurrentVariantKey = " - ";
		AttachIdleHandler("VisibleEnabledIfNeeded", 0.1, True);
	EndIf;
	
	ReportsClientOverridable.NotificationProcessing(ThisObject, EventName, Parameter, Source, NotificationProcessed);
EndProcedure

&AtServer
Procedure OnLoadVariantAtServer(NewSettingsDC)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Do nothing if report is not on DLS and no settings are imported.
	ReportVariantMode = (TypeOf(CurrentVariantKey) = Type("String") AND Not IsBlankString(CurrentVariantKey));
	If Not ReportVariantMode AND NewSettingsDC = Undefined Then
		Return;
	EndIf;
	
	// Update report option reference.
	If PanelVariantsCurrentVariantKey <> CurrentVariantKey Then
		ReportSettings.VariantRef = ReportsVariants.GetRef(ReportSettings.ReportRef, CurrentVariantKey);
	EndIf;
	
	// Call a predefined module.
	ReportsOverridable.BeforeLoadVariantAtServer(ThisObject, NewSettingsDC);
	If ReportSettings.Events.BeforeLoadVariantAtServer
		Or ReportSettings.Events.OnLoadVariantAtServer Then
		ReportObject = FormAttributeToValue("Report");
	EndIf;
	If ReportSettings.Events.BeforeLoadVariantAtServer Then
		ReportObject.BeforeLoadVariantAtServer(ThisObject, NewSettingsDC);
	EndIf;
	
	// Import fixed settings for the decryption mode.
	If EncryptingMode Then
		ReportCurrentVariantName = CommonUseClientServer.StructureProperty(NewSettingsDC.AdditionalProperties, "OptionName");
		If Parameters <> Undefined AND Parameters.Property("Details") Then
			Report.SettingsComposer.LoadFixedSettings(Parameters.Details.UsedSettings);
			Report.SettingsComposer.FixedSettings.AdditionalProperties.Insert("EncryptingMode", True);
		EndIf;
	Else
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("OptionName", ReportCurrentVariantName);
	EndIf;
	If TypeOf(ParametersForm.Filter) = Type("Structure") Then
		DCParameters = Report.SettingsComposer.Settings.DataParameters;
		DCFilters = Report.SettingsComposer.Settings.Filter;
		Inaccessible = DataCompositionSettingsItemViewMode.Inaccessible;
		For Each KeyAndValue In ParametersForm.Filter Do
			Name = KeyAndValue.Key;
			Value = KeyAndValue.Value;
			If TypeOf(Value) = Type("FixedArray") Then
				Value = New Array(Value);
			EndIf;
			If TypeOf(Value) = Type("Array") Then
				List = New ValueList;
				List.LoadValues(Value);
				Value = List;
			EndIf;
			DCParameter = DCParameters.FindParameterValue(New DataCompositionParameter(Name));
			If TypeOf(DCParameter) = Type("DataCompositionSettingsParameterValue") Then
				DCParameter.UserSettingID = "";
				DCParameter.Use    = True;
				DCParameter.ViewMode = Inaccessible;
				DCParameter.Value         = Value;
				Continue;
			EndIf;
			AvailableDCField = DCFilters.FilterAvailableFields.FindField(New DataCompositionField(Name));
			If TypeOf(AvailableDCField) = Type("DataCompositionFilterAvailableField") Then
				If TypeOf(Value) = Type("ValueList") Then
					ComparisonTypeCD = DataCompositionComparisonType.InList;
				Else
					ComparisonTypeCD = DataCompositionComparisonType.Equal;
				EndIf;
				CommonUseClientServer.SetFilterItem(DCFilters, Name, Value, ComparisonTypeCD, , True, Inaccessible, "");
				Continue;
			EndIf;
			ErrorText = NStr("en='Unable to set fixed filter ""%1"".';ru='Не удалось установить фиксированный отбор ""%1"".'");
			ReportsVariants.ErrorByVariant(ReportSettings.VariantRef, ErrorText, Name);
		EndDo;
	EndIf;
	
	// Fill in quick settings panel.
	ReportVariantMode = True;
	
	// Call a predefined module.
	If ReportSettings.Events.OnLoadVariantAtServer Then
		ReportObject.OnLoadVariantAtServer(ThisObject, NewSettingsDC);
	Else
		ReportsOverridable.OnLoadVariantAtServer(ThisObject, NewSettingsDC);
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(NewDCUserSettings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not ReportVariantMode Then
		Return;
	EndIf;
	
	// Call a predefined module.
	If ReportSettings.Events.OnLoadUserSettingsAtServer Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.OnLoadUserSettingsAtServer(ThisObject, NewDCUserSettings);
	Else
		ReportsOverridable.OnLoadUserSettingsAtServer(ThisObject, NewDCUserSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnUpdateUserSettingsAtServer(StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not ReportVariantMode Then
		Return;
	EndIf;
	StandardProcessing = False;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("Event", New Structure);
	FillingParameters.Event.Insert("Name", "OnUpdateUserSettingsAtServer");
	FillingParameters.Event.Insert("StandardProcessing", StandardProcessing);
	QuickSettingsFill(FillingParameters);
	If FillingParameters.Event.StandardProcessing <> StandardProcessing Then
		StandardProcessing = FillingParameters.Event.StandardProcessing;
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Not ReportVariantMode Then
		Return;
	EndIf;
	If CommonUseClientServer.ThisIsWebClient() Then // For platform 8.3.5.
		Return;
	EndIf;
	DCUserSettings = Report.SettingsComposer.UserSettings;
	For Each DCUsersSetting In DCUserSettings.Items Do
		Type = ReportsClientServer.RowSettingType(TypeOf(DCUsersSetting));
		
		If Type = "SettingsParameterValue"
			AND TypeOf(DCUsersSetting.Value) = Type("StandardPeriod")
			AND DCUsersSetting.Use Then
			
			ItemIdentificator = ReportsClientServer.AdjustIDToName(DCUsersSetting.UserSettingID);
			
			BeginOfPeriod    = Items.Find(Type + "_Begin_"    + ItemIdentificator);
			EndOfPerioding = Items.Find(Type + "_End_" + ItemIdentificator);
			If BeginOfPeriod = Undefined Or EndOfPerioding = Undefined Then
				Continue;
			EndIf;
			
			Value = DCUsersSetting.Value;
			If BeginOfPeriod.AutoMarkIncomplete
				AND Not ValueIsFilled(Value.StartDate)
				AND Not ValueIsFilled(Value.EndDate) Then
				ErrorText = NStr("en='Period is not specified.';ru='Не указан период'");
				DataPath = BeginOfPeriod.DataPath;
			ElsIf Value.StartDate > Value.EndDate Then
				ErrorText = NStr("en='Period end should be more than start';ru='Конец периода должен быть больше начала'");
				DataPath = EndOfPerioding.DataPath;
			Else
				Continue;
			EndIf;
			
			Cancel = True;
			CommonUseClientServer.MessageToUser(ErrorText, , DataPath);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure OnSaveVariantAtServer(DCSettings)
	If Not ReportVariantMode Then
		Return;
	EndIf;
	NewSettingsDC = Report.SettingsComposer.GetSettings();
	Report.SettingsComposer.LoadSettings(NewSettingsDC);
	// For platform 8.3.5.
	DCSettings.AdditionalProperties.Insert("Address", PutToTempStorage(NewSettingsDC));
	DCSettings = NewSettingsDC;
	PanelVariantsCurrentVariantKey = " - ";
	VisibleEnabledCorrectness("ReportVariant");
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(DCUserSettings)
	If Not ReportVariantMode Then
		Return;
	EndIf;
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, DCUserSettings);
	FillOptionSelectionCommands();
EndProcedure

&AtClient
Procedure OnClose()
	If BackgroundJobID <> Undefined Then
		BackgroundJobCancel(BackgroundJobID);
		BackgroundJobID = Undefined;
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// ITEMS EVENTS

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document

&AtClient
Procedure ReportSpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	ReportsClientOverridable.DetailProcessing(ThisObject, Item, Details, StandardProcessing);
EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentAdditionalDetailProcessing(Item, Details, StandardProcessing)
	ReportsClientOverridable.AdditionalDetailProcessing(ThisObject, Item, Details, StandardProcessing);
EndProcedure

&AtClient
Procedure ReportSpreadsheetDocumentOnActivateArea(Item)
	If ReportSettings.OutputAmountSelectedCells Then
		AttachIdleHandler("CalculateCellsAmount", ClientVariables.WaitInterval, True);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached

&AtClient
Procedure Attachable_CheckboxUsing_OnChange(Item)
	ItemIdentificator = Right(Item.Name, 32);
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
		For Each Link In Found Do
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
	
	PagesName             = SettingPropertiesType + "_Pages_"      + ItemIdentificator;
	PeriodValueName       = SettingPropertiesType + "_Value_"      + ItemIdentificator;
	PeriodPresentationName  = SettingPropertiesType + "_Presentation_" + ItemIdentificator;
	RandomNamePage = SettingPropertiesType + "_PageRandom_" + ItemIdentificator;
	StandardNamePage  = SettingPropertiesType + "_PageStandard_" + ItemIdentificator;
	
	Value = ThisObject[PeriodValueName];
	
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
	ThisObject[PeriodPresentationName] = Presentation;
	ThisObject[PeriodValueName]      = Value;
	
	DCUsersSetting = FindElementsUsersSetup(ItemIdentificator);
	If TypeOf(DCUsersSetting) = Type("DataCompositionSettingsParameterValue") Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	DCUsersSetting.Use = True;
	
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_Value_StartChoice(Item, StandardProcessing)
	StandardProcessing = False;
	
	// Generate information about an item.
	PeriodPresentationName = Item.Name;
	ItemIdentificator  = Right(PeriodPresentationName, 32);
	SettingPropertiesType = Left(PeriodPresentationName, Find(PeriodPresentationName, "_Presentation_")-1);
	
	PeriodValueName = SettingPropertiesType + "_Value_"      + ItemIdentificator;
	PeriodKindName     = SettingPropertiesType + "_Kind_"           + ItemIdentificator;
	
	Value   = ThisObject[PeriodValueName];
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
	ChoiceParameters.Insert("PeriodPresentationName", PeriodPresentationName);
	ChoiceParameters.Insert("PeriodValueName",      PeriodValueName);
	ChoiceParameters.Insert("PeriodKind",             PeriodKind);
	ChoiceParameters.Insert("IsParameter",            SettingPropertiesType = "SettingsParameterValue");
	
	SelectPeriodFromDropdownList(-1, ChoiceParameters);
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_BeginOfPeriod_OnChange(Item)
	
	// Generate information about an item.
	BeginOfPeriodName = Item.Name;
	ItemIdentificator  = Right(BeginOfPeriodName, 32);
	SettingPropertiesType = Left(BeginOfPeriodName, Find(BeginOfPeriodName, "_Begin_")-1);
	PeriodValueName = SettingPropertiesType + "_Value_" + ItemIdentificator;
	
	Value = ThisObject[PeriodValueName];
	
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
	
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_EndOfPeriod_OnChange(Item)
	
	// Generate information about an item.
	EndOfPeriodName = Item.Name;
	ItemIdentificator  = Right(EndOfPeriodName, 32);
	SettingPropertiesType = Left(EndOfPeriodName, Find(EndOfPeriodName, "_End_")-1);
	
	PeriodValueName = SettingPropertiesType + "_Value_" + ItemIdentificator;
	
	Value = ThisObject[PeriodValueName];
	
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
	
EndProcedure

&AtClient
Procedure Attachable_StandardPeriod_Value_Clearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// BUTTONS EVENTS

#Region FormCommandsHandlers

&AtClient
Procedure AllSettings(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings",     ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("OptionName", String(ReportCurrentVariantName));
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	
	Handler = New NotifyDescription("AllSettingsEnd", ThisObject);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ReportSettings", FormParameters, ThisObject, , , , Handler, Mode);
EndProcedure

&AtClient
Procedure AllSettingsEnd(Result, ExecuteParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	QuickSettingsFill(Result);
	If Result.Property("Regenerate") AND Result.Regenerate Then
		ClearMessages();
		Generate();
	EndIf;
EndProcedure

&AtClient
Procedure ChangeReportVariant(Command)
	FormParameters = New Structure(ParametersForm);
	FormParameters.Insert("Variant",                               Report.SettingsComposer.Settings);
	FormParameters.Insert("VariantKey",                          String(CurrentVariantKey));
	FormParameters.Insert("UserSettings",             Report.SettingsComposer.UserSettings);
	FormParameters.Insert("VariantPresentation",                 String(ReportCurrentVariantName));
	FormParameters.Insert("UserSettingsPresentation", "");
	
	OpenForm(ReportSettings.FullName + ".VariantForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure DefaultSettings(Command)
	FillingParameters = New Structure;
	FillingParameters.Insert("Event", New Structure);
	FillingParameters.Event.Insert("Name", "DefaultSettings");
	FillingParameters.Insert("ResetUserSettings", True);
	FillingParameters.Insert("UserSettingsModified", True);
	
	QuickSettingsFill(FillingParameters);
EndProcedure

&AtClient
Procedure SendByEMail(Command)
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	If StatePresentation.Visible = True
		AND StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance Then
		QuestionText = NStr("en='Report is not generated. Generate?';ru='Отчет не сформирован. Сформировать?'");
		Handler = New NotifyDescription("SendByEMailEnd", ThisObject);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	Else
		ShowSendingByEMailDialog();
	EndIf;
EndProcedure

&AtClient
Procedure ReportAssembleResult(Command)
	ClearMessages();
	Generate();
EndProcedure

&AtClient
Procedure CalculateAmount(Command)
	SelectedAreas = StandardSubsystemsClient.SelectedAreas(ReportSpreadsheetDocument);
	MarkedCellsAmount = CalculateSummServer(ReportSpreadsheetDocument, SelectedAreas);
	Items.AutoSumButton.Enabled = False;
EndProcedure

&AtClient
Procedure FormImmediately(Command)
	
	FormImmediately = Not ReportSettings.FormImmediately;
	ReportSettings.FormImmediately = FormImmediately;
	Items.FormImmediately.Check = FormImmediately;
	
	StateBeforeChange = New Structure("Visibile, AdditionalShowMode, Picture, Text");
	FillPropertyValues(StateBeforeChange, Items.ReportSpreadsheetDocument.StatePresentation);
	
	Report.SettingsComposer.UserSettings.AdditionalProperties.Insert("FormImmediately", FormImmediately);
	UserSettingsModified = True;
	
	FillPropertyValues(Items.ReportSpreadsheetDocument.StatePresentation, StateBeforeChange);
	
EndProcedure

&AtClient
Procedure OtherReports(Command)
	FormParameters = New Structure;
	FormParameters.Insert("VariantRef",     ReportSettings.VariantRef);
	FormParameters.Insert("ReportRef",       ReportSettings.ReportRef);
	FormParameters.Insert("SubsystemRef",  ParametersForm.Subsystem);
	FormParameters.Insert("ReportName", ReportSettings.Description);
	
	Block = FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.OtherReportsPanel", FormParameters, ThisObject, True, , , , Block);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached

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

&AtClient
Procedure Attachable_LoadReportVariant(Command)
	Found = AddedVariants.FindRows(New Structure("CommandName", Command.Name));
	If Found.Count() = 0 Then
		ShowMessageBox(, NStr("en='Report variant is not found.';ru='Вариант отчета не найден.'"));
		Return;
	EndIf;
	FormVariant = Found[0];
	LoadVariant(FormVariant.VariantKey);
	UniqueKey = Left(UniqueKey, Find(UniqueKey, "/")) + "VariantKey." + FormVariant.VariantKey;
	If ReportSettings.FormImmediately Then
		AttachIdleHandler("Generate", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

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
		ThisObject[ChoiceParameters.PeriodPresentationName] = ?(IsBlankString(Result.Presentation), String(Result.Value), Result.Presentation);
		Value.Variant = Result.Value;
	Else
		BeginOfPeriod = ReportsClientServer.ReportPeriodStart(ChoiceParameters.PeriodKind, Result.Value);
		EndOfPeriod  = ReportsClientServer.ReportEndOfPeriod(ChoiceParameters.PeriodKind, Result.Value);
		
		ThisObject[ChoiceParameters.PeriodPresentationName] = Result.Presentation;
		
		Value.Variant = StandardPeriodVariant.Custom;
		Value.StartDate    = BeginOfPeriod;
		Value.EndDate = EndOfPeriod;
	EndIf;
	
	ThisObject[ChoiceParameters.PeriodValueName] = Value;
	
	DCUsersSetting = FindElementsUsersSetup(ChoiceParameters.ItemIdentificator);
	If ChoiceParameters.IsParameter Then
		DCUsersSetting.Value = Value;
	Else
		DCUsersSetting.RightValue = Value;
	EndIf;
	
	DCUsersSetting.Use = True;
	
EndProcedure

&AtClient
Function FindElementsUsersSetup(ItemIdName)
	// For custom settings, data composition IDs
	//  are stored as they can not be stored as a reference (value copy is in progress).
	If StrLen(ItemIdName) = 32 Then
		ItemIdentificator = ItemIdName;
	Else
		ItemIdentificator = Right(ItemIdName, 32);
	EndIf;
	DCIdentifier = FastSearchOfUserSettings.Get(ItemIdentificator);
	Return Report.SettingsComposer.UserSettings.GetObjectByID(DCIdentifier);
EndFunction

&AtClient
// Exception from development standards.
Function ExecuteContextServerCall(OperationKey, OperationParameters) Export
	// Application interface for the context call from the client general module.
	
	Return ContextServerCall(OperationKey, OperationParameters);
	
EndFunction

&AtClient
Procedure BackgroundJobCheckAtClient()
	If BackGroundJobFinished() Then
		ShowUserNotification(NStr("en='Report created';ru='Отчет сформирован'"), , Title);
		
		// StandardSubsystems.PerformanceEstimation
		If PerformMeteringPerformance Then
			PerformanceEstimationClientServer.EndTimeMeasurement(
				KeyOperation, 
				OperationsStartTime
			);
		EndIf;
		// End StandardSubsystems.PerformanceEstimation
		
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("BackgroundJobCheckAtClient", HandlerParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtClient
Procedure CalculateCellsAmount()
	MarkedCellsAmount = StandardSubsystemsClientServer.CellsAmount(ReportSpreadsheetDocument, Undefined);
	Items.AutoSumButton.Enabled = (MarkedCellsAmount = "<");
EndProcedure

&AtClient
Procedure SendByEMailEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		GenerateDirectly();
		ShowSendingByEMailDialog();
	EndIf;
EndProcedure

&AtClient
Procedure ShowSendingByEMailDialog()
	DocumentsTable = New ValueList;
	DocumentsTable.Add(ThisObject.ReportSpreadsheetDocument, ThisObject.ReportCurrentVariantName);
	
	FormTitle = StrReplace(NStr("en='Send report ""%1"" by email.';ru='Отправка отчета ""%1"" по почте'"), "%1", ThisObject.ReportCurrentVariantName);
	
	FormParameters = New Structure;
	FormParameters.Insert("DocumentsTable", DocumentsTable);
	FormParameters.Insert("Subject",               ThisObject.ReportCurrentVariantName);
	FormParameters.Insert("Title",          FormTitle);
	
	OpenForm("CommonForm.SendingSpreadsheetDocumentsByEmail", FormParameters, , );
EndProcedure

&AtClient
Procedure Generate()
	
	// StandardSubsystems.PerformanceEstimation
	PerformMeteringPerformance = Not KeyOperation.IsEmpty();
	If PerformMeteringPerformance Then
		OperationsStartTime = PerformanceEstimationClientServer.TimerValue();
	EndIf;
	// End StandardSubsystems.PerformanceEstimation
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase
		Or TypeOf(ReportSettings.ReportRef) = Type("String") Then
		GenerateDirectly();
		
		// StandardSubsystems.PerformanceEstimation
		If PerformMeteringPerformance Then
			PerformanceEstimationClientServer.EndTimeMeasurement(
			KeyOperation, 
			OperationsStartTime
			);
		EndIf;
		// End StandardSubsystems.PerformanceEstimation
		
	Else
		HandlerRequired = BackGroundJobStart();
		If HandlerRequired Then
			LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
			AttachIdleHandler("BackgroundJobCheckAtClient", 1, True);
		Else
			// StandardSubsystems.PerformanceEstimation
			If PerformMeteringPerformance Then
				PerformanceEstimationClientServer.EndTimeMeasurement(
				KeyOperation, 
				OperationsStartTime
				);
			EndIf;
			// End StandardSubsystems.PerformanceEstimation
		EndIf;
	EndIf;
	
	StateBeforeChange = New Structure("Visibile, AdditionalShowMode, Picture, Text");
	FillPropertyValues(StateBeforeChange, Items.ReportSpreadsheetDocument.StatePresentation);
	
	Report.SettingsComposer.UserSettings.AdditionalProperties.Delete("GenerateOnOpening");
	
	FillPropertyValues(Items.ReportSpreadsheetDocument.StatePresentation, StateBeforeChange);
EndProcedure

&AtClient
Procedure VisibleEnabledIfNeeded()
	If PanelVariantsCurrentVariantKey <> " - " Then // Changes are already applied
		Return;
	EndIf;
	VisibleEnabledCorrectness("");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Procedure VisibleEnabledCorrectness(Changes = "")
	ShowReportOptionsCommands = ReportVariantMode AND ReportVariantsCommandsVisible;
	
	If Changes = "" Then
		// Calculate display parameters.
		IsSettings = ThereAreQuickSettings Or ThereAreCommonSettings;
		
		// Apply display parameters.
		Items.AllSettings_Left.Visible = ShowReportOptionsCommands Or ThereAreCommonSettings;
		Items.AllSettings.Visible       = ShowReportOptionsCommands Or ThereAreCommonSettings;
		Items.GroupReportSettings_Left.Visible = ShowReportOptionsCommands;
		Items.ChooseVariant.Visible              = ShowReportOptionsCommands AND Not EncryptingMode;
		Items.SaveVariant.Visible            = ShowReportOptionsCommands;
		Items.ChangeVariant.Visible             = ShowReportOptionsCommands;
		Items.GroupUserSettings.Visible = ShowReportOptionsCommands AND IsSettings;
		
		// Generate immediately.
		Items.FormImmediately.Check = ReportSettings.FormImmediately;
	EndIf;
	
	// Variants selection commands.
	If PanelVariantsCurrentVariantKey <> CurrentVariantKey Then
		PanelVariantsCurrentVariantKey = CurrentVariantKey;
		
		If ShowReportOptionsCommands Then
			FillOptionSelectionCommands();
		EndIf;
		
		If OutputRight Then
			Uniqueness = ReportSettings.FullName;
			If ValueIsFilled(CurrentVariantKey) Then
				Uniqueness = Uniqueness + "/VariantKey." + CurrentVariantKey;
			EndIf;
			
			WindowOptionsKey = Uniqueness;
			
			ReportSettings.Print.Insert("PrintParametersKey", Uniqueness);
			RestorePrintingSettings();
		EndIf;
	EndIf;
	
	// Title.
	ReportCurrentVariantName = TrimAll(ReportCurrentVariantName);
	If ValueIsFilled(ReportCurrentVariantName) Then
		Title = ReportCurrentVariantName;
	Else
		Title = ReportSettings.Description;
	EndIf;
	If EncryptingMode Then
		Title = Title + " (" + NStr("en='Details';ru='Расшифровка'") + ")";
	EndIf;
	
EndProcedure

&AtServer
Procedure QuickSettingsFill(Val FillingParameters)
	
	// Insert default values for mandatory keys of the filling parameters.
	QuickSettingsFinishFillingParameters(FillingParameters);
	
	If ReportSettings.Events.BeforeFillingQuickSettingsPanel
		Or ReportSettings.Events.AfterFillingQuickSettingsPanel Then
		ReportObject = FormAttributeToValue("Report");
	EndIf;
	
	// Call a predefined module.
	If ReportSettings.Events.BeforeFillingQuickSettingsPanel Then
		ReportObject.BeforeFillingQuickSettingsPanel(ThisObject, FillingParameters);
	Else
		ReportsOverridable.BeforeFillingQuickSettingsPanel(ThisObject, FillingParameters);
	EndIf;
	
	// Write new variant settings and custom settings in the linker.
	QuickSettingsLoadSettingsToLinker(FillingParameters);
	
	// Receive information from DC
	OutputConditions = New Structure;
	OutputConditions.Insert("OnlyCustom", True);
	OutputConditions.Insert("OnlyQuick",          True);
	OutputConditions.Insert("CurrentCDHostIdentifier", Undefined);
	Information = ReportsServer.ExtendedInformationAboutSettings(Report.SettingsComposer, ThisObject, OutputConditions);
	ThereAreQuickSettings = Information.ThereAreQuickSettings;
	ThereAreCommonSettings = Information.ThereAreCommonSettings;
	
	// Delete items of old settings.
	QuickSettingsDeleteOldItemsAndCommands(FillingParameters);
	
	// Add items of actual settings and import values.
	QuickSettingsCreateControlItemsAndLoadValues(FillingParameters, Information);
	
	// Links.
	RegisterDisabledLinks(Information);
	
	// Process additional settings.
	AfterChangingKeyStates(FillingParameters);
	
	// Title, visible/accessibility of items, parameters of printing and window.
	VisibleEnabledCorrectness("");
	
	// Call a predefined module.
	If ReportSettings.Events.AfterFillingQuickSettingsPanel Then
		ReportObject.AfterFillingQuickSettingsPanel(ThisObject, FillingParameters);
	Else
		ReportsOverridable.AfterFillingQuickSettingsPanel(ThisObject, FillingParameters);
	EndIf;
	
	If ReportSettings.Property("ReportObject") Then
		ReportSettings.Delete("ReportObject");
	EndIf;
	
EndProcedure

&AtServer
Function ContextServerCall(OperationKey, OperationParameters)
	ResultOfCall = New Structure;
	If ReportSettings.Events.ContextServerCall Then
		ReportObject = FormAttributeToValue("Report");
		ReportObject.ContextServerCall(ThisObject, OperationKey, OperationParameters, ResultOfCall);
	Else
		ReportsOverridable.ContextServerCall(ThisObject, OperationKey, OperationParameters, ResultOfCall);
	EndIf;
	Return ResultOfCall;
EndFunction

&AtServer
Procedure GenerateDirectly()
	
	AdditProperties = Report.SettingsComposer.UserSettings.AdditionalProperties;
	
	// Generate report.
	AdditProperties.Insert("VariantKey", CurrentVariantKey);
	SavePrintingSettings();
	ErrorInfo = Undefined;
	Try
		ComposeResult(ResultCompositionMode.Auto);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	AdditProperties.Delete("VariantKey");
	RestorePrintingSettings();
	
	If ErrorInfo <> Undefined Then
		FormationErrorsShow(ErrorInfo);
		Return;
	EndIf;
	
	// Refill settings.
	GenerationResult = New Structure;
	GenerationResult.Insert("VariantModified", False);
	GenerationResult.Insert("UserSettingsModified", False);
	If CommonUseClientServer.StructureProperty(AdditProperties, "VariantModified") = True Then
		GenerationResult.VariantModified = True;
	EndIf;
	If GenerationResult.VariantModified
		Or CommonUseClientServer.StructureProperty(AdditProperties, "UserSettingsModified") = True Then
		GenerationResult.UserSettingsModified = True;
	EndIf;
	AdditProperties.Delete("VariantModified");
	AdditProperties.Delete("UserSettingsModified");
	
	If GenerationResult.VariantModified
		Or GenerationResult.UserSettingsModified Then
		GenerationResult.Insert("Event", New Structure);
		GenerationResult.Event.Insert("Name", "AfterGenerating");
		GenerationResult.Event.Insert("Directly", True);
		QuickSettingsFill(GenerationResult);
	EndIf;
EndProcedure

&AtServer
Function BackGroundJobStart()
	AdditProperties = Report.SettingsComposer.UserSettings.AdditionalProperties;
	
	GenerateOnOpening = CommonUseClientServer.StructureProperty(AdditProperties, "GenerateOnOpening", False);
	If Not CheckFilling() Then
		If GenerateOnOpening Then
			ErrorText = "";
			Messages = GetUserMessages(True);
			For Each Message In Messages Do
				ErrorText = ErrorText + ?(ErrorText = "", "", ";" + Chars.LF + Chars.LF) + Message.Text;
			EndDo;
			FormationErrorsShow(ErrorText);
		EndIf;
		Return False;
	EndIf;
	
	// Background job launch
	AdditProperties.Insert("VariantKey", CurrentVariantKey);
	
	ReportGenerationParameters = New Structure;
	ReportGenerationParameters.Insert("ReportRef", ReportSettings.ReportRef);
	ReportGenerationParameters.Insert("Settings",                 Report.SettingsComposer.Settings);
	ReportGenerationParameters.Insert("FixedSettings",    Report.SettingsComposer.FixedSettings);
	ReportGenerationParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	
	ErrorInfo = Undefined;
	Try
		BackgroundJobResult = LongActions.ExecuteInBackground(
			UUID,
			"ReportsVariants.GenerateReport",
			ReportGenerationParameters,
			NStr("en='Reports variants: Generate report';ru='Варианты отчетов: Формирование отчета'"));
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	AdditProperties.Delete("VariantKey");
	If ErrorInfo <> Undefined Then
		FormationErrorsShow(ErrorInfo);
		Return False;
	EndIf;
	
	BackgroundJobID  = BackgroundJobResult.JobID;
	BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
	
	If BackgroundJobResult.JobCompleted Then
		BackgroundJobImportResult();
		JobStarted = False;
	Else
		StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
		StatePresentation.Visible                      = True;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
		StatePresentation.Picture                       = PictureLib.LongOperation48;
		StatePresentation.Text                          = NStr("en='Generating the report...';ru='Отчет формируется...'");
		
		JobStarted = True;
	EndIf;
	
	Return JobStarted;
	
EndFunction

&AtServer
Function BackGroundJobFinished()
	Try
		JobCompleted = LongActions.JobCompleted(BackgroundJobID);
	Except
		FormationErrorsShow(ErrorInfo());
		Raise;
	EndTry;
	
	If JobCompleted Then
		BackgroundJobImportResult();
	EndIf;
	
	Return JobCompleted;
EndFunction

&AtServerNoContext
Procedure BackgroundJobCancel(BackgroundJobID)
	LongActions.CancelJobExecution(BackgroundJobID);
EndProcedure

&AtServerNoContext
Function CalculateSummServer(Val ReportSpreadsheetDocument, Val SelectedAreas)
	Return StandardSubsystemsClientServer.CellsAmount(ReportSpreadsheetDocument, SelectedAreas);
EndFunction

&AtServer
Procedure LoadVariant(VariantKey)
	SetCurrentVariant(VariantKey);
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture  = PictureLib.Information32;
	StatePresentation.Text     = NStr("en='Another report option is selected. Click Create to generate the report.';ru='Выбран другой вариант отчета. Нажмите ""Сформировать"" для получения отчета.'");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

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
	If Not FillingParameters.Property("ResetUserSettings") Then
		FillingParameters.Insert("ResetUserSettings", False);
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsLoadSettingsToLinker(FillingParameters)
	If FillingParameters.Property("DCSettingsComposer") Then
		Report.SettingsComposer.LoadSettings(FillingParameters.DCSettingsComposer.Settings);
		Report.SettingsComposer.LoadUserSettings(FillingParameters.DCSettingsComposer.UserSettings);
	EndIf;
	
	If FillingParameters.Property("DCSettings") Then
		Report.SettingsComposer.LoadSettings(FillingParameters.DCSettings);
	EndIf;
	
	If FillingParameters.Property("DCUserSettings") Then
		Report.SettingsComposer.LoadUserSettings(FillingParameters.DCUserSettings);
	EndIf;
	
	If FillingParameters.ResetUserSettings Then
		EmptyLinker = New DataCompositionSettingsComposer;
		Report.SettingsComposer.LoadUserSettings(EmptyLinker.UserSettings);
	EndIf;
	
	If FillingParameters.Property("SettingsFormExtendedMode") Then
		ReportSettings.Insert("SettingsFormExtendedMode", FillingParameters.SettingsFormExtendedMode);
	EndIf;
	If FillingParameters.Property("SettingsFormPageName") Then
		ReportSettings.Insert("SettingsFormPageName", FillingParameters.SettingsFormPageName);
	EndIf;
	
	If FillingParameters.VariantModified Then
		VariantModified = True;
	EndIf;
	
	If FillingParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;
	
	If ReportSettings.ReadCheckBoxGenerateImmediatelyFromUserSettings Then
		ReportSettings.ReadCheckBoxGenerateImmediatelyFromUserSettings = False;
		ReportSettings.FormImmediately = CommonUseClientServer.StructureProperty(
			Report.SettingsComposer.UserSettings.AdditionalProperties,
			"FormImmediately",
			ReportSettings.FormImmediately);
	EndIf;
EndProcedure

&AtServer
Procedure QuickSettingsDeleteOldItemsAndCommands(FillingParameters)
	// Delete items.
	DeletedItems = New Array;
	AddChildItems(DeletedItems, Items.QuickSettings.ChildItems);
	For Each Item In DeletedItems Do
		Items.Delete(Item);
	EndDo;
	
	// Delete commands
	DeletedCommands = New Array;
	For Each Command In Commands Do
		If ConstantCommands.FindByValue(Command.Name) = Undefined Then
			DeletedCommands.Add(Command);
		EndIf;
	EndDo;
	For Each Command In DeletedCommands Do
		Commands.Delete(Command);
	EndDo;
EndProcedure

&AtServer
Procedure AddChildItems(Where, From)
	For Each SubordinateItem In From Do
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
	
	// Delete attributes
	FillingParameters.Insert("Attributes", New Structure);
	FillingParameters.Attributes.Insert("Adding",  New Array);
	FillingParameters.Attributes.Insert("ToDelete",    New Array);
	FillingParameters.Attributes.Insert("Existing", New Map);
	AllAttributes = GetAttributes();
	For Each Attribute In AllAttributes Do
		AttributeFullName = Attribute.Name + ?(IsBlankString(Attribute.Path), "", "." + Attribute.Path);
		If ConstantAttributes.FindByValue(AttributeFullName) = Undefined Then
			FillingParameters.Attributes.Existing.Insert(AttributeFullName, Attribute.ValueType);
		EndIf;
	EndDo;
	
	// Local variables for setting values and properties after creation of attributes.
	AddedInputFields          = New Structure;
	AddedStandardPeriods = New Array;
	
	// Links structure.
	Links = Information.Links;
	
	MainFormAttributesNames     = New Map;
	NamesOfElementsForLinksSetup = New Map;
	UsageFlagsNames        = New Map;
	SettingsWithComparisonTypeEqual    = New Map;
	
	DCSettingsComposer       = Report.SettingsComposer;
	DCUserSettings = DCSettingsComposer.UserSettings;
	DCSettings                 = DCSettingsComposer.GetSettings();
	
	AdditionalItemsSettings = CommonUseClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	SettingTemplate = New Structure("Type, Subtype,
		|Template, TreeRow, DCUserSetting, Identifier, DCVariantSetting, AvailableDCSetting");
	SettingTemplate.Insert("Hierarchy", False);
	SettingTemplate.Insert("CheckboxUsing", False);
	SettingTemplate.Insert("EnterByList", False);
	SettingTemplate.Insert("LimitChoiceWithSpecifiedValues", False);
	SettingTemplate = New FixedStructure(SettingTemplate);
	
	OutputGroups = New Structure;
	OutputGroups.Insert("Fast", New Structure("Order, Size", New Array, 0));
	
	HasDataLoadFromFile = CommonUse.SubsystemExists("StandardSubsystems.DataLoadFromFile");
	
	OutputSettings = Information.UserSettings.Copy(New Structure("OutputAllowed, Quick", True, True));
	OutputSettings.Sort("IndexInCollection Asc");
	
	Other = New Structure;
	Other.Insert("Links",       Links);
	Other.Insert("ReportObject", Undefined);
	Other.Insert("FillingParameters",       FillingParameters);
	Other.Insert("PathToLinker",         "Report.SettingsComposer");
	Other.Insert("HasDataLoadFromFile", HasDataLoadFromFile);
	Other.Insert("AdditionalItemsSettings",   AdditionalItemsSettings);
	Other.Insert("MainFormAttributesNames",       MainFormAttributesNames);
	Other.Insert("NamesOfElementsForLinksSetup",   NamesOfElementsForLinksSetup);
	Other.Insert("MapMetadataObjectName", MapMetadataObjectName);
	Other.Insert("AddedInputFields",          AddedInputFields);
	Other.Insert("AddedStandardPeriods", AddedStandardPeriods);
	Other.Insert("AddedValueLists",     Undefined);
	
	For Each SettingProperty In OutputSettings Do
		UserSettingsMap.Insert(SettingProperty.ItemIdentificator, SettingProperty.DCIdentifier);
		OutputGroup = OutputGroups.Fast;
		ReportsServer.OutputSettingItems(ThisObject, Items, SettingProperty, OutputGroup, Other);
	EndDo;
	
	ReportsServer.PutInOrder(ThisObject, OutputGroups.Fast, Items.QuickSettings, 2, False);
	
	// Delete old and add new attributes.
	For Each KeyAndValue In FillingParameters.Attributes.Existing Do
		FillingParameters.Attributes.ToDelete.Add(KeyAndValue.Key);
	EndDo;
	ChangeAttributes(FillingParameters.Attributes.Adding, FillingParameters.Attributes.ToDelete);
	
	// Input fields (set values and links).
	For Each KeyAndValue In AddedInputFields Do
		AttributeName = KeyAndValue.Key;
		ThisObject[AttributeName] = KeyAndValue.Value;
		Items[AttributeName].DataPath = AttributeName;
	EndDo;
	
	// Standard periods (set values and links).
	For Each SettingProperty In AddedStandardPeriods Do
		Additionally = SettingProperty.Additionally;
		ThisObject[Additionally.ValueName]      = SettingProperty.Value;
		ThisObject[Additionally.PeriodKindName]    = Additionally.PeriodKind;
		ThisObject[Additionally.AuthorPresentationActualName] = Additionally.Presentation;
		Items[Additionally.PeriodKindName].DataPath    = Additionally.PeriodKindName;
		Items[Additionally.AuthorPresentationActualName].DataPath = Additionally.AuthorPresentationActualName;
		Items[Additionally.BeginOfPeriodName].DataPath    = Additionally.ValueName + ".StartDate";
		Items[Additionally.EndOfPeriodName].DataPath = Additionally.ValueName + ".EndDate";
	EndDo;
	
	// Save matches for a quick search to a form data.
	FastSearchOfUserSettings = New FixedMap(UserSettingsMap);
	QuickSearchMetadataObjectName   = New FixedMap(MapMetadataObjectName);
	DisablingLinksFastSearch        = New FixedMap(DisablingLinksMap);
	
	DCUserSettings.AdditionalProperties.Insert("FormItems", AdditionalItemsSettings);
EndProcedure

&AtServer
Procedure SavePrintingSettings()
	FillPropertyValues(ReportSettings.Print, ReportSpreadsheetDocument);
EndProcedure

&AtServer
Procedure RestorePrintingSettings()
	FillPropertyValues(ReportSpreadsheetDocument, ReportSettings.Print);
EndProcedure

&AtServer
Procedure BackgroundJobImportResult()
	
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible                      = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture                       = New Picture;
	StatePresentation.Text                          = "";
	
	GenerationResult = GetFromTempStorage(BackgroundJobStorageAddress);
	
	If GenerationResult = Undefined Then
		
		GenerateDirectly();
		
	Else
		
		SavePrintingSettings();
		ReportSpreadsheetDocument = GenerationResult.ReportSpreadsheetDocument;
		RestorePrintingSettings();
		
		If ValueIsFilled(ReportDetailsData) AND IsTempStorageURL(ReportDetailsData) Then
			DeleteFromTempStorage(ReportDetailsData);
		EndIf;
		ReportDetailsData = PutToTempStorage(GenerationResult.ReportDetails, UUID);
		
		If GenerationResult.VariantModified
			Or GenerationResult.UserSettingsModified Then
			GenerationResult.Insert("Event", New Structure);
			GenerationResult.Event.Insert("Name", "AfterGenerating");
			GenerationResult.Event.Insert("Directly", False);
			QuickSettingsFill(GenerationResult);
		EndIf;
		
	EndIf;
	
	DeleteFromTempStorage(BackgroundJobStorageAddress);
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID = Undefined;
	
EndProcedure

&AtServer
Procedure FormationErrorsShow(ErrorInfo)
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		ErrorDescription = ReportsClientServer.BriefErrorDescriptionOfReportFormation(ErrorInfo);
		DetailErrorDescription = NStr("en='An error occurred while generating:';ru='Ошибка при формировании:'") + Chars.LF + DetailErrorDescription(ErrorInfo);
		If IsBlankString(ErrorDescription) Then
			ErrorDescription = DetailErrorDescription;
		EndIf;
	Else
		ErrorDescription = ErrorInfo;
		DetailErrorDescription = "";
	EndIf;
	
	StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
	StatePresentation.Visible                      = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture                       = New Picture;
	StatePresentation.Text                          = ErrorDescription;
	
	If Not IsBlankString(DetailErrorDescription) Then
		ReportsVariants.WarningByOption(ReportSettings.VariantRef, DetailErrorDescription);
	EndIf;
EndProcedure

&AtServer
Procedure DCRecursiveSettingsAnalyzes(Collection, Map)
	If Collection = Undefined Then
		DCRecursiveSettingsAnalyzes(Report.SettingsComposer.Settings.Filter.Items, Map);
		DCRecursiveSettingsAnalyzes(Report.SettingsComposer.Settings.DataParameters.Items, Map);
		DCRecursiveSettingsAnalyzes(Report.SettingsComposer.FixedSettings.Filter.Items, Map);
		DCRecursiveSettingsAnalyzes(Report.SettingsComposer.FixedSettings.DataParameters.Items, Map);
	Else
		// Registration of enabled filters and DC parameters values that are not output to the quick search.
		For Each VariantSetting In Collection Do
			// DataCompositionFilterItem,
			// DataCompositionFilterItemGroup, DataCompositionParameterValue, DataCompositionSettingsParameterValue.
			If TypeOf(VariantSetting) = Type("DataCompositionParameterValue") Then
				Value = VariantSetting.Value;
				If ValueOrDataCompositionFieldFilled(Value) Then
					DCField = New DataCompositionField("DataParameters." + String(VariantSetting.Parameter));
					Map.Insert(DCField, Value);
				EndIf;
				DCRecursiveSettingsAnalyzes(VariantSetting.NestedParameterValues, Map);
				Continue;
			EndIf;
			
			If VariantSetting.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess
				AND ValueIsFilled(VariantSetting.UserSettingID) Then
				Continue;
			EndIf;
			If VariantSetting.Use <> True Then
				Continue;
			EndIf;
			
			If TypeOf(VariantSetting) = Type("DataCompositionFilterItemGroup") Then
				DCRecursiveSettingsAnalyzes(VariantSetting.Items, Map);
				Continue;
			EndIf;
			
			If TypeOf(VariantSetting) = Type("DataCompositionFilterItem") Then
				Value = VariantSetting.RightValue;
				If ValueOrDataCompositionFieldFilled(Value) Then
					DCField = VariantSetting.LeftValue;
					Map.Insert(DCField, Value);
				EndIf;
			ElsIf TypeOf(VariantSetting) = Type("DataCompositionParameterValue") Then
				Value = VariantSetting.RightValue;
				If ValueOrDataCompositionFieldFilled(Value) Then
					DCField = New DataCompositionField("DataParameters." + String(VariantSetting.Parameter));
					Map.Insert(DCField, Value);
				EndIf;
				DCRecursiveSettingsAnalyzes(VariantSetting.NestedParameterValues, Map);
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function ValueOrDataCompositionFieldFilled(Value)
	If TypeOf(Value) = Type("DataCompositionField") Then
		Return ValueIsFilled(String(Value));
	Else
		Return ValueIsFilled(Value);
	EndIf;
EndFunction

&AtServer
Procedure FillOptionSelectionCommands()
	FormOptions = FormAttributeToValue("AddedVariants");
	FormOptions.Columns.Add("found", New TypeDescription("Boolean"));
	
	SearchParameters = New Structure;
	SearchParameters.Insert("Reports", ReportsClientServer.ValueInArray(ReportSettings.ReportRef));
	SearchParameters.Insert("DeletionMark", False);
	SearchParameters.Insert("ReceiveSummaryTable", True);
	SearchResult = ReportsVariants.FindReferences(SearchParameters);
	VariantTable = SearchResult.ValueTable;
	If ReportSettings.External Then // Add predefined options of the external report to the options table.
		For Each ItemOfList In ReportSettings.PredefinedVariants Do
			TableRow = VariantTable.Add();
			TableRow.Description = ItemOfList.Presentation;
			TableRow.VariantKey = ItemOfList.Value;
		EndDo;
	EndIf;
	VariantTable.GroupBy("Ref, VariantKey, Description");
	VariantTable.Sort("Description Asc, VariantKey Asc");
	
	GroupVar = Items.ReportVariants_Left;
	GroupButtons = GroupVar.ChildItems;
	LastIndex = FormOptions.Count() - 1;
	For Each TableRow In VariantTable Do
		Found = FormOptions.FindRows(New Structure("VariantKey, Found", TableRow.VariantKey, False));
		If Found.Count() = 1 Then
			FormVariant = Found[0];
			FormVariant.found = True;
			Button = Items.Find(FormVariant.CommandName);
			Button.Visible = True;
			Button.Title = TableRow.Description;
			Items.Move(Button, GroupVar);
		Else
			LastIndex = LastIndex + 1;
			FormVariant = FormOptions.Add();
			FillPropertyValues(FormVariant, TableRow);
			FormVariant.found = True;
			FormVariant.CommandName = "ChooseVariant_" + Format(LastIndex, "NZ=0; NG=");
			
			Command = Commands.Add(FormVariant.CommandName);
			Command.Action = "Attachable_LoadReportVariant";
			
			Button = Items.Add(FormVariant.CommandName, Type("FormButton"), GroupVar);
			Button.Type = FormButtonType.CommandBarButton;
			Button.CommandName = FormVariant.CommandName;
			Button.Title = TableRow.Description;
			
			ConstantCommands.Add(FormVariant.CommandName);
		EndIf;
		Button.Check = (ReportSettings.VariantRef = FormVariant.Ref);
	EndDo;
	
	Found = FormOptions.FindRows(New Structure("found", False));
	For Each FormVariant In Found Do
		Button = Items.Find(FormVariant.CommandName);
		Button.Visible = False;
	EndDo;
	
	FormOptions.Columns.Delete("found");
	ValueToFormAttribute(FormOptions, "AddedVariants");
EndProcedure

&AtServer
Procedure AfterChangingKeyStates(FillingParameters)
	If FillingParameters.Event.Name <> "AfterGenerating" Then
		Regenerate = CommonUseClientServer.StructureProperty(FillingParameters, "Regenerate");
		If Regenerate = True Then
			StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			StatePresentation.Picture                       = PictureLib.LongOperation48;
			StatePresentation.Text                          = NStr("en='Generating the report...';ru='Отчет формируется...'");
		ElsIf FillingParameters.VariantModified
			Or FillingParameters.UserSettingsModified
			Or FillingParameters.ResetUserSettings Then
			StatePresentation = Items.ReportSpreadsheetDocument.StatePresentation;
			StatePresentation.Visible = True;
			StatePresentation.Text     = NStr("en='Settings have been changed. Click Create to generate the report.';ru='Изменились настройки. Нажмите ""Сформировать"" для получения отчета.'");
			If Regenerate = Undefined Then
				StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			Else
				StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure RegisterDisabledLinks(Information)
	DisabledLinks.Clear();
	For Each LinkDescription In Information.DisabledLinks Do
		Link = DisabledLinks.Add();
		FillPropertyValues(Link, LinkDescription);
		Link.LeadingIdentifierInForm     = LinkDescription.Leading.ItemIdentificator;
		Link.SubordinateIdentifierInForm = LinkDescription.subordinated.ItemIdentificator;
	EndDo;
EndProcedure

#EndRegion














