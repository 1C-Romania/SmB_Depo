
#Region FormHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ReportObject = FormAttributeToValue("Report");
	ReportMetadata = ReportObject.Metadata();
	ReportMetadataName = "Report."+ReportMetadata.Name;
	ReportSynonym = ReportObject.Metadata().Synonym;
	
	// create list of mandatory data parameters from schema
	TempMandatoryAttributes = New Map;
	For Each SchemaParameter In ReportObject.DataCompositionSchema.Parameters Do
		
		If SchemaParameter.DenyIncompleteValues Then
			TempMandatoryAttributes.Insert(SchemaParameter.Name);
		EndIf;	
		
	EndDo;	
	
	MandatoryAttributes = New FixedMap(TempMandatoryAttributes);

	// get list of bookkeeping parameters
	BookkeepingParametersArray = BookkeepingAtServer.GetBookeepingParametersArray();	
	
	DocumentsFormAtServer.SetVisibleCompanyItem(ThisForm);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.RestoreFormData Then
		ThisForm.Report.SettingsComposer.LoadSettings(FormOwner.Report.SettingsComposer.Settings); 
	EndIf;
	
	If Parameters.BlankSettings Then
		PrepareBlankSetting();
	EndIf;	
	
	InitVisualItems(True);
		
	Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",SettingDescription);
	
	If Parameters.BlankSettings Then
		SettingDescription = Parameters.BlankSettingsName;
	EndIf;	
	
	SetFormTitle();
		
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	For Each MapItem In MandatoryAttributes Do
		CheckedAttributes.Add(MapItem.Key);	
	EndDo;		
EndProcedure

#EndRegion

#Region CommandsHandlers

&AtClient
Procedure CancelEdit(Command)
	
	If Parameters.BlankSettings Then
		
		ThisForm.Report.SettingsComposer.LoadSettings(FormOwner.Report.SettingsComposer.Settings);
		
	EndIf;	
	
	Close(False);
	
EndProcedure

&AtClient
Procedure ApplyChangesAndCreateReport(Command)
	
	WriteVisualItems();

	// skip check filling in report module
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("SkipFillCheck",True);

	If CheckFilling() Then

		ApplyFilterSettings();
		
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("SettingDescription",SettingDescription);
				
		FormOwner.Report.SettingsComposer = Report.SettingsComposer;
		
		Close(True);
		
	EndIf;
	
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
	
EndProcedure

#EndRegion

#Region ReportParametersOnFormHandlers

&AtClient
Procedure AccountOnChange(Item)
	BookkeepingAttributeOnChange("Account");
EndProcedure

#EndRegion

#Region ItemsHandlers

&AtClient
Procedure SettingDescriptionOnChange(Item)
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("SettingPresentation",SettingDescription);
	SetFormTitle();
EndProcedure

#EndRegion

#Region Other

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
Procedure ApplyFilterSettings()
	
	For Each FilterField In Report.SettingsComposer.Settings.Filter.Items Do
		FilterField.UserSettingID = New UUID;
		FilterField.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	EndDo;	
	
EndProcedure

&AtClient
Procedure ApplyPeriodChanges()
	
	DataParameters = Report.SettingsComposer.Settings.DataParameters;
	BeginPeriodParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	EndPeriodParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	PeriodParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	
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
	EndIf;

EndProcedure	

&AtClient
Procedure ReadPeriods()
	
	DataParameters = Report.SettingsComposer.Settings.DataParameters;
	
	BeginPeriodParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	ParameterEndPeriodValue = DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	PeriodParameterValue = DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	
	If BeginPeriodParameterValue <> Undefined 
		AND ParameterEndPeriodValue <> Undefined Then
		BeginOfPeriod = BeginPeriodParameterValue.Value;
		EndOfPeriod = ParameterEndPeriodValue.Value;
		Items.GroupPeriodSettingsTabs.CurrentPage = Items.GroupPeriodSettingsFromToPeriod;
	ElsIf PeriodParameterValue <> Undefined Then
		Period = PeriodParameterValue.Value;
		Items.GroupPeriodSettingsTabs.CurrentPage = Items.GroupPeriodSettingsSinglePeriodTab;
	Else
		Items.GroupPeriodSettingsTabs.CurrentPage = Items.GroupPeriodSettingsNoPeriod;
	EndIf;
	
EndProcedure

&AtClient
Procedure InitVisualItems(Val IsOnOpen = False)
	
	ReadPeriods();
	ReadBookkeepingParameters();
	
		
EndProcedure

&AtClient
Procedure SetFormTitle()
	
	If Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation") Then
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("DetailsSettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + " " + Nstr("en = '(detailed '; pl = '(uszczegółowiony '") + TmpSettingPresentation + ")";
	Else	
		TmpSettingPresentation = "";
		Report.SettingsComposer.Settings.AdditionalProperties.Property("SettingPresentation",TmpSettingPresentation);
		Title = ReportSynonym + ?(IsBlankString(TmpSettingPresentation),""," ("+TmpSettingPresentation+")");
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareBlankSetting()
	
	ReportObject = FormAttributeToValue("Report");
	Report.SettingsComposer.LoadSettings(ReportObject.DataCompositionSchema.SettingVariants.Get(0).Settings);

	Report.SettingsComposer.Settings.ClearItemFilter(Report.SettingsComposer.Settings);
	
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"AppearanceTemplate","DefaultReportPresentationTemplate");
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"ResourcesAutoPosition",DataCompositionResourcesAutoPosition.DontUse);
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"FilterOutput",DataCompositionTextOutputType.DontOutput);
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"DataParametersOutput",DataCompositionTextOutputType.DontOutput);
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"TitleOutput",DataCompositionTextOutputType.DontOutput);
	ReportsModulesAtClientAtServer.SetOutputParameter(Report.SettingsComposer.Settings,"Title","");
	
EndProcedure

&AtClient
Procedure WriteVisualItems()
	
	ApplyPeriodChanges();
	WriteBookkeepingParameters();
	
EndProcedure	

&AtClient
Procedure WriteBookkeepingParameters()
	
	For Each BookkeepingParametersArrayItem In BookkeepingParametersArray Do
		
		If Items.Find(BookkeepingParametersArrayItem) <> Undefined Then
			ReportsModulesAtClientAtServer.SetSettingsParameter(Report.SettingsComposer.Settings,BookkeepingParametersArrayItem,ThisForm[BookkeepingParametersArrayItem]);
		 EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ReadBookkeepingParameters()
		
	For Each BookkeepingParametersArrayItem In BookkeepingParametersArray Do
		
		CurrentParameterValue = ReportsModulesAtClientAtServer.GetSettingsParameter(Report.SettingsComposer.Settings,BookkeepingParametersArrayItem);
		
		If CurrentParameterValue <> Undefined Then
			ThisForm[BookkeepingParametersArrayItem] = CurrentParameterValue.Value;
			BookkeepingAttributeOnChange(BookkeepingParametersArrayItem);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

