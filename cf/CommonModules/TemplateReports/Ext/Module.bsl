// Generates template report in XML String, spreadsheet document or spreadsheet document field	
Function GenerateTemplateReport(ReportObject, Result = Undefined, DetailsData = Undefined, OutputIntoReportForm = True, ExternalDataSets = Undefined) Export
	
	If Result = Undefined Then
		// Output report into XML
		If AnaliticsReport() Then
			SettingsSaving = New Structure;
		Else
			SettingsSaving.FillSettingsOnReportOpening(ReportObject);
		EndIf;
		ReportObject.CompleteComposerBeforeOutput();
		// Generate data composition template by template composer
		TemplateComposer = New DataCompositionTemplateComposer;
		CompositionTemplate = TemplateComposer.Execute(ReportObject.DataCompositionSchema, ReportObject.SettingsComposer.Settings);
		// Create and initialize composition processor 
		CompositionProcessor = New DataCompositionProcessor;
		If ExternalDataSets = Undefined Then
			CompositionProcessor.Initialize(CompositionTemplate,,DetailsData);
		Else
			CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
		EndIf;
		XMLWriter = New XMLWriter();
		XMLWriter.SetString();
		XMLWriter.WriteStartElement("result");
		While True Do
			ResultItem = CompositionProcessor.Next();
			If ResultItem = Undefined Then
				Break;
			EndIf;
			XDTOSerializer.WriteXML(XMLWriter, ResultItem, "item", "http://v8.1c.ru/8.1/data-composition-system/result");
		EndDo;
		XMLWriter.WriteEndElement();
		Return XMLWriter.Close();
		
	ElsIf OutputIntoReportForm Then
		// Output report in report form
		
		Result.Clear();
		Settings = ReportObject.SettingsComposer.GetSettings();
		TemplateReportHeaderOutput(ReportObject, Result, OutputIntoReportForm);
		CompleteTemplateReportBeforeOutput(ReportObject);
		ReportObject.CompleteComposerBeforeOutput();
		OutputTemplateReport(ReportObject, Result, DetailsData, OutputIntoReportForm, ExternalDataSets);
		ReportObject.FinalizeComposerAfterOutput();
		ReportObject.SettingsComposer.LoadSettings(Settings);
		TemplateReportHeaderPresentationManaging(ReportObject, Result);
	Else
		// Output report in spreadsheet document
		Settings = ReportObject.SettingsComposer.GetSettings();
		TemplateReportHeaderOutput(ReportObject, Result, OutputIntoReportForm);
		CompleteTemplateReportBeforeOutput(ReportObject);
		ReportObject.CompleteComposerBeforeOutput();
		OutputTemplateReport(ReportObject, Result, DetailsData, OutputIntoReportForm, ExternalDataSets);
		ReportObject.SettingsComposer.LoadSettings(Settings);

	EndIf;
	
EndFunction

Function AnaliticsReport() Export
	
	Return False;

EndFunction

Function CreateBoundaryFromValue(Value) Export
	
	Return New Boundary(Value);
	
EndFunction	

#If Client Then
	
Function AddParents(DetailsItem, CurrentReport, FieldsDetailsArray, IncludeResources = False) Export
	
	If TypeOf(DetailsItem) = Type("DataCompositionFieldDetailsItem") Then
		For each Field In DetailsItem.GetFields() Do
			AvailableField = GetAvailableFieldOnDataCompositionField(New DataCompositionField(Field.Field), CurrentReport);
			If AvailableField = Undefined Then
				Continue;
			EndIf;
			If Not IncludeResources AND AvailableField.Resource Then
				Continue;
			EndIf;
			FieldsDetailsArray.Add(Field);
		EndDo;
	EndIf;
	For each Parent In DetailsItem.GetParents() Do
		AddParents(Parent, CurrentReport, FieldsDetailsArray, IncludeResources);
	EndDo;
	
EndFunction

// Returns array for reports drilldown
Function GetDetailsFieldsArray(Details, DetailsData, CurrentReport = Undefined, IncludeResources = False) Export
	
	FieldsDetailsArray = New Array;
	
	If TypeOf(Details) <> Type("DataCompositionDetailsID") 
		AND TypeOf(Details) <> Type("DataCompositionDetailsData") Then
		Return FieldsDetailsArray;
	EndIf;
	
	If CurrentReport = Undefined Then
		CurrentReport = DetailsData;
	EndIf;
	
	// Add parent groups fields 
	AddParents(DetailsData.Items[Details], CurrentReport, FieldsDetailsArray, IncludeResources);
		
	Count = FieldsDetailsArray.Count();
	For Indexof = 1 To Count Do
		BackIndex = Count - Indexof;
		For InexInside = 0 To BackIndex - 1 Do
			If FieldsDetailsArray[BackIndex].Field = FieldsDetailsArray[InexInside].Field Then
				FieldsDetailsArray.Delete(BackIndex);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	// Add filter, which was setup in report
	For each FilterItem In CurrentReport.Settings.Filter.Items Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		FieldsDetailsArray.Add(FilterItem);
	EndDo;
	
			
	Return FieldsDetailsArray;
	
EndFunction

#EndIf

// Copy items from one collection into another
Procedure CopyItems(ReceiverValue, SourceValue, CheckAvailability = False, ClearReceiver = True) Export
	
	If TypeOf(SourceValue) = Type("DataCompositionConditionalAppearance")
	 OR TypeOf(SourceValue) = Type("DataCompositionUserFieldsCaseVariants")
	 OR TypeOf(SourceValue) = Type("DataCompositionAppearanceFields") Then
		CreateByType = False;
	Else
		CreateByType = True;
 	EndIf;
	ItemsReceiver = ReceiverValue.Items;
	ItemsSource = SourceValue.Items;
	If ClearReceiver Then
		ItemsReceiver.Clear();
	EndIf;
	
	For each ItemSource In ItemsSource Do
		
		If CreateByType Then
			ItemReceiver = ItemsReceiver.Add(TypeOf(ItemSource));
		Else
			ItemReceiver = ItemsReceiver.Add();
		EndIf;
		
		FillPropertyValues(ItemReceiver, ItemSource);
		
		// In some collection should be filled other collections
		If TypeOf(ItemsSource) = Type("DataCompositionConditionalAppearanceItemCollection") Then
			CopyItems(ItemReceiver.Fields, ItemSource.Fields);
			CopyItems(ItemReceiver.Filter, ItemSource.Filter);
			FillItems(ItemReceiver.Appearance, ItemSource.Appearance); 
		ElsIf TypeOf(ItemsSource)	= Type("DataCompositionUserFieldCaseVariantCollection") Then
			CopyItems(ItemReceiver.Filter, ItemSource.Filter);
		EndIf;
		
		// In some collection items should be filled other collections
		If TypeOf(ItemSource) = Type("DataCompositionFilterItemGroup") Then
			CopyItems(ItemReceiver, ItemSource);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionSelectedFieldGroup") Then
			CopyItems(ItemReceiver, ItemSource);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionUserFieldCase") Then
			CopyItems(ItemReceiver.Variants, ItemSource.Variants);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionUserFieldExpression") Then
			ItemReceiver.SetDetailRecordExpression (ItemSource.GetDetailRecordExpression());
			ItemReceiver.SetTotalRecordExpression(ItemSource.GetTotalRecordExpression());
			ItemReceiver.SetDetailRecordExpressionPresentation(ItemSource.GetDetailRecordExpressionPresentation ());
			ItemReceiver.SetTotalRecordExpressionPresentation(ItemSource.GetTotalRecordExpressionPresentation ());
		EndIf;
		
	EndDo;
	
EndProcedure

// Filled one items collection based on another collection
Procedure FillItems(ReceiverValue, SourceValue, FirstLevel = Undefined, FillUnused = True) Export
	
	If TypeOf(ReceiverValue) = Type("DataCompositionParameterValueCollection") Then
		ValuesCollection = SourceValue;
	Else
		ValuesCollection = SourceValue.Items;
	EndIf;
	
	For each ItemSource In ValuesCollection Do
		If FirstLevel = Undefined Then
			ItemReceiver = ReceiverValue.FindParameterValue(ItemSource.Parameter);
		Else
			ItemReceiver = FirstLevel.FindParameterValue(ItemSource.Parameter);
		EndIf;
		If ItemReceiver = Undefined Then
			Continue;
		EndIf;
		If Not FillUnused AND Not ItemSource.Use Then
		Else
			FillPropertyValues(ItemReceiver, ItemSource);
		EndIf;
		If TypeOf(ItemSource) = Type("DataCompositionParameterValue") Then
			FillItems(ItemReceiver.NestedParameterValues, ItemSource.NestedParameterValues, ReceiverValue);
		EndIf;
	EndDo;
	
EndProcedure

// Returns groups array of settings composer
Function GetGroupsArray(StructureItem, SettingsComposer, GroupsArray = Undefined)
	
	If GroupsArray = Undefined Then
		GroupsArray = New Array;
	EndIf;
	
	For each GroupField In StructureItem.GroupFields.Items Do
		If Not GroupField.Use OR TypeOf(GroupField) = Type("DataCompositionAutoGroupField") Then
			Continue;
		EndIf;
		AvailableField = GetAvailableField(GroupField.Field, SettingsComposer.Settings.GroupAvailableFields);
		If AvailableField = Undefined Then
			Continue;
		EndIf;
		GroupsArray.Add(AvailableField.Title);
	EndDo;
	
	If StructureItem.Structure.Count() = 0 Then
		Return GroupsArray;
	Else
		Return GetGroupsArray(StructureItem.Structure[0], SettingsComposer, GroupsArray);
	EndIf;
	
EndFunction

#If Client Then
// Copy data composition settings from one composer to another
Procedure CopyDataCompositionSettings(SettingsReceiver, SettingsSource) Export
	
	If SettingsSource = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(SettingsReceiver) = Type("DataCompositionSettings") Then
		For each Parameter In SettingsSource.DataParameters.Items Do
		   ParameterValue = SettingsReceiver.DataParameters.FindParameterValue(Parameter.Parameter);
		   If ParameterValue <> Undefined Then
			   FillPropertyValues(ParameterValue, Parameter);
		   EndIf;
		EndDo;
	EndIf;
	
	If TypeOf(SettingsSource) = Type("DataCompositionNestedObjectSettings") Then
		FillPropertyValues(SettingsReceiver, SettingsSource);
		CopyDataCompositionSettings(SettingsReceiver.Settings, SettingsSource.Settings);
		Return;
	EndIf;
	
	// Copy settings
	If TypeOf(SettingsSource) = Type("DataCompositionSettings") Then
		
		FillItems(SettingsReceiver.DataParameters, SettingsSource.DataParameters);
		CopyItems(SettingsReceiver.UserFields, SettingsSource.UserFields);
		CopyItems(SettingsReceiver.Filter,         SettingsSource.Filter);
		CopyItems(SettingsReceiver.Order,       SettingsSource.Order);
		
	EndIf;
	
	If TypeOf(SettingsSource) = Type("DataCompositionGroup")
		OR TypeOf(SettingsSource) = Type("DataCompositionTableGroup")
		OR TypeOf(SettingsSource) = Type("DataCompositionChartGroup") Then
		
		CopyItems(SettingsReceiver.GroupFields, SettingsSource.GroupFields);
		CopyItems(SettingsReceiver.Filter,           SettingsSource.Filter);
		CopyItems(SettingsReceiver.Order,         SettingsSource.Order);
		FillPropertyValues(SettingsReceiver, SettingsSource);
		
	EndIf;
	
	CopyItems(SettingsReceiver.Selection,              SettingsSource.Selection);
	CopyItems(SettingsReceiver.ConditionalAppearance, SettingsSource.ConditionalAppearance);
	FillItems(SettingsReceiver.OutputParameters,      SettingsSource.OutputParameters);
	
	// Copy structure
	If TypeOf(SettingsSource) = Type("DataCompositionSettings")
	 OR TypeOf(SettingsSource) = Type("DataCompositionGroup") Then
	 	
		For each StructureItemSource In SettingsSource.Structure Do
			StructureItemReceiver = SettingsReceiver.Structure.Add(TypeOf(StructureItemSource));
			CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
	EndIf;
	
	If TypeOf(SettingsSource) = Type("DataCompositionTableGroup")
	 OR TypeOf(SettingsSource) = Type("DataCompositionChartGroup") Then
	 	
		For each StructureItemSource In SettingsSource.Structure Do
			StructureItemReceiver = SettingsReceiver.Structure.Add();
			CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
	EndIf;
	
	If TypeOf(SettingsSource) = Type("DataCompositionTable") Then
		
		For each StructureItemSource In SettingsSource.Rows Do
			StructureItemReceiver = SettingsReceiver.Rows.Add();
		    CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
		For each StructureItemSource In SettingsSource.Columns Do
			StructureItemReceiver = SettingsReceiver.Columns.Add();
		    CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
	EndIf;
	
	If TypeOf(SettingsSource) = Type("DataCompositionChart") Then
		
		For each StructureItemSource In SettingsSource.Series Do
			StructureItemReceiver = SettingsReceiver.Series.Add();
		    CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
		For each StructureItemSource In SettingsSource.Points Do
			StructureItemReceiver = SettingsReceiver.Points.Add();
		    CopyDataCompositionSettings(StructureItemReceiver, StructureItemSource);
		EndDo;
		
	EndIf;
	
EndProcedure

// Replace colors in chart
Procedure ReplaceColorsInChart(Chart, SeriesColorTable) Export
	
	Series = Chart.Series;
	
	For each Series In Series Do
		
		SearchStructure = New Structure("Text", Series.Text);
		SeriesColorsArray = SeriesColorTable.FindRows(SearchStructure);
		
		If SeriesColorsArray.Count() > 0 Then
			Series.Color = SeriesColorsArray[0].Color;
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns report's item presentation picture
Function GetReportItemPresentationPicture(ReportItemPresentation) Export
	
	If ReportItemPresentation = Enums.ReportItemsPresentation.Table Then
		Return  PictureLib.Table;
	ElsIf ReportItemPresentation = Enums.ReportItemsPresentation.CrossTable Then
		Return  PictureLib.CrossTable;
	ElsIf ReportItemPresentation = Enums.ReportItemsPresentation.Chart Then
		Return PictureLib.Chart;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Delete unavaliable filter items from composer
Procedure DeleteUnavaliableFieldsFromFilter(SettingsComposer) Export
	
	Count = SettingsComposer.Settings.Filter.Items.Count();
	For Indexof = 1 To Count Do
		FilterItem = SettingsComposer.Settings.Filter.Items[Count - Indexof];
		FilterField = FilterItem.LeftValue;
		If SettingsComposer.Settings.Filter.FilterAvailableFields.FindField(FilterField) = Undefined Then
			SettingsComposer.Settings.Filter.Items.Delete(FilterItem);
		EndIf;
	EndDo;
	
EndProcedure

// Delete unavaliable filter items from content rows
Procedure DeleteUnavaliableFiltersFromContentRows(Content, SettingsComposer) Export
	
	For each ContentRow In Content Do
		FilterMap = ContentRow.Get();
		NewMap = New Map;
		For each FilterItemMap In FilterMap Do
			Field = New DataCompositionField(FilterItemMap.Key);
			If SettingsComposer.Settings.Filter.FilterAvailableFields.FindField(Field) <> Undefined Then
				NewMap.Insert(FilterItemMap.Key, FilterItemMap.Value);
			EndIf;
		EndDo;
		ContentRow.Filter = New ValueStorage(FilterMap);
	EndDo;
		
EndProcedure

// Returns setting composer by composition schema and composer settings
Function GetComposerBySchemaAndSettings(Schema, Settings = Undefined) Export
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(Schema));
	If Settings <> Undefined Then
		SettingsComposer.LoadSettings(Settings);
	EndIf;
	Return SettingsComposer;
	
EndFunction

// Adds into group order auto item
Procedure AddOrderAutoItem(Row) Export
	
	FieldOrderField = Row.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
EndProcedure


// Returns structure item type by presentation
Function GetItemTypeByPresentation(Presentation) Export
	
	If Presentation = Enums.ReportItemsPresentation.Table Then
		Return Type("DataCompositionGroup")
	ElsIf Presentation = Enums.ReportItemsPresentation.CrossTable Then
		Return Type("DataCompositionTable")
	ElsIf Presentation = Enums.ReportItemsPresentation.Chart Then
		Return Type("DataCompositionChart")
	EndIf;
	
EndFunction

//Procedure assign to form an unique ID for giving possibility open a few same forms
Procedure AssignToFormUniqueID(Form) Export
	
	If Form.UniqueKey = Undefined Then
		Form.UniqueKey = New UUID();
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// OVERALL REPORTS PROCEDURES

// Opens settings form for template reports
Function EditTemplateReportSettings(ReportObject, ReportForm, FormParameters = Undefined,ModeSwitch = False) Export
	
	If ReportObject.ExtendedSetting Then
		
		// Save settings in case if they will be changed, we should have a copy
		SavedSettings = ReportObject.SettingsComposer.GetSettings();
		
		SettingsForm = GetCommonForm("SettingsComposerSettingForm");
		SettingsForm.ReportObject = ReportObject;
		SettingsForm.SettingsComposer = ReportObject.SettingsComposer;
		
		SettingsForm.MainSetting = True;
		SettingsForm.GenerateOnOpening = True;
		
		If SettingsForm.DoModal() = True Then
			If Not AnaliticsReport() Then 
				If ReportObject.SavedSetting <> Undefined 
					AND ReportObject.SavedSetting.SaveAutomatically Then
					ReportForm.SaveSettings();
				EndIf;
				UpdateTemplateReportFormOnComposer(ReportObject, ReportForm);
				If SettingsForm.ReturnToNormalMode Then
					ReportObject.ExtendedSetting = False;
					Return OpenStandartReportSettings(ReportObject, ReportForm, FormParameters );
				EndIf;	
			EndIf;
			// Report will not be generated
			Return False;
		Else
			
			// Switiching from standart settings to extended
			If ModeSwitch Then
				ReportObject.ExtendedSetting = False;
			EndIf;	
			// We should cancel settings editing - restore previosly saved settings
			ReportObject.SettingsComposer.LoadSettings(SavedSettings);
			
		EndIf;
		
	Else
		Return OpenStandartReportSettings(ReportObject, ReportForm, FormParameters );
	EndIf;
	
	Return False;
	
EndFunction

Function OpenStandartReportSettings(ReportObject, ReportForm, FormParameters = Undefined)
	
	SettingsForm = GetCommonForm("TemplateReportSettingsForm", ReportForm);
	SettingsForm.ReportObject = ReportObject;
	SettingsForm.NegativeInRed = ReportObject.NegativeInRed;
	SettingsForm.ShowZerosAfterCommaForQuantities = ReportObject.ShowZerosAfterCommaForQuantities;
	SettingsForm.PeriodSettings = ReportObject.PeriodSettings;
	SettingsForm.FormParameters = FormParameters;
	If NOT SettingsForm.IsOpen() Then
		OpeningResult = SettingsForm.DoModal();
	Else
		OpeningResult = True;
	EndIf;	
	If OpeningResult <> Undefined Then 
		If Not AnaliticsReport() Then
			If ReportObject.SavedSetting <> Undefined
				AND ReportObject.SavedSetting.SaveAutomatically Then
				ReportForm.SaveSettings();
			EndIf;
			UpdateTemplateReportFormOnComposer(ReportObject, ReportForm);
			TemplateReportHeaderPresentationManaging(ReportObject, ReportForm.Controls.Result);
		EndIf;
		
		Return OpeningResult;
		
	EndIf;

	Return False
	
EndFunction	

// Hide or show quick filter on form
Procedure TemplateReportFormControlsPresentationManging(ReportObject, ReportForm) Export
	
	ReportForm.Controls.FormActions.Buttons.Filter.Check = ReportObject.ShowQuickFilter;
	If Not AnaliticsReport() Then
		If ReportForm.Controls.FormActions.Buttons.Header.Check Then
			Value = DataCompositionTextOutputType.Output;
		Else
			Value = DataCompositionTextOutputType.DontOutput;
		EndIf;
	
		ReportObject.SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput")).Value = Value;
	EndIf;
	
	If ReportObject.ShowQuickFilter Then
		// show filter
		ReportForm.Controls.Splitter.Collapse = ControlCollapseMode.None;
		ReportForm.Controls.FilterPanel.Collapse = ControlCollapseMode.None;
		ReportForm.Controls.Splitter.SetLink(ControlEdge.Top, ReportForm.Panel, ControlEdge.Top, ReportForm.Panel, ControlEdge.Bottom);
		ReportForm.Controls.FilterPanel.SetLink(ControlEdge.Bottom, ReportForm.Controls.Splitter, ControlEdge.Top);
		
	Else
		// hide filter
		ReportForm.Controls.FilterPanel.SetLink(ControlEdge.Bottom);
		ReportForm.Controls.Splitter.SetLink(ControlEdge.Top, ReportForm.Controls.FilterPanel, ControlEdge.Bottom);
		ReportForm.Controls.FilterPanel.Collapse = ControlCollapseMode.Top;
		ReportForm.Controls.Splitter.Collapse = ControlCollapseMode.Top;
	EndIf;
	
EndProcedure

// Opens report copy in new window
Procedure OpenTemplateReportInNewWindow(ReportObject, ReportForm) Export
	
	If String(ReportObject) = "ExternalReportObject." + ReportObject.Metadata().Name Then
		Message(Nstr("en='This report is external.';pl='Ten raport jest zewnętrzny.'") + Chars.LF + Nstr("en='Opening of a new report is possible only for configuration objects.';pl='Otwieranie nowego raportu możliwe jedynie dla obiektów konfiguracji.'"));
		Return;
	Else
		NewReport = Reports[ReportObject.Metadata().Name].Create();
	EndIf;
	
	FillPropertyValues(NewReport, ReportObject,, "SavedSetting");
	NewReport.SettingsComposer.LoadSettings(ReportObject.SettingsComposer.GetSettings());
	NewReportsForm = NewReport.GetForm();
	NewReportsForm.IsDetailProcessing = True;
	NewReportsForm.Open();
	NewReport.GenerateReport(NewReportsForm.Controls.Result, NewReportsForm.DetailsData);
	
EndProcedure

#EndIf

// Hide or show header of template report
Procedure TemplateReportHeaderPresentationManaging(ReportObject, Result) Export
	
	If Result.TableHeight = 0 Then
		Return;
	EndIf;
	
	TitleArea = Result.Areas.Find("Header");
	If TitleArea = Undefined Then
		// no header found
		Return;
	EndIf;	
	
	ShowHeader = (ReportObject.SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput")).Value = DataCompositionTextOutputType.Output);
	TitleArea.Visible = ShowHeader;
	
EndProcedure


// Adds into group autoselected field
Function AddAutoSelectedField(Structure) Export
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	Return SelectedField;
	
EndFunction

// Output header  for template report in spreadsheet document
Procedure TemplateReportHeaderOutput(ReportObject, Result, Val OutputIntoReportForm = True) Export
	
	OrdinaryFormCompatibilityMode = NOT ReportObject.SettingsComposer.Settings.AdditionalProperties.Property("NotOrdinaryRunMode");
	// need to be cleared up
	ReportObject.SettingsComposer.Settings.AdditionalProperties.Delete("NotOrdinaryRunMode");	
	
	ParameterValue = ReportObject.SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	OutputHeader = (ParameterValue.Value = DataCompositionTextOutputType.Output AND ParameterValue.Use);
	
	If Not OutputIntoReportForm AND Not OutputHeader Then
		Return;
	EndIf;
	TemplateReportHeaderName = "TemplateReportHeader";
	WasOwnHeader = False;
	If ReportObject.Metadata().Templates.Find(TemplateReportHeaderName) = Undefined Then
		HeaderTemplate = GetCommonTemplate(TemplateReportHeaderName);
	Else
		HeaderTemplate = ReportObject.GetTemplate(TemplateReportHeaderName);
		WasOwnHeader = True;
	EndIf;	
	TitleArea = HeaderTemplate.GetArea("Header");
	ParameterValue = ReportObject.SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OrdinaryFormCompatibilityMode 
		OR ParameterValue = Undefined 
		OR NOT ParameterValue.Use
		OR IsBlankString(ParameterValue.Value) Then
		ReportHeader = ReportObject.Metadata().Synonym; 
	Else	
		ReportHeader = ParameterValue.Value;
	EndIf;	
	TitleArea.Parameters.ReportHeader = ReportHeader;
	If OrdinaryFormCompatibilityMode Then
		TitleArea.Parameters.ReportSettingsDescription = GetReportSettingsDescription(ReportObject.SettingsComposer);
	EndIf;
	
	If WasOwnHeader Then
		
		ReportObject.FillOwnHeader(TitleArea);
		
	EndIf;	
	
	Result.Put(TitleArea);
	
EndProcedure

// Returns presentation by structure item type
Function GetPresentationByStructureItem(StructureItem) Export
	
	If TypeOf(StructureItem) = Type("DataCompositionGroup") Then
		Return Enums.ReportItemsPresentation.Table;
	ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
		Return Enums.ReportItemsPresentation.CrossTable;
	ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
		Return Enums.ReportItemsPresentation.Chart;
	EndIf;
	
EndFunction

Function GetReportPeriodDescription(SettingsComposer,LanguageCode = "") Export
	
	If SettingsComposer.Settings.Structure.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	// Period
	PeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If PeriodParameterValue = Undefined Then
		PeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("ReportPeriod"));		
	EndIf;	
	BeginPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	If BeginPeriodParameterValue = Undefined Then
		BeginPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("ReportBeginOfPeriod"));		
	EndIf;		
	EndPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If EndPeriodParameterValue = Undefined Then
		EndPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("ReportEndOfPeriod"));		
	EndIf;		
	If BeginPeriodParameterValue <> Undefined 
	   AND EndPeriodParameterValue <> Undefined Then
		BeginPeriod = BeginPeriodParameterValue.Value;
		If TypeOf(BeginPeriod) = Type("StandardBeginningDate") Then
			BeginPeriod = BeginPeriod.Date;
		EndIf;	
		EndPeriod = EndPeriodParameterValue.Value;
		If TypeOf(EndPeriod) = Type("StandardBeginningDate") Then
			EndPeriod = EndPeriod.Date;
		EndIf;	
		If BeginPeriod = '00010101' AND EndPeriod = '00010101' Then
			PeriodDescription = NStr("en='Period does not set';pl='Okres nie jest określony';ru='Период не указан'");
		ElsIf BeginPeriod = '00010101' OR EndPeriod = '00010101' Then
			PeriodDescription = Format(BeginPeriod, "DLF = D; DE = ...") + " - " + Format(EndPeriod, "DLF = D; DE = ...");
		ElsIf BegOfDay(BeginPeriod) = BegOfMonth(BeginPeriod) AND EndOfDay(EndPeriod) = EndOfMonth(EndPeriod) Then
			PeriodDescription = PeriodPresentation(BegOfDay(BeginPeriod), EndOfDay(EndPeriod), "FP = True"+?(NOT IsBlankString(LanguageCode),"; L ="+LanguageCode,""));
		ElsIf BeginPeriod <= EndPeriod Then
			PeriodDescription = Format(BegOfDay(BeginPeriod), "DLF = D; DE = ...") + " - " + Format(EndOfDay(EndPeriod), "DLF = D; DE = ...");
		Else
			PeriodDescription = NStr("en='Wrong period!';pl='Niepoprawny okres!';ru='Недопустимый период!'");
		EndIf;
	ElsIf PeriodParameterValue <> Undefined Then
		Period = PeriodParameterValue.Value;
		If Period = '00010101' Then
			PeriodDescription = NStr("en='on ';pl='na '") + Format(CurrentDate(), "DLF = D; DE = ...");
		Else
			PeriodDescription = NStr("en='on end of day ';pl='na koniec dnia '") + Format(Period, "DLF = D; DE = ...");
		EndIf;
	Else
		PeriodDescription = "";
	EndIf;
	
	Return PeriodDescription;
	
EndFunction	

Function GetReportSettingsDescription(SettingsComposer)
		
	If SettingsComposer.Settings.Structure.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	PeriodDescription = GetReportPeriodDescription(SettingsComposer);
	
	If Not IsBlankString(PeriodDescription) Then
		PeriodDescription = Nstr("en='Period';pl='Okres'")+": " + PeriodDescription + Chars.LF;
	EndIf;
	
	PartsCounter = 1;
	PartsDescription = "";
	For Each ReportItem In SettingsComposer.Settings.Structure Do
		
	//	ReportItem = SettingsComposer.Settings.Structure[0];
		ReportItemPresentation = GetPresentationByStructureItem(ReportItem);
		If ReportItemPresentation = Enums.ReportItemsPresentation.Table Then
			Rows = GetGroupsArray(ReportItem, SettingsComposer);
			RowsType = Nstr("en='Rows groups';pl='Grupy wierszy'");
		ElsIf ReportItemPresentation = Enums.ReportItemsPresentation.CrossTable Then
			If ReportItem.Rows.Count() > 0 Then
				Rows = GetGroupsArray(ReportItem.Rows[0], SettingsComposer);
			Else
				Rows = New Array;
			EndIf;
			RowsType = Nstr("en='Rows groups';pl='Grupy wierszy'");
			If ReportItem.Columns.Count() > 0 Then
				Columns = GetGroupsArray(ReportItem.Columns[0], SettingsComposer); 
			Else
				Columns = New Array;
			EndIf;
			ColumnsType = Nstr("en='Columns groups';pl='Grupy kolumn'");
		ElsIf ReportItemPresentation = Enums.ReportItemsPresentation.Chart Then
			If ReportItem.Series.Count() > 0 Then
				Rows = GetGroupsArray(ReportItem.Series[0], SettingsComposer);
			Else
				Rows = New Array;
			EndIf;
			RowsType = Nstr("en='Series groups';pl='Grupy serii'");
			If ReportItem.Points.Count() > 0 Then
				Columns = GetGroupsArray(ReportItem.Points[0], SettingsComposer); 
			Else
				Columns = New Array;
			EndIf;
			ColumnsType = Nstr("en='Points groups';pl='Grupy punktów'");
		EndIf;
		
		Data = GetDataItems(SettingsComposer);
		AdditionalFields = GetAdditionalFields(SettingsComposer);
		
		FilterRow = String(SettingsComposer.Settings.Filter);
		PartsDescription = ?(SettingsComposer.Settings.Structure.Count()>1,PartsDescription + Nstr("en='Part';pl='Część'") + " " + PartsCounter + ":" + Chars.CR,"") +
		GenerateFieldsRow(RowsType, Rows) + 
		GenerateFieldsRow(ColumnsType, Columns) + 
		GenerateFieldsRow(Nstr("en='Additional fields';pl='Dodatkowe pola';ru='Дополнительные поля'"), AdditionalFields) +
		GenerateFieldsRow(Nstr("en='Data';pl='Dane'"), Data) +
		?(IsBlankString(FilterRow) , "", Nstr("en='Filter';pl='Filtr';ru='Отбор'")+": " + FilterRow) + Chars.CR;
		PartsCounter = PartsCounter + 1;
		
	EndDo;
	ReportSettingsDescription = PeriodDescription + PartsDescription;
	Return ReportSettingsDescription;		
	
EndFunction

// Output template report into spreadsheet document
Procedure OutputTemplateReport(ReportObject, Result, DetailsData, OutputIntoReportForm = True, ExternalDataSets = Undefined) Export
	
	ReportObject.SettingsComposer.Refresh();
	Schema = ReportObject.DataCompositionSchema;
	
	//Generate data composition template using template composer
	TemplateComposer = New DataCompositionTemplateComposer;	
	
	ResetedBalanceFields = ResetBalanceFields(Schema,ReportObject.SettingsComposer.Settings);

	//As composition schema will be used reports own data composition schema
	//As reports settings = current reports settings
	//Data details will be stored in DetailsData

	If OutputIntoReportForm Then
		CompositionTemplate = TemplateComposer.Execute(Schema, ReportObject.SettingsComposer.Settings, DetailsData);
		ReportObject.UpdateDataCompositionTemplateBeforeOutput(CompositionTemplate);
		CompleteTemplatesCompositionTemplateResourcesDetails(CompositionTemplate, ReportObject.SettingsComposer);
		// Create and initalize composition processor
		CompositionProcessor = New DataCompositionProcessor;
		If ExternalDataSets = Undefined Then
			CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);
		Else
			CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
		EndIf;
	Else
		CompositionTemplate = TemplateComposer.Execute(Schema, ReportObject.SettingsComposer.Settings);
		// Create and initalize composition processor
		CompositionProcessor = New DataCompositionProcessor;
		If ExternalDataSets = Undefined Then
			CompositionProcessor.Initialize(CompositionTemplate, , , True);
		Else
			CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, , True);
		EndIf;
	EndIf;
	
	RestoreResetedFields(ResetedBalanceFields,ReportObject.SettingsComposer.Settings);
	
	// Create and initalize result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(Result);
	
	//Mark start output
	OutputProcessor.BeginOutput();
	#If Client Then
	Status(NSTR("en='If you want to break report output, please press Ctrl+Break';pl='Jeżeli chcesz przerwać wydruk raportu, przyciśnij Ctrl+Break'"));
	#EndIf
	TableFixed = Not OutputIntoReportForm;
	
	If CommonAtServer.IsDocumentAttribute("ExtendedSetting",ReportObject.Metadata()) Then
		ReportObjectExtendedSetting = ReportObject.ExtendedSetting;
	Else
		ReportObjectExtendedSetting = True;
	EndIf;	
	
	Result.FixedTop = 0;
	//Main loop report output
	While True Do
		
		#If Client Then
		UserInterruptProcessing();
		#EndIf
		//Get next item composition result
		ResultItem = CompositionProcessor.Next();
		
		If ResultItem = Undefined Then
			//Next item not found - end loop
			Break;
			
		Else
			
			// Fix header
			If Not ReportObjectExtendedSetting 
				AND Not TableFixed 
				AND ResultItem.ParameterValues.Count() > 0 
				AND TypeOf(ReportObject.SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then
				TableFixed = True;
				Result.FixedTop = Result.TableHeight;
			EndIf;
			
			//Item found - output using output processor
			OutputProcessor.OutputItem(ResultItem);
			
		EndIf;
		
	EndDo;	
	
	//Mark end output
	OutputProcessor.EndOutput();
	
EndProcedure

Function GetAvailableField(Val Field, SearchArea) Export
	
	Return SearchArea.FindField(Field);
	
EndFunction

Function GetDataItems(SettingsComposer)
	
	Items = New Array;
	SelectedFields = GetSelectedFields(SettingsComposer);
	
	For each SelectedField In SelectedFields Do
		
		If SelectedField.Use Then
			AvailableField = GetAvailableField(SelectedField.Field, SettingsComposer.Settings.Selection.SelectionAvailableFields);
			If AvailableField <> Undefined AND AvailableField.Resource Then
				Items.Add(AvailableField.Title);
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Items;
	
EndFunction

Function GetAdditionalFields(SettingsComposer)
	
	Items = New Array;
	SelectedFields = GetSelectedFields(SettingsComposer);
	
	For each SelectedField In SelectedFields Do
		AvailableField = GetAvailableField(SelectedField.Field, SettingsComposer.Settings.Selection.SelectionAvailableFields);
		If AvailableField<>Undefined AND Not AvailableField.Resource Then
			Items.Add(AvailableField.Title);
		EndIf;
	EndDo;
	
	Return Items;
	
EndFunction

Function GenerateFieldsRow(FieldsType, FieldsArray)
	
	If FieldsArray = Undefined OR FieldsArray.Count() = 0 Then
		Return "";
	EndIf;
	
	FieldsString = FieldsType + ": ";
	For each Field In FieldsArray Do
		FieldsString = FieldsString + Field + "; ";
	EndDo;
	
	FieldsString = Left(FieldsString, StrLen(FieldsString) - 2) + "." + Chars.LF;
	
	Return FieldsString;
	
EndFunction

Function ResetBalanceFields(DataCompositionSchema,DataCompositionSettings)
	
	ListOfSelectedItems = GetSelectedFields(DataCompositionSettings.Selection);
	
	FilterGroup = Undefined;
	
	For Each Item In ListOfSelectedItems Do
		
		FoundField = DataCompositionSettings.FilterAvailableFields.FindField(Item.Field);
		
		If GetFieldUse(Item,True) 
			AND FoundField <> Undefined AND FoundField.Resource Then
			If FilterGroup = Undefined Then
				FilterGroup = DataCompositionSettings.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.GroupType = DataCompositionFilterItemsGroupType.NotGroup;
				FilterGroup.Use = True;
			EndIf;	
			
			AddFilter(FilterGroup,Item.Field,0);	
			
		EndIf;	
		
	EndDo;	
	
	Return FilterGroup;
	
EndFunction	

Procedure RestoreResetedFields(ResetedFields,DataCompositionSettings)
	
	If ResetedFields <> Undefined Then
		DataCompositionSettings.Filter.Items.Delete(ResetedFields);
	EndIf;	

EndProcedure	

Function GetFieldUse(Field,ConsidireParent = False)
	
	If ConsidireParent 
		AND Field.Use Then
		CurrentField = Field;
		While CurrentField.Parent <> Undefined Do
			If Not CurrentField.Parent.Use Then
				Return False;
			EndIf;
			CurrentField = CurrentField.Parent;
		EndDo;	
		Return CurrentField.Use;
	Else
		Return Field.Use;
	EndIf;	
	
EndFunction	

Procedure SetShowZerosAfterCommaForQuantities(ReportObject, SettingsComposer = Undefined) Export
	
	NewItem = SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	For each Resource In GetSelectedFields(SettingsComposer) Do
		
		ResourceField = SettingsComposer.Settings.SelectionAvailableFields.FindField(Resource.Field);
		
		If ResourceField = Undefined OR Not ResourceField.Resource Then
			Continue;
		EndIf;
		
		If Not Resource.Use Then
			Continue;
		EndIf;
		
		If Find(Upper(String(Resource.Field)),Upper("Quantity"))<=0 Then
			Continue;
		EndIf;	
		
		// Fields settings
		Field = NewItem.Fields.Items.Add();
		Field.Field = Resource.Field;
		
	EndDo;
	
	If NewItem.Fields.Items.Count() = 0 Then
		SettingsComposer.Settings.ConditionalAppearance.Items.Delete(NewItem);
	Else
		ParameterValue = NewItem.Appearance.FindParameterValue(New DataCompositionParameter("Format"));
		ParameterValue.Use = True;
		If ReportObject.ShowZerosAfterCommaForQuantities Then
			ParameterValue.Value = "NFD=3"
		Else
			ParameterValue.Value = "";
		EndIf;	
	EndIf;
	
EndProcedure	

// Returns list of group fields all groups from data composer
Function GetGroupsFields(SettingsComposer) Export
	
	FieldList = New ValueList;
	
	Structure = SettingsComposer.Settings.Structure;
	AddFieldsGroups(Structure, FieldList);
	Return FieldList;
	
EndFunction

Procedure AddFieldsGroups(Structure, FieldList)
	
	For each StructureItem In Structure Do
		If TypeOf(StructureItem) = Type("DataCompositionNestedObjectSettings") Then
		    AddFieldsGroups(StructureItem.Settings.Structure,FieldList);
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
			AddFieldsGroups(StructureItem.Rows, FieldList);
			AddFieldsGroups(StructureItem.Columns, FieldList);
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
			AddFieldsGroups(StructureItem.Series, FieldList);
			AddFieldsGroups(StructureItem.Points, FieldList);
		Else
			For each CurrentGroupField In StructureItem.GroupFields.Items Do
				AvailableField = StructureItem.Selection.SelectionAvailableFields.FindField(CurrentGroupField.Field);
				FieldList.Add(String(AvailableField.Field), AvailableField.Title);
			EndDo;
			AddFieldsGroups(StructureItem.Structure, FieldList);
		EndIf;
	EndDo;
		
EndProcedure

#If Client Then
	
Function GetFieldNameFromDataPath(Field)
	
	FieldDataPath = String(Field);
	
	While True Do
		FoundDotPos = Find(FieldDataPath,".");
		If FoundDotPos>0 Then
			FieldDataPath = Right(FieldDataPath,StrLen(FieldDataPath) - FoundDotPos);
		Else
			Break;
		EndIf;	
	EndDo;	
	
	Return FieldDataPath;
	
EndFunction	

// Function recursively checks existance items in group
//
Function IsItemsInGroup(Item)
	
	AreItems = False;
	
	For Each CurItem In Item.Items Do
		
		If TypeOf(CurItem) = Type("DataCompositionFilterItemGroup") Then
			
			If NOT CurItem.Use Then
				Continue;
			EndIf;
			
			If NOT IsItemsInGroup(CurItem) Then
				Return False;
			Else
				AreItems = True;
			EndIf;
		Else
			If CurItem.Use Then
				AreItems = True;
			EndIf;
		EndIf;
	EndDo;
	
	Return AreItems;

EndFunction

// Returns  reports parameters structure for saving
Function GetTemplateReportParametersStructure(ReportObject) Export
	
	ParametersStructure = New Structure;
	ReportSettings = ReportObject.SettingsComposer.GetSettings();
	For each Attribute In ReportObject.Metadata().Attributes Do
		ParametersStructure.Insert(Attribute.Name, ReportObject[Attribute.Name]);
		FoundDataParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter(Attribute.Name));
		If FoundDataParameter<>Undefined Then
			FoundDataParameter.Value = ReportObject[Attribute.Name]; 
		EndIf;	
	EndDo;
	ParametersStructure.Insert("ComposerSettings", ReportSettings);
	Return ParametersStructure;
	
EndFunction

// Updates template reports header
Procedure UpdateTemplateReportHeader(ReportObject, ReportForm) Export
	
	If ValueIsFilled(ReportObject.SavedSetting) Then
		TextSavedSetting = " (" + ReportObject.SavedSetting + ")";
	Else
		TextSavedSetting = "";
	EndIf;
	
	ReportHeader = ReportObject.Metadata().Synonym;
	ReportForm.Caption = ReportHeader + TextSavedSetting;
	
EndProcedure

// Opens period settings form
Function SetupPeriod(PeriodSettings, BeginPeriod, EndPeriod) Export
	
	PeriodSettings.SetPeriod(BeginPeriod, ?(EndPeriod='0001-01-01', EndPeriod, EndOfDay(EndPeriod)));
	PeriodSettings.EditAsInterval = True;
	PeriodSettings.EditAsPeriod = True;
	PeriodSettings.SettingsMode = PeriodSettingsVariant.Period;
	If PeriodSettings.Edit() Then
		BeginPeriod = PeriodSettings.GetDateFrom();
		EndPeriod = PeriodSettings.GetDateTo();
		Return PeriodSettings;
	EndIf;

EndFunction

// Updates period parameters in settings composer
Procedure UpdatePeriodParametersOnForm(SettingsComposer, Form) Export
	
	BeginPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	EndPeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	PeriodParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	
	If BeginPeriodParameterValue <> Undefined Then
		BeginPeriodParameterValue.Value = Form.BeginPeriod;
	EndIf;
	
	If EndPeriodParameterValue <> Undefined Then
		EndPeriodParameterValue.Value = ?(Form.EndPeriod = '0001-01-01', Form.EndPeriod, EndOfDay(Form.EndPeriod));
	EndIf;
	
	If PeriodParameterValue <> Undefined Then
		PeriodParameterValue.Value = ?(Form.Period = '0001-01-01', Form.Period, EndOfDay(Form.Period));
	EndIf;
	
EndProcedure

// Updates items form for template report in settings composer
Procedure UpdateTemplateReportFormOnComposer(ReportObject, ReportForm) Export
	
	// Period parameters
	BeginPeriodParameterValue = ReportObject.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	EndPeriodParameterValue = ReportObject.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	PeriodParameterValue = ReportObject.SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	
	If BeginPeriodParameterValue <> Undefined 
	   AND EndPeriodParameterValue <> Undefined Then
	   	If TypeOf(BeginPeriodParameterValue.Value) = Type("Date") Then
			ReportForm.BeginPeriod = BeginPeriodParameterValue.Value;
		ElsIf TypeOf(BeginPeriodParameterValue.Value) = Type("StandardBeginningDate") Then
			ReportForm.BeginPeriod = BeginPeriodParameterValue.Value.Date;
		EndIf;	
		If TypeOf(EndPeriodParameterValue.Value) = Type("Date") Then
			ReportForm.EndPeriod = EndPeriodParameterValue.Value;
		ElsIf TypeOf(EndPeriodParameterValue.Value) = Type("StandardBeginningDate") Then
			ReportForm.EndPeriod = EndPeriodParameterValue.Value.Date;
		EndIf;	
		ReportForm.Controls.PeriodPanel.CurrentPage = ReportForm.Controls.PeriodPanel.Pages.Interval;
	ElsIf PeriodParameterValue <> Undefined Then
		ReportForm.Period = PeriodParameterValue.Value;
		ReportForm.Controls.PeriodPanel.CurrentPage = ReportForm.Controls.PeriodPanel.Pages.Period;
	Else
		ReportForm.Controls.PeriodPanel.CurrentPage = ReportForm.Controls.PeriodPanel.Pages.Empty;
	EndIf;
	
	// Header output cancelled
	Value = ReportObject.SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput")).Value;
	Check = (Value = DataCompositionTextOutputType.Output);
	ReportForm.Controls.FormActions.Buttons.Header.Check = Check;
	
EndProcedure

Function GetRowsArrayByRow(Val String) Export
	
	RowsArray = New Array;
	String = StrReplace(String, ",", Chars.LF);
	For Indexof = 1 To StrOccurenceCount(String, Chars.LF) + 1 Do
		RowsArray.Add(TrimAll(StrGetLine(String, Indexof)));
	EndDo;
	Return RowsArray;
	
EndFunction

// Processing of details in template reports
Procedure TemplateReportDetailsProcessing(Details, StandardProcessing, ReportObject, ReportForm) Export
	
	If ReportObject.ExtendedSetting Then
		Return;
	EndIf;
	If String(ReportObject) = "ExternalReportObject." + ReportObject.Metadata().Name Then
		IsExternalReport = True;
	Else 
		IsExternalReport = False;
	EndIf;
	
	StandardProcessing = False;
	
	IsDetailRecord = False;
	Item = ReportForm.DetailsData.Items[Details];
	If TypeOf(Item) = Type("DataCompositionFieldDetailsItem") Then
		Items = Item.GetParents();
		If Items.Count() > 0 Then
			Item = Items[0];
			If TypeOf(Item) = Type("DataCompositionGroupDetailsItem") Then
				IsDetailRecord = True;
			EndIf;
		EndIf;
	EndIf;
	
	FieldsDetailsArray = GetDetailsFieldsArray(Details, ReportForm.DetailsData);
	DetailsFieldsWithResourcesArray = GetDetailsFieldsArray(Details, ReportForm.DetailsData, , True);
	
	// Get fields Name for detailed cells
	FieldsArray = New Array; 
	For each DetailsField In DetailsFieldsWithResourcesArray Do
		If TypeOf(DetailsField) = Type("DataCompositionDetailsFieldValue") Then 
			FieldsArray.Add(DetailsField.Field);
		EndIf;
	EndDo;
		
	ChoiceList = New ValueList;
	
	// Add in details choice list other reports
	For each DetailsReport In ReportObject.Details Do
		If TypeOf(DetailsReport.Value) = Type("String") Then
			ChoiceList.Add(DetailsReport.Value, DetailsReport.Presentation, , PictureLib.Report);
		ElsIf TypeOf(DetailsReport.Value) = Type("Structure") Then
			RowsArray = GetRowsArrayByRow(DetailsReport.Value.Fields);
			For each Field In RowsArray Do
				If FieldsArray.Find(Field) <> Undefined Then
					ChoiceList.Add(DetailsReport.Value.ReportName, DetailsReport.Presentation, , PictureLib.Report);
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	// Add in details choice list open value
	Indexof = 0;
	For each DetailsField In FieldsDetailsArray Do
		If TypeOf(DetailsField) = Type("DataCompositionDetailsFieldValue")
		   AND DetailsField.Value <> Null Then
			AvailableField = GetAvailableFieldOnDataCompositionField(New DataCompositionField(DetailsField.Field), ReportForm.DetailsData);
			ChoiceList.Add("OpenValue" + Format(Indexof, "ND=2; NZ=; NLZ="), Nstr("en='Open: ';pl='Otwórz: ';ru='Открыть: '") + AvailableField.Title + " = """ +  DetailsField.Value + """",,PictureLib.Magnifier);
		EndIf;
		Indexof = Indexof + 1;
	EndDo;
	
	If Not IsDetailRecord AND Not IsExternalReport Then
		ChoiceList.Add("Drilldown", Nstr("en='Drilldown...';pl='Uszczegóławianie...';ru='Расшифровка...'"),,);
	EndIf;
	
	
	If ChoiceList.Count() = 0 Then
		Return;
	ElsIf ChoiceList.Count() = 1 Then
		SelectedValue = ChoiceList[0];
	Else
		SelectedValue = ReportForm.ChooseFromMenu(ChoiceList);
	EndIf;
		
	If SelectedValue = Undefined Then
		Return;
	ElsIf SelectedValue.Value = "StandartDetails" Then
		StandardProcessing = True;
		Return;
	ElsIf Left(SelectedValue.Value, 9) = "OpenValue" Then
		// Open value
		OpenValue(FieldsDetailsArray[Number(Right(SelectedValue.Value,2))].Value);
	ElsIf SelectedValue.Value = "Drilldown" Then
		// Drilldown by own report
		FieldChoiceForm = GetCommonForm("SettingsComposerAvailableFieldChoiceForm");
		FieldChoiceForm.SettingsComposer = ReportObject.SettingsComposer;
		FieldParents = New Array;
		AddParents(ReportForm.DetailsData.Items[Details], ReportForm.DetailsData, FieldParents);
		FieldChoiceForm.FieldParents = FieldParents;
		Result = FieldChoiceForm.DoModal();
		If Result = Undefined Then
			Return;
		EndIf;
		
		DetailProcessing = New DataCompositionDetailsProcess(ReportForm.DetailsData, 
			New DataCompositionAvailableSettingsSource(ReportObject.DataCompositionSchema));
			
		CompositionSettings = DetailProcessing.Drilldown(Details, Result.Field);
		
		NewReport = Reports[ReportObject.Metadata().Name].Create();
		FillPropertyValues(NewReport, ReportObject, , "SavedSetting");
		NewReport.SettingsComposer.LoadSettings(CompositionSettings);
		NewReportsForm = NewReport.GetForm();
		NewReportsForm.IsDetailProcessing = True;
		NewReportsForm.Open();
		NewReportsForm.RefreshReport();
		
	Else
		// Drilldown by other raport
		NewReportObject = Reports[SelectedValue.Value].Create();
		NewReportObject.ReportInitialization();
		NewReportObject.Setup(FieldsDetailsArray, ReportObject.SettingsComposer);
		NewReportsForm = NewReportObject.GetForm(,, New UUID);
		NewReportsForm.IsDetailProcessing = True;
		NewReportsForm.Open();
		NewReportsForm.RefreshReport()
	EndIf;
		
EndProcedure

// Reports setup  based on filters
Procedure SetupTemplateReport(ReportObject, Filter, MainReportComposer = Undefined) Export
	
	If TypeOf(Filter) <> Type("Array") Then
		Return;
	EndIf;
	
	// Filter settings
	For each FilterItem In Filter Do
		
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem") Then
			FilterField = FilterItem.LeftValue;
		Else
			FilterField = New DataCompositionField(FilterItem.Field);
		EndIf;
		
		If ReportObject.SettingsComposer.Settings.FilterAvailableFields.FindField(FilterField) = Undefined Then
			Continue;
		EndIf;
		
		NewFilterItem = ReportObject.SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem") Then
			FillPropertyValues(NewFilterItem, FilterItem);
		Else
			NewFilterItem.Use  = True;
			NewFilterItem.LeftValue  = FilterField;
			If FilterItem.Hierarchy Then
				If TypeOf(FilterItem.Value) = Type("ValueList") Then
					NewFilterItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
				Else
					NewFilterItem.ComparisonType = DataCompositionComparisonType.InHierarchy;
				EndIf;
			Else
				If TypeOf(FilterItem.Value) = Type("ValueList") Then
					NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
				Else
					NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
				EndIf;
			EndIf;
			
			NewFilterItem.RightValue = FilterItem.Value;
			
		EndIf;
				
	EndDo;
	
	// Parameter settings
	If MainReportComposer = Undefined Then
		Return;
	EndIf;
	For each MainReportParameter In MainReportComposer.Settings.DataParameters.Items Do
		ParameterValue = ReportObject.SettingsComposer.Settings.DataParameters.FindParameterValue(MainReportParameter.Parameter);
		If ParameterValue <> Undefined Then
			ParameterValue.Value = MainReportParameter.Value;
		EndIf;
	EndDo;
	 
EndProcedure

// Print table document without preview
Procedure PrintTemplateReport(Result) Export
	
	Result.Print();
	
EndProcedure

// Opens form for editing user fields
Procedure EditUserFields(SettingsComposer) Export
	
	UserFieldsConstructor = DataProcessors.UserFieldsConstructor.Create();
	Form = UserFieldsConstructor.GetForm(, );
	Form.SettingsComposer = SettingsComposer;
	Form.DoModal();
	
EndProcedure

// Returns form Name, for editing following users field
Function GetEditingUserFieldFormName(UserField) Export
	
	If TypeOf(UserField) = Type("DataCompositionUserFieldExpression") Then
		Return Undefined;
	EndIf;
	
	If UserField.Variants.Items.Count() > 0
	   AND TemplateReports.GetParameterFromRow(UserField.Variants.Items[0].Value) = "TableCompleting" Then
		FormName = TemplateReports.GetParameterFromRow(UserField.Variants.Items[0].Value, 2) + "Form" ;
	EndIf;
	If UserField.Variants.Items.Count() > 0
		AND UserField.Variants.Items[0].Value = "0TG" Then
		FormName = "IntervalsForm";
	EndIf;
	Return FormName;
	
EndFunction

Function GetParameterFromRow(Val String, ParameterNumber = 1) Export
	
	For Indexof = 1 To ParameterNumber Do
		CommaPosition = Find(String, ",");
		If CommaPosition = 0 Then
			Substring = String;
			Return Substring;
		Else
			Substring = Left(String, CommaPosition - 1);
		EndIf;
		String = Mid(String, CommaPosition + 1);
	EndDo;
	
	Return Substring;
	
EndFunction

#EndIf

// Return list of avaliable for choice resources
Function GetAvailableResourcesList(SettingsComposer, IncludeUserExpressionFields = True, IncludeUserFieldsSelection = True) Export
	ResourcesList = New ValueList;
	AddResources(ResourcesList, SettingsComposer.Settings.SelectionAvailableFields, SettingsComposer, IncludeUserExpressionFields, IncludeUserFieldsSelection);
	Return ResourcesList;
	
EndFunction

Function AddResources(ResourcesList, FieldsCollection, SettingsComposer, IncludeUserExpressionFields, IncludeUserFieldsSelection)
	
	For each AvailableField In FieldsCollection.Items Do
		If AvailableField.Resource Then
			UserField = FindUserField(SettingsComposer, AvailableField.Field);
			If UserField <> Undefined Then
				If Not (TypeOf(UserField) = Type("DataCompositionUserFieldExpression") AND IncludeUserExpressionFields
				 OR TypeOf(UserField) = Type("DataCompositionUserFieldCase") AND IncludeUserFieldsSelection) Then
				 Continue;
			 	EndIf;
			 EndIf;
			ResourcesList.Add(AvailableField.Field, AvailableField.Title);
		EndIf;
		If AvailableField.Folder Then
			AddResources(ResourcesList, AvailableField, SettingsComposer, IncludeUserExpressionFields, IncludeUserFieldsSelection);
		EndIf;
	EndDo;
	
EndFunction


// Returns avaliable field by composition field
Function GetAvailableFieldOnDataCompositionField(DataCompositionField, SettingsComposer) Export
	
	Return SettingsComposer.Settings.SelectionAvailableFields.FindField(DataCompositionField);
	
EndFunction

// Fills builder filter by composer filter
Procedure FillFilterByComposerFilter(Filter, ComposerFilter) Export

	FillPropertyValues(Filter, ComposerFilter, "Use, Presentation");
	
	If ComposerFilter.ComparisonType = DataCompositionComparisonType.Greater Then
		Filter.ComparisonType = ComparisonType.Greater;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
		Filter.ComparisonType = ComparisonType.GreaterOrEqual;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.InHierarchy Then
		Filter.ComparisonType = ComparisonType.InHierarchy;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.InList Then
		Filter.ComparisonType = ComparisonType.InList;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.InListByHierarchy Then
		Filter.ComparisonType = ComparisonType.InListByHierarchy;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.Less Then
		Filter.ComparisonType = ComparisonType.Less;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual Then
		Filter.ComparisonType = ComparisonType.LessOrEqual;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.NotEqual Then
		Filter.ComparisonType = ComparisonType.NotEqual;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.Equal Then
		Filter.ComparisonType = ComparisonType.Equal;
	ElsIf ComposerFilter.ComparisonType = DataCompositionComparisonType.Contains Then
		Filter.ComparisonType = ComparisonType.Contains;
	EndIf;
	
	Filter.Value = ComposerFilter.RightValue;
	
EndProcedure

// Returns list of all groups settings composer
Function GetGroups(SettingsComposer) Export
	
	FieldList = New ValueList;
	
	Structure = SettingsComposer.Settings.Structure;
	AddGroups(Structure, FieldList);
	Return FieldList;
	
EndFunction

Procedure AddGroups(Structure, FieldList)
	
	For each StructureItem In Structure Do
		If TypeOf(StructureItem) = Type("DataCompositionTable") Then
			AddGroups(StructureItem.Rows, FieldList);
			AddGroups(StructureItem.Columns, FieldList);
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
			AddGroups(StructureItem.Series, FieldList);
			AddGroups(StructureItem.Points, FieldList);
		Else
			FieldList.Add(StructureItem);
			AddGroups(StructureItem.Structure, FieldList);
		EndIf;
	EndDo;
		
EndProcedure

// // Returns group by field group
Function GetStructureItemByGroupField(GroupField, SettingsComposer) Export
	
	Structure = SettingsComposer.Settings.Structure;
	Return FindStructureItemByGroupField(Structure, GroupField);

EndFunction

Function FindStructureItemByGroupField(Structure, GroupField)
	
	For each StructureItem In Structure Do
		If TypeOf(StructureItem) = Type("DataCompositionTable") Then
			StructureItem = FindStructureItemByGroupField(StructureItem.Rows, GroupField);
			If StructureItem = Undefined Then
				Return FindStructureItemByGroupField(StructureItem.Columns, GroupField);
			Else
				Return StructureItem;
			EndIf;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
			StructureItem = FindStructureItemByGroupField(StructureItem.Series, GroupField);
			If StructureItem = Undefined Then
				Return FindStructureItemByGroupField(StructureItem.Points, GroupField);
			Else
				Return StructureItem;
			EndIf;
		Else
			For each CurrentGroupField In StructureItem.GroupFields.Items Do
				If GroupField = CurrentGroupField.Field Then
					Return StructureItem;
				EndIf;
			EndDo;
			Return FindStructureItemByGroupField(StructureItem.Structure, GroupField);
		EndIf;
	EndDo;

EndFunction


// Returns data sets array - query in data composition schema
Function GetDataSetsQuery(DCS, DataSets = Undefined, DataSetsArray = Undefined) Export
	
	If DataSetsArray = Undefined Then
		DataSetsArray = New Array;
	EndIf;
	If DataSets = Undefined Then
		DataSets = DCS.DataSets;
	EndIf;
	
	For each DataSet In DataSets Do
		If TypeOf(DataSet) = Type("DataCompositionSchemaDataSetQuery") Then
			DataSetsArray.Add(DataSet);
		ElsIf TypeOf(DataSet) = Type("DataCompositionSchemaDataSetUnion") Then
			GetDataSetsQuery(DCS, DataSet.Items, DataSetsArray)
		EndIf;
	EndDo;
	Return DataSetsArray;
	
EndFunction

// Returns group - details records of settings composer
Function GetStructureItemDetailRecords(SettingsComposer) Export
	
	StructureLastItem = GetStructureLastItem(SettingsComposer, True);
	If TypeOf(StructureLastItem) = Type("DataCompositionGroup")
	 OR TypeOf(StructureLastItem) = Type("DataCompositionTableGroup")
	 OR TypeOf(StructureLastItem) = Type("DataCompositionChartGroup") Then
		If StructureLastItem.GroupFields.Items.Count() = 0 Then
			Return StructureLastItem;
		EndIf;
	EndIf;
	
EndFunction

// Returns last item of structure - group
Function GetStructureLastItem(SettingsComposer, Rows = True) Export
	
	Structure = SettingsComposer.Settings.Structure;
	If Structure.Count() = 0 Then
		Return SettingsComposer.Settings;
	EndIf;
	
	If Rows Then
		StructureTableName = "Rows";
		ChartStructureName = "Series";
	Else
		StructureTableName = "Columns";
		ChartStructureName = "Points";
	EndIf;
	
	While True Do
		StructureItem = Structure[0];
		If TypeOf(StructureItem) = Type("DataCompositionTable") AND StructureItem[StructureTableName].Count() > 0 Then
			If StructureItem[StructureTableName][0].Structure.Count() = 0 Then
				Structure = StructureItem[StructureTableName];
				Break;
			EndIf;
			Structure = StructureItem[StructureTableName][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") AND StructureItem[ChartStructureName].Count() > 0 Then
			If StructureItem[ChartStructureName][0].Structure.Count() = 0 Then
				Structure = StructureItem[ChartStructureName];
				Break;
			EndIf;
			Structure = StructureItem[ChartStructureName][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionTableGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
			If StructureItem.Structure.Count() = 0 Then
				Break;
			EndIf;
			Structure = StructureItem.Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
			Return StructureItem[StructureTableName];
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart")	Then
			Return StructureItem[ChartStructureName];
		Else
			Return StructureItem;
		EndIf;
	EndDo;
	
	Return Structure[0];
	
EndFunction


// Return user field by data composition field
Function FindUserField(SettingsComposer, DataCompositionField) Export
	
	For each UserField In SettingsComposer.Settings.UserFields.Items Do
		If UserField.DataPath = String(DataCompositionField) Then
			Return UserField;
		EndIf;
	EndDo;
	
EndFunction

////////////////////////////////////////////////////////////
// FUNCTIONS FOR PROGRAMMATICALLY SETUP OF SETTING COMPOSER

// Set output parameter for data composer
Function SetOutputParameter(SettingsComposer, ParameterName, Value) Export
	
	ParameterValue = SettingsComposer.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If ParameterValue = Undefined Then
		Return Undefined;
	Else
		ParameterValue.Use = True;
		ParameterValue.Value = Value;
		Return ParameterValue;
	EndIf;
	
EndFunction

// In parameters structure restore reports state
Procedure ApplyReportParametersStructure(ReportObject, ParametersStructure) Export
	
	If ParametersStructure = Undefined Then
		Return;
	EndIf;
	FillPropertyValues(ReportObject, ParametersStructure);
	ReportObject.ReportInitialization();
	ReportObject.SettingsComposer.LoadSettings(ParametersStructure.ComposerSettings);
	
EndProcedure

Procedure TemplateReportInitialization(ReportObject) Export
	ReportObject.NegativeInRed = True;
EndProcedure

// Set data parameter for data composer
Function SetParameter(SettingsComposer, ParameterName, Value = Undefined) Export
	
	Return SetSettingParameter(SettingsComposer.Settings, ParameterName, Value);
	
EndFunction

Function SetSettingParameter(Setting, ParameterName, Value = Undefined) Export
	
	ParameterValue =Setting.DataParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If ParameterValue = Undefined Then
		
		Return Undefined;
		
	ElsIf TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
		
		If Value = Undefined Then
			ParameterValue.Use = True;
			Return ParameterValue;
		Else	
			ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
			ParameterValue.Value.Date = Value;
			ParameterValue.Use = True;
		EndIf;	
		
	Else
		
		If Value <> Undefined Then
			
			ParameterValue.Use = True;
			ParameterValue.Value = Value;
			Return ParameterValue;
			
		Else
			
			ParameterValue.Use = True;
			Return ParameterValue;
			
		EndIf;
		
	EndIf;
	
EndFunction


// Add filter in filter set for composer or filter group
Function AddFilter(StructureItem, Val Field, Value, ComparisonType = Undefined) Export
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Filter = StructureItem.Settings.Filter;
	Else
		Filter = StructureItem;
	EndIf;
	
	If ComparisonType = Undefined Then
		ComparisonType = DataCompositionComparisonType.Equal;
	EndIf;
	
	NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewItem.LeftValue = Field;
	NewItem.RightValue = Value;
	NewItem.ComparisonType = ComparisonType;
	Return NewItem;
	
EndFunction

// Delete filter from settings composer, if field is not specified then clears filter
Function DeleteFilter(SettingsComposer, Val Field = Undefined) Export
	
	If Field = Undefined Then
		SettingsComposer.Settings.Filter.Items.Clear();
		Return True;
	EndIf;
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	FieldDeleted = False;
	Items = GetFilterItems(SettingsComposer);
	For each Item In Items Do
		If Item.Use AND Item.LeftValue = Field Then
			Item.Use = False;
			FieldDeleted = True;
		EndIf;
	EndDo;
	Return FieldDeleted;
	
EndFunction

// Returns filter items array or group items filter
Function GetFilterItems(SettingsComposer, OnlyGroups = False) Export

	FieldsArray = New Array;
	AddFilterItemsIntoArray(SettingsComposer.Settings.Filter.Items, FieldsArray, OnlyGroups);
	Return FieldsArray;
	
EndFunction

Procedure AddFilterItemsIntoArray(Items, FieldsArray, OnlyGroups = False)
	
	For each Item In Items Do
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
			If OnlyGroups Then
				FieldsArray.Add(Item);
			EndIf;
			AddFilterItemsIntoArray(Item.Items, FieldsArray, OnlyGroups);
		Else
			If Not OnlyGroups Then
				FieldsArray.Add(Item);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Complete report before output
Procedure CompleteTemplateReportBeforeOutput(ReportObject, SettingsComposer = Undefined) Export
	
	ReportObjectMetadata = ReportObject.Metadata();
	
	#If ThickClientOrdinaryApplication Then
	If CommonAtServer.IsDocumentAttribute("ExtendedSetting",ReportObjectMetadata) Then		
		If ReportObject.ExtendedSetting  Then
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	#EndIf 
	
	If SettingsComposer = Undefined Then
		SettingsComposer = ReportObject.SettingsComposer;
	EndIf;
	
	// Processing "Negative in red"
	If ReportObject.NegativeInRed Then
		
		NewItem = SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		// Appearence settings
		ParameterValue = NewItem.Appearance.FindParameterValue(New DataCompositionParameter("MarkNegatives"));
		ParameterValue.Use = True;
		ParameterValue.Value = True;
		
		For each Resource In GetSelectedFields(SettingsComposer) Do
			
			ResourceField = SettingsComposer.Settings.SelectionAvailableFields.FindField(Resource.Field);
			
			If ResourceField = Undefined OR Not ResourceField.Resource Then
				Continue;
			EndIf;
			
			If Not GetFieldUse(Resource,True) Then
				Continue;
			EndIf;
			
			// Fields settings
			Field = NewItem.Fields.Items.Add();
			Field.Field = Resource.Field;
			
		EndDo;
		
		If NewItem.Fields.Items.Count() = 0 Then
			SettingsComposer.Settings.ConditionalAppearance.Items.Delete(NewItem);
		EndIf;
		
	EndIf;
	
	SetShowZerosAfterCommaForQuantities(ReportObject,SettingsComposer);
	
	// Cancel header output, header was outputed manually earlier
	SetOutputParameter(SettingsComposer, "TitleOutput", DataCompositionTextOutputType.DontOutput);
	
EndProcedure

// Return selected fields array or group selected fields
Function GetSelectedFields(StructureItem, OnlyGroups = False) Export
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") 
		OR TypeOf(StructureItem) = Type("DataCompositionNestedObjectSettings")  Then
		SelectedFields = StructureItem.Settings.Selection;
	Else
		SelectedFields = StructureItem;
	EndIf;
	
	FieldsArray = New Array;
	AddSelectedFieldsIntoArray(SelectedFields.Items, FieldsArray, OnlyGroups);
	Return FieldsArray;
	
EndFunction

Procedure AddSelectedFieldsIntoArray(StructureItem, FieldsArray, OnlyGroups = False)
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		SelectedFields = StructureItem.Settings.Selection;
	Else
		SelectedFields = StructureItem;
	EndIf;
	
	For each Item In StructureItem Do
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField") Then
			Continue;
		ElsIf TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then
			If OnlyGroups Then
				FieldsArray.Add(Item);
			EndIf;
			AddSelectedFieldsIntoArray(Item.Items, FieldsArray, OnlyGroups);
		Else
			If Not OnlyGroups Then
				FieldsArray.Add(Item);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Add in data set field
Function AddDataSetField(DataSet, Field, Title, DataPath = Undefined) Export
	
	If DataPath = Undefined Then
		DataPath = Field;
	EndIf;
	
	DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	DataSetField.Field        = Field;
	DataSetField.Title   = Title;
	DataSetField.DataPath = DataPath;
	Return DataSetField;
	
EndFunction

	
// Delete specified selected field from settings composer if field is not specified then clears filter
Function DeleteSelectedField(StructureItem, Val Field = Undefined) Export
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		SelectedFields = StructureItem.Settings.Selection;
	Else
		SelectedFields = StructureItem;
	EndIf;
	
	If Field = Undefined Then
		SelectedFields.Items.Clear();
		Return True;
	EndIf;
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	FieldDeleted = False;
	Items = GetSelectedFields(SelectedFields);
	For each Item In Items Do
		If Item.Use AND Item.Field = Field Then
			Item.Use = False;
			FieldDeleted = True;
		EndIf;
	EndDo;
	Return FieldDeleted;
	
EndFunction

// Add group in settings composer in bottom of level structure, if field is not specified then clears filter
Function AddGroup(SettingsComposer, Val Field = Undefined, Rows = True) Export
	
	StructureItem = GetStructureLastItem(SettingsComposer, Rows);
	If StructureItem = Undefined 
	 OR GetStructureItemDetailRecords(SettingsComposer) <> Undefined 
	   AND Field = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionTableGroup") 
	 OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
		NewGroup = StructureItem.Structure.Add();
	ElsIf TypeOf(StructureItem) = Type("DataCompositionTableStructureItemCollection")
		OR TypeOf(StructureItem) = Type("DataCompositionChartStructureItemCollection") Then
		NewGroup = StructureItem.Add();
	Else
		NewGroup = StructureItem.Structure.Add(Type("DataCompositionGroup"));
	EndIf;
	
	NewGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	NewGroup.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	If Field <> Undefined Then
		GroupField = NewGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = Field;
	EndIf;
	Return NewGroup;
	
EndFunction

// Function delete from setting composer specified in parameter group, if field is not specified then clears filter 
Function DeleteGroup(SettingsComposer, Val Field = Undefined, Rows = True) Export
	
	If SettingsComposer.Settings.Structure.Count() = 0 Then
		Return Undefined;
	EndIf;
	Item = SettingsComposer.Settings.Structure[0];
	If TypeOf(Item) = Type("DataCompositionTable") Then
		If Rows AND Item.Rows.Count() > 0 Then
			Item = Item.Rows[0];
		ElsIf Not Rows AND Item.Columns.Count() > 0 Then
			Item = Item.Columns[0];
		Else
			Return Undefined;
		EndIf;
	ElsIf TypeOf(Item) = Type("DataCompositionChart") Then
		If Rows AND Item.Series.Count() > 0 Then
			Item = Item.Series[0];
		ElsIf Not Rows AND Item.Points.Count() > 0 Then
			Item = Item.Points[0];
		Else
			Return Undefined;
		EndIf;
	EndIf;
	If Field = Undefined Then
		SettingsComposer.Settings.Structure.Clear();
		Return Undefined;
	EndIf;
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	While True Do
		If Item.GroupFields.Items.Count() > 0 
		   AND Item.GroupFields.Items[0].Field = Field Then
		   Item.Parent.Structure.Clear();
		   Break;
		   Return True;
		ElsIf Item.Structure.Count() > 0 Then
		   Item = Item.Structure[0];
		Else 
		   Break;
		EndIf;
   EndDo;
	
EndFunction


// Function add selected field in set of selected fields
Function AddSelectedField(StructureItem, Val Field, Title = Undefined) Export
		
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		SelectedFields = StructureItem.Settings.Selection;
	Else
		SelectedFields = StructureItem;
	EndIf;
	
	If TypeOf(Field) = Type("String") Then
		Field = New DataCompositionField(Field);
	EndIf;
	SelectedField = SelectedFields.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = Field;
	If Title <> Undefined Then
		SelectedField.Title = Title;
	EndIf;
	Return SelectedField;

EndFunction

// Function add total field in data composition schema. If parameter expression is not specified, then Sum(DataPath)
Function AddTotalField(DCS, DataPath, Expression = Undefined) Export
	
	If Expression = Undefined Then
		Expression = "Sum(" + DataPath + ")";
	EndIf;
	
	TotalField = DCS.TotalFields.Add();
	TotalField.DataPath = DataPath;
	TotalField.Expression = Expression;
	Return TotalField;
	
EndFunction

// Add in data set period fields second, minute, hour ....
Function AddPeriodFieldsIntoDataSet(DataSet) Export
	
	PeriodsList = New ValueList;
	PeriodsList.Add("SecondPeriod",   NStr("en='Period second';pl='Okres wg secundy'"));
	PeriodsList.Add("MinutePeriod",    NStr("en='Period minute';pl='Okres wg minuty'"));
	PeriodsList.Add("HourPeriod",       NStr("en='Period hour';pl='Okres wg godziny'"));
	PeriodsList.Add("DayPeriod",      NStr("en='Period day';pl='Okres wg dnia'"));
	PeriodsList.Add("WeekPeriod",    NStr("en='Period week';pl='Okres wg tygodnia'"));
	PeriodsList.Add("TenDaysPeriod",    NStr("en='Period tendays';pl='Okres wg 10-dni'"));
	PeriodsList.Add("MonthPeriod",      NStr("en='Period month';pl='Okres wg miesiąca'"));
	PeriodsList.Add("QuarterPeriod",   NStr("en='Period quarter';pl='Okres wg kwartała'"));
	PeriodsList.Add("HalfYearPeriod", NStr("en='Period halfyear';pl='Okres wg pół roku'"));
	PeriodsList.Add("YearPeriod",       NStr("en='Period year';pl='Okres wg roku'"));
	
	FolderName = Nstr("en='Periods';pl='Okresy';ru='Периоды'");
	DataSetFieldsList = New ValueList;
	DataSetFieldFolder = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetFieldFolder"));
	DataSetFieldFolder.Title   = FolderName;
	DataSetFieldFolder.DataPath = FolderName;
		
	For each Period In PeriodsList Do
		DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		DataSetField.Field        = Period.Value;
		DataSetField.Title   = Period.Presentation;
		DataSetField.DataPath = FolderName + "." + Period.Value;
		DataSetFieldsList.Add(DataSetField);
	EndDo;
	
	Return DataSetFieldsList;
	
EndFunction

// Function add in composition schema data source with type "Local"
Function AddLocalDataSource(DCS) Export
	
	DataSource = DCS.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	Return DataSource;

EndFunction

// Function add data set - query in specified in parameter data set collection
Function AddDataSetQuery(DataSets, DataSource, DataSetName = "DataSet1") Export
	
	DataSet = DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = DataSetName;
	DataSet.DataSource = DataSource.Name;
	Return DataSet;

EndFunction

// Add in templates composition template with details for resources
Procedure CompleteTemplatesCompositionTemplateResourcesDetails(CompositionTemplate, SettingsComposer) Export
	
	For each Template In CompositionTemplate.Templates Do
		// Get array parameters details
		FieldsExpressionsArray = New Array;
		For each Parameter In Template.Parameters Do
			If TypeOf(Parameter) <> Type("DataCompositionDetailsAreaParameter") Then
				Continue;
			EndIf;
			For each FieldExpression In Parameter.FieldExpressions Do
				If Not IsDetailParameterFieldExpressionResource(FieldExpression, SettingsComposer) Then
					FieldsExpressionsArray.Add(FieldExpression);
				EndIf;
			EndDo;
		EndDo;
		// Set parameters details in resources
		For each Parameter In Template.Parameters Do
			If TypeOf(Parameter) <> Type("DataCompositionDetailsAreaParameter") Then
				Continue;
			EndIf;
			Resource = False;
			For each FieldExpression In Parameter.FieldExpressions Do
				If IsDetailParameterFieldExpressionResource(FieldExpression, SettingsComposer) Then
					Resource = True;
					Break;
				EndIf;
			EndDo;
			If Not Resource Then
				Continue;
			EndIf;
			For each FieldExpression In FieldsExpressionsArray Do
				If Parameter.FieldExpressions.Find(FieldExpression.Field) <> Undefined Then
					Continue;
				EndIf;
				NewFieldExpression = Parameter.FieldExpressions.Add();
				FillPropertyValues(NewFieldExpression, FieldExpression);
			EndDo;
		EndDo;
	EndDo;

EndProcedure

Function IsDetailParameterFieldExpressionResource(FieldExpression, SettingsComposer)
	
	AvailableResources = TemplateReports.GetAvailableResourcesList(SettingsComposer);
	AvailableResource = AvailableResources.FindByValue(New DataCompositionField(FieldExpression.Field));
	Return AvailableResource <> Undefined;
	
EndFunction

#If Client Then
	
//Procedure FilterDragCheck(SettingsComposer, Control, DragParameters, StandardProcessing, Row, Column) Export
//	
//	DragAndDrop.DragCheck_AllowSpreadsheetDocumentAndString(Control, DragParameters, StandardProcessing, Row, Column);

//EndProcedure	

//Procedure FilterDrag(SettingsComposer, Control, DragParameters, StandardProcessing, Row, Column) Export
//	
//	If TypeOf(DragParameters.Value) = Type("SpreadsheetDocument")
//		OR TypeOf(DragParameters.Value) = Type("String") Then
//		
//		If TypeOf(DragParameters.Value) = Type("SpreadsheetDocument") Then
//			ValuesArray = GetValuesArrayFromSpreadsheetDocument(DragParameters.Value);
//		ElsIf TypeOf(DragParameters.Value) = Type("String") Then
//			ValuesArray = GetValuesArrayFromString(DragParameters.Value);
//		EndIf;	
//		
//		ValuesArrayCount = ValuesArray.Count();
//		If ValuesArrayCount = 0 Then
//			Return;
//		EndIf;
//		
//		StandardProcessing = False;
//		DragParameters.Action = DragAction.Copy;
//		DragParameters.AllowedActions = DragAllowedActions.Copy;
//		
//		If Row = Undefined Then
//			SettingsComposerAvailableFilterItemsForm = GetCommonForm("SettingsComposerAvailableFilterItemsForm");
//			SettingsComposerAvailableFilterItemsForm.SettingsComposer = SettingsComposer;
//			Result = SettingsComposerAvailableFilterItemsForm.DoModal();
//			If Result = True Then
//				Row = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
//				Row.LeftValue = New DataCompositionField(SettingsComposerAvailableFilterItemsForm.DataCompositionField.Field);
//			Else
//				Return;
//			EndIf;	
//		EndIf;	
//		Row.Use = True;
//		If ValuesArrayCount = 1 Then
//			Row.RightValue = ValuesArray[0];
//			If Row.ComparisonType <> DataCompositionComparisonType.NotEqual Then
//				Row.ComparisonType = DataCompositionComparisonType.Equal;
//			EndIf;	
//		Else
//			ValueList = New ValueList;
//			ValueList.LoadValues(ValuesArray);
//			Row.RightValue = ValueList;
//			If Row.ComparisonType <> DataCompositionComparisonType.NotInList Then
//				Row.ComparisonType = DataCompositionComparisonType.InList;
//			EndIf;	
//		EndIf;		
//		
//	EndIf;
//		
//EndProcedure	

Function GetValuesArrayFromString(String) Export
	
	ValuesArray = New Array;
	
	For i = 1 To StrLineCount(String) Do
		
		ValuesArray.Add(TrimAll(StrGetLine(String,i)));
		
	EndDo;	
	
	Return ValuesArray;
	
EndFunction	

Function GetValuesArrayFromSpreadsheetDocument(SpreadsheetDocument) Export
	
	ValuesArray = New Array;
	
	For i = 1 To SpreadsheetDocument.TableHeight Do
		
		ValuesArray.Add(TrimAll(SpreadsheetDocument.Area(i,1,i,1).Text));
		
	EndDo;	
	
	Return ValuesArray;
	
EndFunction	

// Function add data set - union in specified in parameter data set collection
Function AddDataSetUnion(DataSets, DataSource, DataSetName = "DataSet1") Export
	
	DataSet = DataSets.Add(Type("DataCompositionSchemaDataSetUnion"));
	DataSet.Name = DataSetName;
	Return DataSet;

EndFunction

Procedure FillDataSetFieldBalance(DataSetField, BalanceGroup) Export
	                                                         
	DataPath = DataSetField.DataPath;
	
	If Find(DataPath, "OpeningBalance") > 0 OR Find(DataPath, "ClosingBalance") > 0 Then
			DataSetField.Role.Balance = True;
			DataSetField.Role.BalanceGroup = BalanceGroup;
			If Upper(Right(DataPath, 2)) = "DR" Then
				DataSetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Debit
			ElsIf Upper(Right(DataPath, 2)) = "CR" Then
				DataSetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Credit
			Else
				DataSetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None
			EndIf;
			If Find(DataPath, "OpeningBalance") > 0 Then
				DataSetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
			ElsIf Find(DataPath, "ClosingBalance") > 0 Then
				DataSetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
			Else
				DataSetField.Role.BalanceType = DataCompositionBalanceType.None;
			EndIf;
		EndIf;	
		
EndProcedure

Function ShowSchema(DCS, SettingsComposer, Form) Export
	
	CopyDataCompositionSettings(DCS.SettingsByDefault, SettingsComposer.GetSettings());
	//DCS.DataSets[0].Items[0].Query = StrReplace(DCS.DataSets[0].Items[0].Query, "SELECT", "SELECT" + Chars.LF);
	//If OutputExpandedBalance Then
	//	DCS.DataSets[0].Items[1].Query = StrReplace(DCS.DataSets[0].Items[1].Query, "SELECT", "SELECT" + Chars.LF);
	//EndIf;
	Builder = New DataCompositionSchemaWizard(DCS);
	Builder.Edit(Form);
	
	Return True;
	
EndFunction

Procedure TemplateReportChangesProcessingInFormReport(ReportObject, ReportForm) Export
	
	If ReportObject.SavedSetting <> Undefined 
	   AND ReportObject.SavedSetting.SaveAutomatically Then
		ReportForm.SaveSettings();
	EndIf;
	                                	
EndProcedure

Procedure SaveOrShowReportSettingsXML(ReportObject,SettingsComposer,Save = False) Export
	
	RealFolderPath = CommonAtServer.GetUserSettingsValue("ReportsDefaultDirectory",SessionParameters.CurrentUser);
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	ReportObjectMetadata = ReportObject.Metadata();
	If ValueIsFilled(ReportObject.SavedSetting) Then
		SavedSettingName = TrimAll(ReportObject.SavedSetting.Description);
	Else
		SavedSettingName = "";
	EndIf;	
	ReportName = ReportObject.Metadata().Name + ?(IsBlankString(SavedSettingName),"","_"+SavedSettingName);
	
	If CommonAtServer.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName",SessionParameters.CurrentUser) Then
		FileInXMLFormat = RealFolderPath + ?(Not IsBlankString(RealFolderPath),"\","") + AdditionalInformationRepository.GenerateFileName(ReportName +".xml",CurrentDate());
	Else	
		FileInXMLFormat = RealFolderPath + ?(Not IsBlankString(RealFolderPath),"\","") + ReportName +".xml";
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.SetFileType("UTF-8");
	TextDocument.SetText(Common.SerializeObject(SettingsComposer.GetSettings()));
	
	If Save Then
		
		Mode = FileDialogMode.Save;
		SaveFileDialog = New FileDialog(Mode);
		SaveFileDialog.FullFileName = FileInXMLFormat;
		SaveFileDialog.Directory = RealFolderPath;
		SaveFileDialog.DefaultExt = "xml";
		Filter = Nstr("en='XML files';pl='Pliki XML'")+"(*.xml)|*.xml";
		SaveFileDialog.Filter = Filter;
		SaveFileDialog.CheckFileExist = True;
		SaveFileDialog.Multiselect = False;
		SaveFileDialog.Title = Nstr("en='Export report settings';pl='Eksportuj ustawienia raportu'");
		
		If SaveFileDialog.Choose() Then
			FileInXMLFormat = SaveFileDialog.FullFileName;
		Else
			Return;
		EndIf;
				
		TextDocument.Write(FileInXMLFormat,"UTF-8");
	Else
		
		TextDocument.Show(ReportName,FileInXMLFormat);
		
	EndIf;	
	
EndProcedure

Function RestoreReportSettingsXML(ReportObject,SettingsComposerSettings) Export
		
	RealFolderPath = CommonAtServer.GetUserSettingsValue("ReportsDefaultDirectory",SessionParameters.CurrentUser);
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	FileDialog = New FileDialog(FileDialogMode.Open);

	FileDialog.Filter  = Nstr("en='XML files';pl='Pliki XML'")+"(*.xml)|*.xml";
	FileDialog.Title   = Nstr("en='Import report settings';pl='Importuj ustawienia raportu'");
	FileDialog.Preview = False;
	FileDialog.DefaultExt              = "XML";

	XMLFileName = "";
	If FileDialog.Choose() Then
		XMLFileName = FileDialog.FullFileName;
	EndIf;

	If Not IsBlankString(XMLFileName) Then
		
		TextDocument = New TextDocument;
		TextDocument.Read(XMLFileName,"UTF-8");
		NewSettingComposerSettings = Common.GetObjectFromXML(TextDocument.GetText(),Type("DataCompositionSettings"));
		Return NewSettingComposerSettings;
	Else
		Return SettingsComposerSettings;
	EndIf;	
	
EndFunction

#EndIf

Procedure PerformReportsGeneratingSchedules(ReportsGeneratingScheduleRef) Export
	
	GeneratedReportsValueTable = New ValueTable;
	GeneratedReportsValueTable.Columns.Add("FileName");
	GeneratedReportsValueTable.Columns.Add("ValueStorage");
	GeneratedReportsValueTable.Columns.Add("AttachmentType");
	GeneratedReportsValueTable.Columns.Add("FtpPath");
	
	For Each ReportName in ReportsGeneratingScheduleRef.ScheduleTable Do
		Try
			Spreadsheet = New SpreadsheetDocument;
			CurrentReportAttachmentType = ReportName.AttachmentType;	
			If CurrentReportAttachmentType = Enums.AttachmentType.TXT Then
				Spreadsheet = New TextDocument;
			EndIf;
			
			FileNameWithoutExtension = AdditionalInformationRepository.GenerateFileName(ReportName.AttachmentFileName);
			
			Report = Reports[ReportName.Report].Create();
			
			Report.SavedSetting = ReportName.Settings;
			Report.ApplySetting();
			
			StandardPeriod = ReportName.ReportPeriod.Get();
			If StandardPeriod <> Undefined Then
				BeginOfPeriod = BegOfDay(StandardPeriod.StartDate);
				EndOfPeriod = EndOfDay(StandardPeriod.EndDate);
				SetParameter(Report.SettingsComposer,"BeginOfPeriod",BeginOfPeriod);
				SetParameter(Report.SettingsComposer,"EndOfPeriod",EndOfPeriod);
				SetParameter(Report.SettingsComposer,"Period",EndOfPeriod);	
				
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[BYYYY]", Format(BeginOfPeriod,"DF=yyyy"));
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[BMM]", Format(BeginOfPeriod,"DF=MM"));
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[BDD]", Format(BeginOfPeriod,"DF=dd"));
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[EYYYY]", Format(EndOfPeriod,"DF=yyyy"));
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[EMM]", Format(EndOfPeriod,"DF=MM"));
				FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[EDD]", Format(EndOfPeriod,"DF=dd"));
			EndIf;	
			
			FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[CD]", Format(GetServerDate(),"DF=yyyyMMdd"));
			FileNameWithoutExtension = StrReplace(FileNameWithoutExtension, "[CT]", Format(GetServerDate(),"DF=HHmmss"));
			
			Report.GenerateReport(Spreadsheet,,False);
			
			CurrentReportAttachmentType = ReportName.AttachmentType;	
			If CurrentReportAttachmentType = Enums.AttachmentType.XLSX OR CurrentReportAttachmentType = Enums.AttachmentType.XLS Then
				FileInXLSFormat = GetTempFileName();
				Spreadsheet.Output = UseOutput.Enable;
				Spreadsheet.Write(FileInXLSFormat, SpreadsheetDocumentFileType.XLS);
				FileName = FileNameWithoutExtension + ".XLS";
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInXLSFormat));
			EndIf;
			If CurrentReportAttachmentType = Enums.AttachmentType.XLSX Then
				FileInXLSFormat = GetTempFileName();
				Spreadsheet.Output = UseOutput.Enable;
				Spreadsheet.Write(FileInXLSFormat, SpreadsheetDocumentFileType.XLSX);
				FileName = FileNameWithoutExtension + ".XLSX";
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInXLSFormat));
			EndIf;
			
			If CurrentReportAttachmentType = Enums.AttachmentType.PDF Then
				FileInPDFFormat = GetTempFileName();
				Spreadsheet.Output = UseOutput.Enable;
				Spreadsheet.Write(FileInPDFFormat, SpreadsheetDocumentFileType.PDF);
				FileName = FileNameWithoutExtension + ".PDF";
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInPDFFormat));
			EndIf;
			
			FileInHTMLFormat = Undefined; 
			
			If CurrentReportAttachmentType = Enums.AttachmentType.HTML
				OR CurrentReportAttachmentType = Enums.AttachmentType.AddToContent Then
				FileName = FileNameWithoutExtension + ".HTM";
				FileInHTMLFormat = EmailModule.GenerateHTMLFile(Spreadsheet);
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInHTMLFormat,True));
			EndIf;  
			
			If CurrentReportAttachmentType = Enums.AttachmentType.MXL Then
				FileInMXLFormat = GetTempFileName();
				Spreadsheet.Output = UseOutput.Enable;
				Spreadsheet.Write(FileInMXLFormat, SpreadsheetDocumentFileType.MXL);
				FileName = FileNameWithoutExtension + ".MXL";
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInMXLFormat));
			EndIf; 
			
			If CurrentReportAttachmentType = Enums.AttachmentType.TXT Then
				FileInTXTFormat = GetTempFileName();
				Spreadsheet.Output = UseOutput.Enable;
				Spreadsheet.Write(FileInTXTFormat, SpreadsheetDocumentFileType.TXT);
				FileName = FileNameWithoutExtension + ".TXT";
				ValueStorage = New ValueStorage(EmailModule.GetBinaryData(FileInTXTFormat));
			EndIf; 
			
			GeneratedReportsValueTableRow = GeneratedReportsValueTable.Add();
			GeneratedReportsValueTableRow.FileName = FileName;
			GeneratedReportsValueTableRow.ValueStorage = ValueStorage;
			GeneratedReportsValueTableRow.AttachmentType = ReportName.AttachmentType;
			GeneratedReportsValueTableRow.FtpPath = ReportName.FtpPath;
						
		Except
			Alerts.AddAlert(NStr("en = 'Error report generating!'; pl = 'Błąd generowania raportu!'")+ " " +ErrorDescription());
		EndTry;
	EndDo;

	If ReportsGeneratingScheduleRef.Type = Enums.ReportGeneratingScheduleTypes.Ftp Then
		AdditionalInformationRepository.ReportsGeneratingScheduleSendToFtp(ReportsGeneratingScheduleRef,GeneratedReportsValueTable);
	ElsIf ReportsGeneratingScheduleRef.Type = Enums.ReportGeneratingScheduleTypes.Email Then	
		EmailModule.SendMailsReports(ReportsGeneratingScheduleRef,GeneratedReportsValueTable);
	EndIf;	
		
EndProcedure	

