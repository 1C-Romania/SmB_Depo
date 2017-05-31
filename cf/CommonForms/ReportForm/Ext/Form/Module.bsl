
&AtClient
Var ClientVariables;

#Region FromHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// need report metadata for synonym and list of attributes
	ReportObject = FormAttributeToValue("Report");
	ReportMetadata = ReportObject.Metadata();
	ReportMetadataName = "Report."+ReportMetadata.Name;
	SetupObject = StrReplace(ReportMetadataName,"Report.","ReportObject.");
		
	// storing synonym
	ReportSynonym = ReportMetadata.Synonym;

	// get list of bookkeeping parameters
	BookkeepingParametersArray = BookkeepingAtServer.GetBookeepingParametersArray();
	
	// create list of mandatory data parameters from schema
	TempMandatoryAttributes = New Map;
	For Each SchemaParameter In ReportObject.DataCompositionSchema.Parameters Do
		
		If SchemaParameter.DenyIncompleteValues Then
			TempMandatoryAttributes.Insert(SchemaParameter.Name);
		EndIf;	
		
	EndDo;	
	
	MandatoryAttributes = New FixedMap(TempMandatoryAttributes);

	// list of report attributes to sync settings saving between data parameters and attributes
	TempReportAttributes = New Map;
	For Each Attribute In ReportMetadata.Attributes Do
		
		If Attribute.Name = "PeriodSettings" Then
			Continue;
		EndIf;
		
		TempReportAttributes.Insert(Attribute.Name);
		
	EndDo;	
	
	ReportAttributes = New FixedMap(TempReportAttributes);
	
	// create all predefined variants if needed
	CreateVariantsAsSettings(ReportObject.DataCompositionSchema.SettingVariants);
	
	// setup filter to report settings field
	NewArray = New Array;
	NewArray.Add(New ChoiceParameter("Filter.Owner", SessionParameters.CurrentUser));
	NewArray.Add(New ChoiceParameter("Filter.SetupObject", SetupObject));
	NewParameters = New FixedArray(NewArray);

	Items.ReportSetting.ChoiceParameters = NewParameters;
	
	If Parameters.Property("Details") 
		AND Parameters.Details <> Undefined 
		AND NOT IsBlankString(Parameters.Details.Data) Then
		IsDetailed = True;
	Else
		// get last used setting
		CurrentVariantKey = SystemSettingsStorage.Load(ReportMetadataName+"/CurrentVariantKey");
		If CurrentVariantKey = Undefined Then
			CurrentVariantKey = "";
		EndIf;	
		
		LoadReportSettingsByKey(CurrentVariantKey);
	EndIf;

		
EndProcedure

&AtServer
Procedure OnLoadVariantAtServer(Settings)
	
	If IsDetailed Then
		// drilldown processing
				
		For Each FilterItem In Report.SettingsComposer.Settings.Filter.Items Do
			FilterItem.UserSettingID = New UUID;
			FilterItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
		EndDo;	
		
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",TmpSettingPresentation);
		
		ReportSetting = Catalogs.SavedSettings.EmptyRef();
		Report.SettingsComposer.Settings.AdditionalProperties.Clear();
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("IsDetailed",True);
		
		AfterLoadSettings();
		// force filter showing for details
		ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings,"ShowQuickFilter",True);
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("DetailsSettingPresentation",TmpSettingPresentation);	
		SetFormTitle();
		
	EndIf;	
		
	VariantModified = False;
	UserSettingsModified = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// restore CurrentVariantPresentation and CurrentVariantDescription they have been overwritte in OnLoadVariantAtServer
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",CurrentVariantPresentation);
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",CurrentVariantDescription);
	
	// fill form attributes from schema
	InitVisualItems(True);
	
	// detected connection speed - used for field sum frequency
	ClientVariables = New Structure;
	ClientVariables.Insert("WaitInterval", ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2));
	
	#If NOT WebClient Then
	// need save "not changed" report presentation
	InitialStatePresentation = Items.Result.StatePresentation;	
	If IsDetailed Then
		Items.Result.StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		Items.Result.StatePresentation.Visible = False;
	EndIf;	
	#EndIf	

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	#If NOT ThickClientOrdinaryApplication Then
		If SaveAutomatically Then
			ApplyFormDataToSettings();
			If NOT IsBlankString(CurrentVariantKey) Then
			//  Jack to do 29.05.2017	
			//	CommonAtClient.PushReportSettings(ReportMetadataName,CurrentVariantKey,Report.SettingsComposer.Settings);
			//	SaveReportSettingUsingGlobalVariables();
			EndIf;	
			VariantModified = False;
			UserSettingsModified = False;
		ElsIf (VariantModified OR UserSettingsModified) 
				AND Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingOwner") 
				AND Report.SettingsComposer.Settings.AdditionalProperties.SettingOwner = ApplicationParameters.CurrentUser Then
			
			Cancel = True;
			ShowQueryBox(New NotifyDescription("SaveChangedVariantQueryChoiceProcessing",ThisForm),
						Nstr("en='Report settings have been changed. Do you want to save settings?';pl='Ustawienia raportu zostały zmienione. Czy chcesz je zapisać?';ru='Настройки отчета были изменены. Хотите сохранить настройки?'"),
						QuestionDialogMode.YesNoCancel,
						,DialogReturnCode.Yes);
						
		Else
			VariantModified = False;
			UserSettingsModified = False;			
		EndIf;		
	#EndIf
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
		
	For Each MapItem In MandatoryAttributes Do
		
		CheckedAttributes.Add(MapItem.Key);
		
	EndDo;	
	
EndProcedure

#EndRegion

#Region ReportParametersOnFormHandlers

&AtClient
Procedure AnyPeriodOnChange(Item)
	
	ApplyPeriodChanges();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ApplyBookkeepingAttributeChange("Company");
		
EndProcedure

&AtClient
Procedure CashDeskOnChange(Item)
	
	ApplyBookkeepingAttributeChange("CashDesk");
	
EndProcedure

&AtClient
Procedure DuesAndDebtsPeriodsOnChange(Item)

	ApplyBookkeepingAttributeChange("DuesAndDebtsPeriods");
	
EndProcedure

&AtClient
Procedure PartialJournalOnChange(Item)
	ApplyBookkeepingAttributeChange("PartialJournal");
EndProcedure

&AtClient
Procedure AccountOnChange(Item)
	BookkeepingAttributeOnChange("Account");
	ApplyBookkeepingAttributeChange("Account");
EndProcedure

&AtClient
Procedure FinancialYearOnChange(Item)
	
	ApplyBookkeepingAttributeChange("FinancialYear");
	// financial year should be visible in header
	SetReportTitle();

EndProcedure

&AtClient
Procedure ShowClosePeriodRecordsOnChange(Item)
	ApplyBookkeepingAttributeChange("ShowClosePeriodRecords");
EndProcedure

&AtClient
Procedure OutputPageTotalsOnChange(Item)
	ApplyBookkeepingAttributeChange("OutputPageTotals");	
EndProcedure

#EndRegion

#Region FormItemsHandlers

&AtClient
Procedure ResultOnActivateArea(Item)
	AttachIdleHandler("CalculateCellsAmount", ClientVariables.WaitInterval, True);
EndProcedure

&AtClient
Procedure ReportSettingOnChange(Item)
	
	// don't let user have empty settings
	If ReportSetting.IsEmpty() Then
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingRef",ReportSetting);
		Return;
	EndIf;
	
	// if we were in detailed settings and setting has been choosed manualy assume  
	// that user want to leave detailed settings
	If SaveAutomatically Then
		SaveReportSettingCommon();
	EndIf;	
	LoadReportSettingsByRef(ReportSetting);
	
	#If NOT WebClient Then
	FillPropertyValues(Items.Result.StatePresentation, InitialStatePresentation);
	#EndIf
	
	InitVisualItems();
	
EndProcedure

&AtClient
Procedure ReportSettingCreating(Item, StandardProcessing)
	
	StandardProcessing = False;	
	// save current setting
	SaveReportSettingAtServer();
	OpenForm(ReportMetadataName+".VariantForm",New Structure("RestoreFormData, BlankSettings",True,True),ThisForm,,,,New NotifyDescription("FinishSettingEdit",ThisObject,New Structure("BlankSettings")),FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure BlankSetting(Command)
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("BlankSetting",True);
	AdditionalParameters.Insert("CallBack",New NotifyDescription("BlankSettingResponse",ThisForm));
	AskForReportName(AdditionalParameters);
EndProcedure

&AtClient
Procedure BlankSettingResponse(Val Value,AdditionalParameters) Export
	
	// save previous setting
	If SaveAutomatically Then
		SaveReportSettingCommon();
	EndIf;	
	
	Value.Insert("BlankSettings");
	OpenForm(ReportMetadataName+".VariantForm",New Structure("RestoreFormData, BlankSettings, BlankSettingsName",True,True,Value.SettingName),ThisForm,,,,New NotifyDescription("FinishSettingEdit",ThisObject,Value),FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure	

#EndRegion

#Region CommandsHandlers

&AtClient
Procedure RunReport(Command)
	
	// Update user settings from form settings.
	ApplyFormDataToSettings();	
	
	// Skipping  fill check at server, forms one should be enough in case running from form
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("SkipFillCheck",True);
	
	// Build the report.
	ComposeResult();
	
	// Collapse groupings of the 1-st level.
	Result.ShowRowGroupLevel(1);
	
EndProcedure

&AtClient
Procedure SaveReportSetting(Command)
	If IsDetailed Then
		AdditionalParameters = New Structure();
		AdditionalParameters.Insert("CallBack",New NotifyDescription("SaveReportSettingResponse",ThisForm));
		AskForReportName(AdditionalParameters);
	Else
		SaveReportSettingCommon(,True);
	EndIf;
EndProcedure

&AtClient
Procedure SaveReportSettingResponse(Val Value,AdditionalParameters) Export
	
	SaveReportSettingCommon(True,True,Value.SettingName);
	
EndProcedure

&AtClient
Procedure CopySettings(Command)
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("CallBack",New NotifyDescription("CopySettingsResponse",ThisForm));
	AskForReportName(AdditionalParameters);
EndProcedure

&AtClient
Procedure CopySettingsResponse(Val Value,AdditionalParameters) Export
	
	SaveReportSettingCommon(True,True,Value.SettingName);
	
EndProcedure	

&AtClient
Procedure TurnOnAutoSaving(Command)
	SaveAutomatically = True;
	ShowHideAutoSaving(SaveAutomatically);
EndProcedure

&AtClient
Procedure TurnOffAutoSaving(Command)
	SaveAutomatically = False;
	ShowHideAutoSaving(SaveAutomatically);
EndProcedure

&AtClient
Procedure ReadOnlySettingCopy(Command)
	SaveReportSettingCommon(True,True);	
EndProcedure

&AtClient
Procedure EditSettings(Command)
	ApplyFormDataToSettings();	
	OpenForm(ReportMetadataName+".VariantForm",New Structure("RestoreFormData",True),ThisForm,,,,New NotifyDescription("FinishSettingEdit",ThisObject,New Structure),FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure FinishSettingEdit(Result,AdditionalSettings) Export
	
	If Result = True Then
		
		// read data from settings
		InitVisualItems();

		SetReportTitle();
		SetFormTitleAtClient();
		
		If AdditionalSettings.Property("BlankSettings")
			OR IsDetailed Then
			SaveAutomatically = True;
		EndIf;	
		
		If SaveAutomatically Then
			SaveReportSettingCommon(,True,Report.SettingsComposer.Settings.AdditionalProperties.SettingDescription,?(AdditionalSettings.Property("BlankSettings"),AdditionalSettings.FoundRef,Undefined));
		EndIf;	
		
		RunReport(Undefined);
		
	// if cancelling editing, and report was autosaved - need to reread
	// because additional settings are cleared up while saving settings
	ElsIf SaveAutomatically Then
	
		LoadReportSettingsByRef(ReportSetting);
		
	EndIf;	
	
EndProcedure	

&AtClient
Procedure SendEmail(Command)
	PrintDocumentsInfo = GetPrintDocumentsInfo();
	PrintManagerClient.SendReportByEMail(PrintDocumentsInfo);
EndProcedure

&AtClient
Procedure CalculateSum(Command)
	
	SelectedAreas = SpreadsheetFunctionsAtClient.SelectedAreas(Result);
	AutoSumValue = SpreadsheetFunctionsAtClientAtServer.GetCellsAmount(Result, SelectedAreas);
	Items.FormCalculateSum.Enabled = False;

EndProcedure

&AtClient
Procedure HideFilter(Command)
	ShowHideFilter(False);
	WriteShowFilter();
EndProcedure

&AtClient
Procedure ShowFilter(Command)
	
	ShowHideFilter(True);
	WriteShowFilter();
	
EndProcedure

&AtClient
Procedure ShowHeader(Command)
	ShowHideHeader(True);
	WriteShowHeader();
EndProcedure

&AtClient
Procedure HideHeader(Command)
	ShowHideHeader(False);
	WriteShowHeader();
EndProcedure

&AtClient
Procedure ChoosePeriodFromTo(Command)
	
	ChoiceParameters = New Structure("BeginOfPeriod,EndOfPeriod", BeginOfPeriod, EndOfPeriod);
	NotifyDescription = New NotifyDescription("ChoosePeriodFromToFinish", ThisObject);
	OpenForm("CommonForm.StandardPeriodChoiceForm", ChoiceParameters, Items.ChoosePeriodFromTo, , , , NotifyDescription);

EndProcedure

&AtClient
Procedure ChoosePeriodFromToFinish(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		BeginOfPeriod = Result.BeginOfPeriod;
		EndOfPeriod  = Result.EndOfPeriod;
	EndIf;
	
	ApplyPeriodChanges();
	
EndProcedure

#EndRegion

#Region OtherAtClient

&AtClient
Procedure InitVisualItems(Val IsOnOpen = False)
	
	ReadPeriods();
	ReadBookkeepingParameters();
	ReadQuickFilter(IsOnOpen);
	ReadShowHeader();
	
EndProcedure	

&AtClient
Procedure ReadPeriods()
	
	// data parameters changed because changing date should mark report as not actual
	
	DataParameters = Report.SettingsComposer.Settings.DataParameters;
	
	BeginPeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"BeginOfPeriod");
	ParameterEndPeriodValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"EndOfPeriod");
	PeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"Period");
	Items.GroupPeriodSettingsFromToPeriod.Visible = False;		
	Items.GroupPeriodSettingsSinglePeriodTab.Visible = False;			
	If BeginPeriodParameterValue <> Undefined 
		AND ParameterEndPeriodValue <> Undefined Then
		BeginOfPeriod = BeginPeriodParameterValue.Value;
		EndOfPeriod = ParameterEndPeriodValue.Value;		
		Items.GroupPeriodSettingsFromToPeriod.Visible = True;		
	ElsIf PeriodParameterValue <> Undefined Then
		Period = PeriodParameterValue.Value;
		Items.GroupPeriodSettingsSinglePeriodTab.Visible = True;			
	EndIf;
	
	SetReportTitle();
	
EndProcedure

&AtClient
Procedure BookkeepingAttributeOnChange(Val AttributeName)
	
	DataCompositionSchemaAdress = "";
	BookkeepingAtClient.BookkeepingAttributeOnChange(ReportMetadataName,AttributeName,ThisForm,Report.SettingsComposer,DataCompositionSchemaAdress);
	If NOT IsBlankString(DataCompositionSchemaAdress) Then
		SetDataCompositionSchema(DataCompositionSchemaAdress);
	EndIf;	
EndProcedure

&AtServer
Procedure SetDataCompositionSchema(Val DataCompositionSchemaAdress)
	Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchemaAdress));
	CreateUserSettingsFormItems();
EndProcedure	

&AtClient
Procedure ReadBookkeepingParameters()
		
	For Each BookkeepingParametersArrayItem In BookkeepingParametersArray Do
		
		CurrentParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,BookkeepingParametersArrayItem);
		
		If CurrentParameterValue <> Undefined Then
			Items[BookkeepingParametersArrayItem].Visible = True;		
			ThisForm[BookkeepingParametersArrayItem] = CurrentParameterValue.Value;
			BookkeepingAttributeOnChange(BookkeepingParametersArrayItem);
		Else
			Items[BookkeepingParametersArrayItem].Visible = False;		
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ReadQuickFilter(Val IsOnOpen = False)
	
	ShowQuickFilter = Undefined;
	ShowQuickFilterParameter = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"ShowQuickFilter");
	If ShowQuickFilterParameter = Undefined Then
		If IsOnOpen Then
		// if there is no data setting - assume it should be always true
			ShowQuickFilter = True;
		Else
		// no changes - keeping user selected option
		EndIf;	
	Else 
		ShowQuickFilter = ShowQuickFilterParameter.Value;
	EndIf;
	If ShowQuickFilter<> Undefined Then
		ShowHideFilter(ShowQuickFilter);
	EndIf;	

EndProcedure	

&AtClient
Procedure ReadShowHeader()
	
	ShowHeaderParameter = ReportsModulesAtClientAtServer.GetTitleOutputParameter(Report.SettingsComposer.Settings);
	If ShowHeaderParameter.Use AND ShowHeaderParameter.Value = DataCompositionTextOutputType.DontOutput Then
		ShowHideHeader(False);
	Else
		ShowHideHeader(True);
	EndIf;	

EndProcedure	

&AtServer
Procedure SetFormTitle()
	
	If Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation") Then
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + " " + Nstr("en='(detailed ';pl='(uszczegółowiony ';ru='(подробный '") + TmpSettingPresentation + ")";
	Else	
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + ?(IsBlankString(TmpSettingPresentation),""," ("+TmpSettingPresentation+")");
	EndIf;
	
EndProcedure	

&AtClient
Procedure SetReportTitle()
	Var LocalTitle;
	LocalTitle = ReportSynonym + " " + ReportsModulesAtClient.GetReportPeriodDescription(Report.SettingsComposer);
	TitleParameter = ReportsModulesAtClientAtServer.GetOutputParameter(Report.SettingsComposer.Settings,"Title");
	// dont use platforms SetParameterValue, because it's sets use mode, but it's controled other way in reports
	TitleParameter.Value = LocalTitle;
EndProcedure	

&AtClient
Procedure SetFormTitleAtClient()
	
	If Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation") Then
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + " " + Nstr("en='(detailed ';pl='(uszczegółowiony ';ru='(подробный '") + TmpSettingPresentation + ")";
	Else	
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + ?(IsBlankString(TmpSettingPresentation),""," ("+TmpSettingPresentation+")");
	EndIf;
	
EndProcedure	

&AtClient
Procedure ShowHideFilter(Val FilterVisible)
	
	Items.GroupUserSettingsFilter.Visible = FilterVisible;
	Items.HideFilter.Visible = FilterVisible;
	Items.ShowFilter.Visible = NOT FilterVisible;
		
EndProcedure

&AtClient
Procedure ShowHideHeader(Val HeaderVisible)
	
	Items.HideHeader.Visible = HeaderVisible;
	Items.ShowHeader.Visible = NOT HeaderVisible;
	
	FoundHeader = Result.Areas.Find("Header");
	If FoundHeader <> Undefined Then
		FoundHeader.Visible = HeaderVisible;
	EndIf;	
	
EndProcedure

&AtClient
Procedure ShowHideAutoSaving(Val FilterVisible)
	
	Items.TurnOnAutoSaving.Visible = NOT SaveAutomatically;
	Items.TurnOffAutoSaving.Visible =SaveAutomatically;
	
	ReturnResult = ReportsModulesAtServer.SetSettingSaveAutomaticallyByRef(ReportSetting,SaveAutomatically);	
	If ReturnResult.IsError Then
		CommonAtClientAtServer.NotifyUser(ReturnResult.ErrorDescription,,,"ReportSetting");
	EndIf;	

EndProcedure

&AtClient
Function GetPrintDocumentsInfo()
	
	PrintDocumentsInfo = New Array;

	Partner = Undefined;
	
	If PrintDocumentsInfo.Count() = 0 Then
		PrintDocumentsInfo.Add(New Structure("Description, Object, PrintOut, Partner", 
		"Report", Undefined, Result, Undefined));
	EndIf;
	
	Return New FixedArray(PrintDocumentsInfo);
	
EndFunction	

&AtClient
Procedure CalculateCellsAmount()
	AutoSumValue = SpreadsheetFunctionsAtClientAtServer.GetCellsAmount(Result, Undefined);
	Items.FormCalculateSum.Enabled = (AutoSumValue = "<");
EndProcedure

&AtClient
Procedure ApplyPeriodChanges()
	
	BeginPeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"BeginOfPeriod");
	EndPeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"EndOfPeriod");
	PeriodParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,"Period");
	
	If BeginPeriodParameterValue <> Undefined Then
		BeginPeriodParameterValue.Use = True;
		BeginPeriodParameterValue.Value = BeginOfPeriod;
	EndIf;
	
	If EndPeriodParameterValue <> Undefined Then
		EndPeriodParameterValue.Use = True;
		EndPeriodParameterValue.Value = ?(EndOfPeriod = '00010101', EndOfPeriod, EndOfDay(EndOfPeriod));
	EndIf;
	
	If PeriodParameterValue <> Undefined Then
		PeriodParameterValue.Use = True;
		PeriodParameterValue.Value = ?(Period = '00010101', Period, EndOfDay(Period));
		PeriodPresentation = Format(Period,"DLF=D");
	EndIf;
	
	SetReportTitle();
	
EndProcedure	

&AtClient
Procedure ApplyBookkeepingAttributeChange(Val AttributeName)

	ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings,AttributeName,ThisForm[AttributeName]);
	
EndProcedure	

&AtClient
Procedure WriteVisualItems()
	
	WriteBookkeepingParameters();
	WriteShowHeader();
	WriteShowFilter();
	
EndProcedure	

&AtClient
Procedure WriteBookkeepingParameters()
	
	For Each BookkeepingParametersArrayItem In BookkeepingParametersArray Do
		
		ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings,BookkeepingParametersArrayItem,ThisForm[BookkeepingParametersArrayItem]);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure WriteShowHeader()
	
	PrevResultState = Items.Result.StatePresentation.AdditionalShowMode;	
	If Items.HideHeader.Visible Then
		HeaderVisibility = DataCompositionTextOutputType.Output;
	Else 	
		HeaderVisibility = DataCompositionTextOutputType.DontOutput;
	EndIf;	
	ReportsModulesAtClientAtServer.SetTitleOutputParameter(Report.SettingsComposer.Settings,HeaderVisibility);
	
	#If NOT WebClient Then
	If PrevResultState = AdditionalShowMode.DontUse Then
		Items.Result.StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		Items.Result.StatePresentation.Visible = False;
	EndIf;
	#EndIf

EndProcedure

&AtClient
Procedure WriteShowFilter()
	
	PrevResultState = Items.Result.StatePresentation.AdditionalShowMode;	
	ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings,"ShowQuickFilter",Items.HideFilter.Visible);
	#If NOT WebClient Then
	If PrevResultState = AdditionalShowMode.DontUse Then
		Items.Result.StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		Items.Result.StatePresentation.Visible = False;
	EndIf;
	#EndIf
		
EndProcedure	

&AtClient
Procedure ApplyFormDataToSettings()
	Report.SettingsComposer.LoadUserSettings(Report.SettingsComposer.UserSettings);
	
	// if setting isn't loaded we need to push user settings to settings
	For Each FilterItem In Report.SettingsComposer.Settings.Filter.Items Do
		UserSettingValue = Report.SettingsComposer.UserSettings.Items.Find(FilterItem.UserSettingID);
		If UserSettingValue<>Undefined Then
			If  TypeOf(UserSettingValue) = Type("DataCompositionFilterItemGroup") Then
				FillPropertyValues(FilterItem,UserSettingValue,"Use");
			Else 
				FillPropertyValues(FilterItem,UserSettingValue,"Use,ComparisonType, RightValue");
			EndIf;
		EndIf;	
	EndDo;	

	WriteVisualItems();
	
EndProcedure

&AtClient
Procedure SaveReportSettingCommon(Val CopyMode = False, Val AutoApply = False, Val SettingName = "", Val OverwriteRef = Undefined)
	
	If IsBlankString(SettingName) Then
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",SettingName);
	EndIf;	
	
	ApplyFormDataToSettings();
	SaveReportSettingAtServer(CopyMode, AutoApply, SettingName,OverwriteRef);
	If OverwriteRef=Undefined Then
		NotifyChanged(ReportSetting);
	Else
		NotifyChanged(OverwriteRef);
	EndIf;	
	
	IsDetailed = False;
	VariantModified = False;
	UserSettingsModified = False;
	
EndProcedure

&AtClient
Procedure AskForReportName(AdditionalParameters)
	// ask for copy name
	// edit current description
	If AdditionalParameters.Property("BlankSetting") 
		OR IsDetailed Then
		InputString = "";
	Else	
		InputString = ObjectsExtensionsAtServer.GetAttributeFromRef(ReportSetting,"Description");
	EndIf;	
	ShowInputString(New NotifyDescription("AskForReportNameResponse",ThisForm,AdditionalParameters),
					InputString,Nstr("en='Input setting name';pl='Wprowadź nazwę ustawienia';ru='Введите наименование настройки'"),
					150,False);	
EndProcedure

&AtClient
Procedure AskForReportNameResponse(Val InputString, AdditionalParameters) Export
	
	If InputString = Undefined Then
		// cancelling input
		Return;
	EndIf;	
	
	If IsBlankString(InputString) Then
		AskForReportName(AdditionalParameters);
		Return;
	EndIf;	
	
	FoundRef = Undefined;
	If IsSettingNameUnique(SetupObject, InputString,FoundRef) Then
		ExecuteNotifyProcessing(AdditionalParameters.CallBack,New Structure("OverWrite,SettingName,FoundRef",False,InputString,FoundRef));
	Else
		AdditionalParameters.Insert("FoundRef",FoundRef);
		AdditionalParameters.Insert("InputString",InputString);
		ButtonsValueList = New ValueList;
		ButtonsValueList.Add(DialogReturnCode.Retry,Nstr("en='Will input other name';pl='Chcę nadać inną nazwę';ru='Ввести иное наименование'"));
		ButtonsValueList.Add(DialogReturnCode.Yes,Nstr("en='Overwrite existing one';pl='Chcę nadpisać istniejące ustawienie';ru='Перезаписать существующую настройку'"));
		ButtonsValueList.Add(DialogReturnCode.Cancel,Nstr("en='Cancel setting saving';pl='Nie chcę zapisywać ustawienie';ru='Не перезаписывать существующую настройку'"));
		ShowQueryBox(New NotifyDescription("NotUniqueSettingNameQueryChoiceProcessing",ThisForm,AdditionalParameters),
					Nstr("en=""Inputed setting name isn't unique!"";pl='Ustawienie o wprowadzonej nazwie już istnieje!';ru='Настройка с данными наименованием уже существует!'"),
					ButtonsValueList,30,DialogReturnCode.Retry,Nstr("en='Error setting saving';pl='Błąd zapisywania ustawienia';ru='Произошла ошибка при сохранении настройки'"),DialogReturnCode.Cancel);
	EndIf;	
	
EndProcedure	

&AtClient
Procedure NotUniqueSettingNameQueryChoiceProcessing(Val QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Retry Then
		AskForReportName(AdditionalParameters);
	ElsIf QuestionResult = DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(AdditionalParameters.CallBack,New Structure("OverWrite,SettingName,FoundRef",True,AdditionalParameters.InputString,AdditionalParameters.FoundRef));
	EndIf;	
	
EndProcedure	

&AtClient
Procedure SaveChangedVariantQueryChoiceProcessing(Val QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		VariantModified = False;
		UserSettingsModified = False;
		Close(True);
	ElsIf QuestionResult = DialogReturnCode.Yes Then
		SaveReportSettingCommon();
		Close(True);
	EndIf;	
	
EndProcedure	

#EndRegion

#Region OtherAtServer

&AtServerNoContext
Function IsSettingNameUnique(Val SetupObject, Val InputString, FoundRef)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	COUNT(DISTINCT SavedSettings.Ref) AS RefCount,
	             |	MIN(SavedSettings.Ref) AS FoundRef
	             |FROM
	             |	Catalog.SavedSettings AS SavedSettings
	             |WHERE
	             |	SavedSettings.SetupObject = &ObjectKey
	             |	AND SavedSettings.Description = &SettingName
	             |	AND SavedSettings.Owner = &Owner";
	Query.SetParameter("ObjectKey",SetupObject);
	Query.SetParameter("SettingName",InputString);
	Query.SetParameter("Owner",SessionParameters.CurrentUser);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.RefCount <> Null AND Selection.RefCount>0 Then
			FoundRef = Selection.FoundRef;
			Return False;
		Else
			Return True;
		EndIf;	
	Else
		Return True;
	EndIf;	
		
EndFunction	

&AtServer
Procedure LoadReportSettingsByKey(Val Key)
	
	// If CurrentVariantKey is empty, should be returned one of default variants
	// this report wasn't previously used by user
	ReportsModulesAtServer.FillReportWithSettingsByKey(Report.SettingsComposer,ReportMetadataName,CurrentVariantKey);
	AfterLoadSettings();
	
EndProcedure	

&AtServer
Procedure LoadReportSettingsByRef(Val Ref)
	
	// if setting is loaded by ref - it's not detailed
	IsDetailed = False;
	ReportSetting = Ref;
	ReportsModulesAtServer.FillReportWithSettingsByRef(Report.SettingsComposer,ReportMetadataName,ReportSetting);
	AfterLoadSettings();
	
EndProcedure	

&AtServer
Procedure AfterLoadSettings()
	
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingKey",CurrentVariantKey);
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",CurrentVariantPresentation);
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",CurrentVariantDescription);
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingRef",ReportSetting);
	
	// init parameters from user settings here
	If SessionParameters.IsBookkeepingAvailable Then
		// default values getting such as company and financial year
		BookkeepingReportInitializationData = BookkeepingAtServer.GetBookkeepingReportInitializationData();
		For Each KeyAndValue In BookkeepingReportInitializationData Do
			FoundParameter = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,KeyAndValue.Key);
			If FoundParameter <> Undefined AND (NOT FoundParameter.Use OR ValueIsNotFilled(FoundParameter.Value)) Then
				ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings, KeyAndValue.Key, KeyAndValue.Value);
			EndIf;	
		EndDo;	
	EndIf;
	
	If ReportSetting.IsEmpty() AND IsDetailed Then
		
		Items.CopySettings.Visible = False;
		Items.BlankSetting.Visible = False;
		Items.TurnOnAutoSaving.Visible = False;
		Items.TurnOffAutoSaving.Visible =False;
		Items.SaveReportSettings.Visible = True;
			
	Else	
		
		Items.CopySettings.Visible = True;
		Items.BlankSetting.Visible = True;
		// checking if not setting owner or admin - then show Lock button
		SettingOwner = Undefined;
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingOwner",SettingOwner);
		If SettingOwner=SessionParameters.CurrentUser 
			OR IsInRole(Metadata.Roles.Role_SystemSettings) 
			OR IsInRole(Metadata.Roles.Right_Administration_ConfigurationAdministration) Then
			
			// Read save automatically state
			SaveAutomatically = Undefined;
			Report.SettingsComposer.Settings.AdditionalProperties.Property("SaveAutomatically",SaveAutomatically);
			
			// these code should both on client and server so duplicated
			Items.TurnOnAutoSaving.Visible = NOT SaveAutomatically;
			Items.TurnOffAutoSaving.Visible =SaveAutomatically;
			Items.SaveReportSettings.Visible = True;
		Else	
			Items.TurnOnAutoSaving.Visible = False;
			Items.TurnOffAutoSaving.Visible =False;
			Items.SaveReportSettings.Visible = False;
			SaveAutomatically = False;
		EndIf;
		
	EndIf;
		
	SetFormTitle();
	
	VariantModified = False;
	UserSettingsModified = False;
	CreateUserSettingsFormItems();
	
EndProcedure

&AtServer
Function CreateNewReportSetting(Settings,Val SettingKey,Val SettingName)
		
	NewSavedSetting = Catalogs.SavedSettings.CreateItem();
	NewSavedSetting.SettingsKey = SettingKey;
	NewSavedSetting.SetupObject = SetupObject;
	NewSavedSetting.Owner = SessionParameters.CurrentUser;
	NewSavedSetting.SettingType = Enums.SettingsTypes.ReportSettings;
	NewSavedSetting.Description =  SettingName;
	NewSavedSetting.SaveAutomatically = True;
	
	ReportStructure = ReportsModulesAtServer.GetReportStructureForSaving(Settings,ReportAttributes);
	NewSavedSetting.SettingsStorage = New ValueStorage(ReportStructure);
	SetPrivilegedMode(True);
	NewSavedSetting.Write();
	SetPrivilegedMode(False);
	
	Return NewSavedSetting.Ref;
	
EndFunction	

&AtServer
Procedure SaveReportSettingAtServer(Val CopyMode = False, Val AutoApply = False, Val SettingNewName = "",Val OverwriteRef = Undefined)
	
	SavedSetting = Undefined;
	If ValueIsFilled(OverwriteRef) Then
		SavedSetting =  OverwriteRef;
	Else
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingRef",SavedSetting);
	EndIf;	
	
	If ValueIsFilled(SavedSetting) AND NOT CopyMode Then
		ReturnResult = ReportsModulesAtServer.SaveReportByRef(Report.SettingsComposer.Settings,ReportAttributes,SavedSetting,SettingNewName);
		If ReturnResult.IsError Then
			CommonAtClientAtServer.NotifyUser(ReturnResult.ErrorDescription,,,"ReportSetting");
		EndIf;	
		NewSettingRef = SavedSetting;
	ElsIf CopyMode OR IsDetailed OR ValueIsNotFilled(SavedSetting) Then
		NewSettingRef = CreateNewReportSetting(Report.SettingsComposer.Settings, String(New UUID()),SettingNewName);
	EndIf;	
	
	If AutoApply Then
		LoadReportSettingsByRef(NewSettingRef);
		SaveLastUsedSetting(ReportMetadataName,CurrentVariantKey);
	EndIf;	

EndProcedure

&AtServerNoContext
Function GetReportSettingBySettingsKey(Val SetupObject, Val ReportKey)
	
	SetupObject = StrReplace(SetupObject,"Report.","ReportObject.");
	
	Query = New Query;
	Query.SetParameter("ReportKey",ReportKey);
	Query.SetParameter("ExtendedReportKey",GetPredefinedVariantNameForUser(ReportKey));
	Query.SetParameter("SetupObject",SetupObject);
	Query.Text = "SELECT TOP 1
	             |	SavedSettings.Ref
	             |FROM
	             |	Catalog.SavedSettings AS SavedSettings
	             |WHERE
	             |	SavedSettings.SettingsKey IN (&ReportKey, &ExtendedReportKey)
	             |	AND SavedSettings.SetupObject = &SetupObject";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return Catalogs.SavedSettings.EmptyRef();	
	EndIf;	
	
EndFunction	

&AtServer
Procedure CreateVariantsAsSettings(Val ReportVariants)
		
	VariantsNamesArray = New Array;
	For Each ReportVariantsItem In ReportVariants Do
		
		VariantsNamesArray.Add(GetPredefinedVariantNameForUser(ReportVariantsItem.Name));
		
	EndDo;	
	
	Query = New Query;
	Query.SetParameter("Owner",SessionParameters.CurrentUser);
	Query.SetParameter("VariantsNamesArray",VariantsNamesArray);
	Query.SetParameter("SetupObject",SetupObject);
	Query.Text = "SELECT
	             |	SavedSettings.SettingsKey
	             |FROM
	             |	Catalog.SavedSettings AS SavedSettings
	             |WHERE
	             |	SavedSettings.SettingsKey IN(&VariantsNamesArray)
	             |	AND SavedSettings.Owner = &Owner
	             |	AND SavedSettings.SetupObject = &SetupObject";
	
	FoundSettings = New ValueList;
	FoundSettings.LoadValues(Query.Execute().Unload().UnloadColumn("SettingsKey"));
	
	For Each ReportVariantsItem In ReportVariants Do
		
		If FoundSettings.FindByValue(GetPredefinedVariantNameForUser(ReportVariantsItem.Name)) = Undefined Then
			
			CreateNewReportSetting(ReportVariantsItem.Settings, GetPredefinedVariantNameForUser(ReportVariantsItem.Name),ReportVariantsItem.Presentation);
			
		EndIf;	
		
	EndDo;	
		
EndProcedure	


&AtServerNoContext
Procedure SaveLastUsedSetting(Val ReportName,Val SettingKey)
	SystemSettingsStorage.Save(ReportName+"/CurrentVariantKey","",SettingKey,"");	
EndProcedure

&AtServerNoContext
Function GetPredefinedVariantNameForUser(Val VariantName)
	
	Return VariantName+String(SessionParameters.CurrentUser.UUID());
	
EndFunction	

#EndRegion






