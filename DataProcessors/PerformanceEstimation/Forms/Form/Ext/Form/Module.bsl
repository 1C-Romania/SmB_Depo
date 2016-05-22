
#Region FormEventsHandlers

// Procedure imports TS settings if it
// is the first opening, then all key operations are added to TS from the catalog.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	OverallSystemPerformance = PerformanceEstimationService.GetItemGeneralSystemPerformance();
	If OverallSystemPerformance.IsEmpty() Then
		Object.OverallSystemPerformance = NStr("en = 'Overall system performance'");
	Else
		Object.OverallSystemPerformance = OverallSystemPerformance;
	EndIf;
	
	Try
		ExportableSetup = ExportKeyOperations(Object.OverallSystemPerformance);
		Object.Performance.Load(ExportableSetup);
	Except
		MessageText = NStr("en = 'Failed to import the settings.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndTry;
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateTable = False;
	UpdateChart = False;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.PerformanceEstimation.Form.FilterForm") Then
		
		If ValueSelected <> Undefined Then
			RefreshIndicators(ValueSelected);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PerformanceOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Then
		Return;
	EndIf;
	
	OpenChoiceForm();
	
EndProcedure

&AtClient
Procedure FormOnCurrentPageChange(Item, CurrentPage)
	
	If Not UpdateTable Or Not UpdateChart Then
		If Items.Form.CurrentPage.Name = "PageChart" Then
			UpdateChart = True;
		ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
			UpdateTable = True;
		EndIf;
		RefreshIndicators();
	EndIf;
	
EndProcedure

&AtClient
Procedure TargetTimeWhenChanging(Item)
	
	TD = Items.Performance.CurrentData;
	If TD = Undefined Then
		Return;
	EndIf;
	
	ChangeTargetTime(TD.KeyOperation, TD.TargetTime);
	RefreshIndicators();
	
EndProcedure

// Display the key operation execution history.
//
&AtClient
Procedure PerformanceRange(Item, SelectedRow, Field, StandardProcessing)
	
	TSRow = Object.Performance.FindByID(SelectedRow);
	
	If Left(Field.Name, 18) <> "Performance"
		Or TSRow.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	StandardProcessing = False;
	
	BeginOfPeriod = 0;
	EndOfPeriod = 0;
	IndexPeriod = Number(Mid(Field.Name, 19));
	If Not CalculateDateTimeSegment(BeginOfPeriod, EndOfPeriod, IndexPeriod) Then
		Return;
	EndIf;
	
	HistorySettings = New Structure("KeyOperation, StartDate, EndDate", TSRow.KeyOperation, BeginOfPeriod, EndOfPeriod);
	
	OpenParameters = New Structure("HistorySettings", HistorySettings);
	OpenForm("DataProcessor.PerformanceEstimation.Form.ExecutionHistory", OpenParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	RefreshIndicators();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	TD = Items.Performance.CurrentData;
	If TD = Undefined Then
		Return;
	EndIf;
	
	Temp = Object.Performance;
	CurrentIndex = Temp.IndexOf(TD);
	
	If Temp.Count() <= 1 OR
		CurrentIndex = 0 OR
		Temp[CurrentIndex - 1].KeyOperation = Object.OverallSystemPerformance OR
		TD.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	ShearDirection = -1;
	ShiftLines(ShearDirection, CurrentIndex);
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	TD = Items.Performance.CurrentData;
	If TD = Undefined Then
		Return;
	EndIf;
	
	Temp = Object.Performance;
	CurrentIndex = Temp.IndexOf(TD);
	
	If Temp.Count() <= 1 Or
		CurrentIndex = Temp.Count() - 1 Or
		Temp[CurrentIndex + 1].KeyOperation = Object.OverallSystemPerformance Or
		TD.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	ShearDirection = 1;
	ShiftLines(ShearDirection, CurrentIndex);
	
EndProcedure

&AtClient
Procedure DataExport(Command)
	NotifyDescription = New NotifyDescription("SelectFileAskedExport", ThisObject);
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
EndProcedure

&AtClient
Procedure Setting(Command)
	
	OpenForm("DataProcessor.PerformanceEstimation.Form.AutomaticExportPerformanceMeasurements", , ThisObject);
	
EndProcedure

&AtClient
Procedure SpecifyAPDEX(Command)
	
	TSRow = Object.Performance.FindByID(Items.Performance.CurrentRow);
	Item = Items.Performance.CurrentItem;
	
	If Left(Item.Name, 18) <> "Performance"
		Or TSRow.KeyOperation = Object.OverallSystemPerformance
		Then
			Return;
	EndIf;
	
	If TSRow[Item.Name] = 0 Then
		ShowMessageBox(,NStr("en = 'There are no performance measurements.
			|Unable to calculate target time.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("SpecifyEndAPDEX", ThisObject);
	ToolTip = NStr("en = 'Enter the desired APDEX value'"); 
	APDEX = 0;
	ShowInputNumber(Notification, APDEX, ToolTip, 3, 2);
	
EndProcedure

&AtClient
Procedure SetFilter(Command)
	
	OpenForm("DataProcessor.PerformanceEstimation.Form.FilterForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure AddKeyOperation(Command)
	OpenChoiceForm();
EndProcedure

&AtClient
Procedure DeleteKeyOperation(Command)
	DeleteKeyOperationOnServer();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Priority.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.Performance.LineNumber");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterElement.RightValue = 0;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TargetTime.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Object.OverallSystemPerformance;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtClient
Procedure SpecifyEndAPDEX(Val APDEX, Val AdditionalParameters) Export
	
	If APDEX = Undefined Then
		Return;
	EndIf;
	
	If 0 > APDEX Or APDEX > 1 Then
		ShowMessageBox(,NStr("en = 'You entered an incorrect APDEX measure.
			|Permitted values from 0 to 1.'"));
		Return;
	EndIf;
	
	APDEX = ?(APDEX = 0, 0.001, APDEX);
	
	TSRow = Object.Performance.FindByID(Items.Performance.CurrentRow);
	Item = Items.Performance.CurrentItem;
	TSRow[Item.Name] = APDEX;
	
	IndexPeriod = Number(Mid(Item.Name, 19));
	TargetTime = CalculateTargetTime(TSRow.KeyOperation, APDEX, IndexPeriod);
	
	TSRow.TargetTime = TargetTime;
	TargetTimeWhenChanging(Item);
EndProcedure

// Procedure calculates performance measures.
//
&AtServer
Procedure RefreshIndicators(FilterValues = Undefined)
	
	If Items.Form.CurrentPage.Name = "PageChart" Then
		UpdateChart = True;
		UpdateTable = False;
	ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
		UpdateTable = True;
		UpdateChart = False;
	EndIf;
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	If Not SetupExecuted() Then
		Return;
	EndIf;
	
	// Receive the total KeyOperationTable that will be output to a user.
	TableOfKeyOperations = DataProcessorObject.PerformanceIndicators();
	If TableOfKeyOperations = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Period is installed incorrectly.'"));
		Return;
	EndIf;
	
	If TableOfKeyOperations.Count() = 0 Then
		Return;
	EndIf;
	
	If FilterValues <> Undefined Then
		SetSelectionTableOfKeyOperations(TableOfKeyOperations, FilterValues);
	EndIf;
	
	If Items.Form.CurrentPage.Name = "PageChart" Then
		
		RefreshChart(TableOfKeyOperations);
		
	ElsIf Items.Form.CurrentPage.Name = "PageTable" Then
		
		HandleDetailsObject(TableOfKeyOperations.Columns);
		Object.Performance.Load(TableOfKeyOperations);
		
	EndIf;
	
EndProcedure

// Calculates the target time for the specified APDEX value.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations, a key operation
//                     for which it is required to calculate target time.
//  APDEX - Number, APDEX for which it is required to pick target time.
//  IndexPeriod - Number, period index for which target time will be calculated.
//
// Returns:
//  Number - target time during which APDEX will be equal to the specified value.
//
&AtServer
Function CalculateTargetTime(KeyOperation, APDEX, IndexPeriod)
	
	TableOfKeyOperations = TableOfKeyOperationsToCalculateAPDEX();
	StringTableKeyOperations = TableOfKeyOperations.Add();
	StringTableKeyOperations.KeyOperation = KeyOperation;
	StringTableKeyOperations.Priority = 1;
	
	ThisDataProcessor = FormAttributeToValue("Object");
	
	StepNumber = 0;
	NumberOfSteps = 0;
	If Not ThisDataProcessor.FrequencyChart(StepNumber, NumberOfSteps) Then
		Return False;
	EndIf;
	
	BeginOfPeriod = Object.StartDate + (StepNumber * IndexPeriod);
	EndOfPeriod = BeginOfPeriod + StepNumber - 1;
	
	CalculationOptions = ThisDataProcessor.StructureForCalculationOfApdexParameters();
	CalculationOptions.StepNumber = StepNumber;
	CalculationOptions.NumberOfSteps = 1;
	CalculationOptions.StartDate = BeginOfPeriod;
	CalculationOptions.EndDate = EndOfPeriod;
	CalculationOptions.DisplayResults = False;
	
	TargetTime = 0.01;
	PreviousSpecificTime = TargetTime;
	StepSeconds = 1;
	While True Do
		
		TableOfKeyOperations[0].TargetTime = TargetTime;
		CalculationOptions.TableOfKeyOperations = TableOfKeyOperations;
		
		TableOfKeyOperationsFor = ThisDataProcessor.CalculateAPDEX(CalculationOptions);
		ValueAPDEXCalculated = TableOfKeyOperationsFor[0][3];
		
		If ValueAPDEXCalculated < APDEX Then
			
			PreviousSpecificTime = TargetTime;
			TargetTime = TargetTime + StepSeconds;
		
		ElsIf ValueAPDEXCalculated > APDEX Then
			
			If StepSeconds = 0.01 Or TargetTime = 0.01 Then
				Break;
			EndIf;
			
			StepSeconds = StepSeconds / 10;
			TargetTime = PreviousSpecificTime + StepSeconds;
		
		ElsIf ValueAPDEXCalculated = APDEX Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	Return TargetTime;
	
EndFunction

// Processes the "Performance" tabular section attributes.
//
// Parameters:
//  SpeakersTableOfKeyOperations - ColumnsCollectionValueTables according to
//                                   which you calculate which attributes to remove.
//
&AtServer
Procedure HandleDetailsObject(SpeakersTableOfKeyOperations)
	
	ObjectAttributes = GetAttributes("Object.Performance");
	AttributesToBeRemoved = AttributesToBeRemoved(ObjectAttributes);
	
	// Columns "Key operation", "Priority" and "Target time".
	NumberOfFixedColumns = 3;
	
	// Columns content is changing
	If AttributesToBeRemoved.Count() <> (SpeakersTableOfKeyOperations.Count() - NumberOfFixedColumns) Then
		
		ChangeContentAttributesObject(SpeakersTableOfKeyOperations, AttributesToBeRemoved);
		
		// Generate field lists for a conditional design.
		FieldSelection = New Array;
		FieldDesign = New Array;
		For Each KeyOperationsTableColumn IN SpeakersTableOfKeyOperations Do
			If SpeakersTableOfKeyOperations.IndexOf(KeyOperationsTableColumn) < NumberOfFixedColumns Then
				Continue;
			EndIf;
			FieldSelection.Add("Object.Performance." + KeyOperationsTableColumn.Name);
			FieldDesign.Add(KeyOperationsTableColumn.Name);
		EndDo;
		
		SetConditionalRegistrationPM(FieldSelection, FieldDesign, ConditionalAppearance, Object.OverallSystemPerformance);
		
	// Only column titles are changing.
	Else
		
		Ct = -1;
		For Each Item IN Items.Performance.ChildItems Do
			Ct = Ct + 1;
			// Skip first 3 items not to change titles of columns "Key operation" "Priority"
			// and "Target time".
			If Ct < NumberOfFixedColumns Then
				Continue;
			EndIf;
			Item.Title = SpeakersTableOfKeyOperations[Ct].Title;
		EndDo;
		
	EndIf;
	
EndProcedure

// Change form attributes: unnecessary ones are removed, necessary ones are added.
//
// Parameters:
//  SpeakersTableOfKeyOperations - ColumnsCollectionValueTables according to
//                                   which you calculate which attributes to remove.
//  AttributesToBeRemoved - Array, full names list
//  	of deleted attributes names as Object.Performance.PerformanceN where N is a number.
//
&AtServer
Procedure ChangeContentAttributesObject(SpeakersTableOfKeyOperations, AttributesToBeRemoved)
	
	// Delete columns from the "Performance" tabular section.
	For AttributeIndex = 0 To AttributesToBeRemoved.Count() - 1 Do
		
		// Deleted object names Object.Performance.PerformanceN
		// where N is a number, this expression receives string of the PerformanceN kind.
		Item = Items.Find(Mid(AttributesToBeRemoved[AttributeIndex], 27));
		If Item <> Undefined Then
			Items.Delete(Item);
		EndIf;
		
	EndDo;
	
	AttributesToAdd = AttributesToAdd(SpeakersTableOfKeyOperations);
	ChangeAttributes(AttributesToAdd, AttributesToBeRemoved);
	
	// Add columns to the "Performance" tabular section.
	ObjectAttributes = GetAttributes("Object.Performance");
	For Each ObjectAttribute IN ObjectAttributes Do
		
		AttributeName = ObjectAttribute.Name;
		If Left(AttributeName, 18) = "Performance" Then
			Item = Items.Add(AttributeName, Type("FormField"), Items.Performance);
			Item.Type = FormFieldType.InputField;
			Item.DataPath = "Object.Performance." + AttributeName;
			Item.Title = ObjectAttribute.Title;
			Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
			Item.Format = "ND=5; NFD=2; NZ=";
			Item.ReadOnly = True;
		EndIf;
		
	EndDo;
	
EndProcedure

// The function creates form attributes array (the "Performance" TS columns) that should be added.
//
// Parameters:
//  SpeakersTableOfKeyOperations - ColumnsCollectionValueTables, columns list which should be created.
//
// Returns:
//  Array - Form attributes array.
//
&AtServerNoContext
Function AttributesToAdd(SpeakersTableOfKeyOperations)
	
	AttributesToAdd = New Array;
	TypeNumber63 = New TypeDescription("Number", New NumberQualifiers(6, 3, AllowedSign.Nonnegative));
	
	For Each KeyOperationsTableColumn IN SpeakersTableOfKeyOperations Do
		
		If SpeakersTableOfKeyOperations.IndexOf(KeyOperationsTableColumn) < 3 Then
			Continue;
		EndIf;
		
		NewFormAttribute = New FormAttribute(KeyOperationsTableColumn.Name, TypeNumber63, "Object.Performance", KeyOperationsTableColumn.Title);
		AttributesToAdd.Add(NewFormAttribute);
		
	EndDo;
	
	Return AttributesToAdd;
	
EndFunction

// The function creates form attributes array (the "Performance" TS
// columns) that should be deleted and deletes form items connected to the attributes.
//
// Returns:
//  Array - Form attributes array.
//
&AtServerNoContext
Function AttributesToBeRemoved(ObjectAttributes)
	
	AttributesToBeRemoved = New Array;
	
	AttributeIndex = 0;
	While AttributeIndex < ObjectAttributes.Count() Do
		
		AttributeName = ObjectAttributes[AttributeIndex].Name;
		If Left(AttributeName, 18) = "Performance" Then
			AttributesToBeRemoved.Add("Object.Performance." + AttributeName);
		EndIf;
		AttributeIndex = AttributeIndex + 1;
		
	EndDo;
	
	Return AttributesToBeRemoved;
	
EndFunction

// The procedure sets a conditional "Performance" TS design.
//
&AtServerNoContext
Procedure SetConditionalRegistrationPM(FieldSelection, FieldDesign, ConditionalAppearance, OverallSystemPerformance);
	
	ConditionalAppearance.Items.Clear();
	
	// Clear priority in the SystemGeneralPerformance key operation.
	DesignElement = ConditionalAppearance.Items.Add();
	// Design kind
	DesignElement.Appearance.SetParameterValue("Text", "");
	// Condition for the design
	FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	// Made out field
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("Priority");
	
	// Only view the Priority column.
	DesignElement = ConditionalAppearance.Items.Add();
	// Design kind
	DesignElement.Appearance.SetParameterValue("ReadOnly", True);
	// Condition for the design
	FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.LineNumber");
	FilterItem.RightValue = 0;
	// Made out field
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("Priority");
	
	// Only view the target time in the SystemGeneralPerformance key operation.
	DesignElement = ConditionalAppearance.Items.Add();
	// Design kind
	DesignElement.Appearance.SetParameterValue("ReadOnly", True);
	// Condition for the design
	FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	// Made out field
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TargetTime");
	
	// Unfilled target time mark in all except for GeneralSystemPerformance.
	DesignElement = ConditionalAppearance.Items.Add();
	// Design kind
	DesignElement.Appearance.SetParameterValue("MarkIncomplete", True);
	// Condition for the design
	FilterGroup = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	//
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.KeyOperation");
	FilterItem.RightValue = OverallSystemPerformance;
	//
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.LeftValue = New DataCompositionField("Object.Performance.TargetTime");
	FilterItem.RightValue = 0;
	// Made out field
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TargetTime");
	
	FieldsCount = FieldSelection.Count() - 1;
	
	// Design if operation is not executed.
	For FieldIndex = 0 To FieldsCount Do
		
		DesignElement = ConditionalAppearance.Items.Add();
		
		// Design kind
		DesignElement.Appearance.SetParameterValue("Text", " ");
		// Condition for the design
		FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.LeftValue = New DataCompositionField(FieldSelection[FieldIndex]);
		FilterItem.RightValue = 0;
		// Made out field
		AppearanceField = DesignElement.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField(FieldDesign[FieldIndex]);
		
	EndDo;
	
	// Design for performance measures.
	Map = ColorsToApdexLevelMatch();
	For Each KeyValue IN Map Do
	
		For FieldIndex = 0 To FieldsCount Do
			
			DesignElement = ConditionalAppearance.Items.Add();
			
			// Design kind
			DesignElement.Appearance.SetParameterValue("BackColor", KeyValue.Value.Color);
			// Condition for the design
			FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
			FilterItem.LeftValue = New DataCompositionField(FieldSelection[FieldIndex]);
			FilterItem.RightValue = KeyValue.Value.from;
			// Condition for the design
			FilterItem = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.ComparisonType = DataCompositionComparisonType.Less;
			FilterItem.LeftValue = New DataCompositionField(FieldSelection[FieldIndex]);
			FilterItem.RightValue = KeyValue.Value.Before;
			// Made out field
			AppearanceField = DesignElement.Fields.Items.Add();
			AppearanceField.Field = New DataCompositionField(FieldDesign[FieldIndex]);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Updates chart.
//
// Parameters:
//  TableOfKeyOperations - ValuesTable, data according to which chart will be updated.
//
&AtServer
Procedure RefreshChart(TableOfKeyOperations)
	
	Chart = Object.Chart;
	
	Chart.Update = False;
	
	Chart.AutoMaxValue	= False;
	Chart.AutoMinValue	= False;
	Chart.MaxValue		= 1;
	Chart.MinValue		= 0;
	Chart.BaseValue			= 0;
	Chart.HideBaseValue	= True;
	
	Chart.Clear();
	
	HeaderText = NStr("en = 'Performance chart from %1 to %2 - step: %3'");
	HeaderText = StrReplace(HeaderText, "%1", Format(Object.StartDate, "DF=dd.MM.yyyy"));
	HeaderText = StrReplace(HeaderText, "%2", Format(Object.EndDate, "DF=dd.MM.yyyy"));
	HeaderText = StrReplace(HeaderText, "%3", String(Object.Step));
	Items.Chart.Title = HeaderText;
	
	TableOfKeyOperations.Columns.Delete(1); // Priority
	TableOfKeyOperations.Columns.Delete(1); // TargetTime
	
	For Each StringTableKeyOperations IN TableOfKeyOperations Do
		
		Series = Chart.Series.Add(StringTableKeyOperations.KeyOperation);
		Series.Text = StringTableKeyOperations.KeyOperation;
		
	EndDo;
	
	TableOfKeyOperations.Columns.Delete(0); // KeyOperation
	
	For Each KeyOperationsTableColumn IN TableOfKeyOperations.Columns Do
		
		Point = Chart.Points.Add(KeyOperationsTableColumn.Name);
		// To display only hours if the step is Hour.
		Point.Text = ?(Object.Step = "Hour", Left(KeyOperationsTableColumn.Title, 2), KeyOperationsTableColumn.Title);
		String = 0;
		Column = TableOfKeyOperations.Columns.IndexOf(KeyOperationsTableColumn);
		For Each Series IN Chart.Series Do
			
			DotValue = TableOfKeyOperations[String][Column];
			If DotValue <> Undefined AND DotValue <> Null Then
				Chart.SetValue(Point, Series, ?(DotValue = 0.001 OR DotValue = 0, DotValue, DotValue - 0.001));
			EndIf;	
			String = String + 1;
			
		EndDo;
		
	EndDo;
	
	Chart.ChartType = ChartType.Line;
	
	Chart.Update = True;
	
EndProcedure

&AtClient
Function ToPrepareExportOptions()
	
	KeyOperations = New Array;
	
	GeneralPerformance = Object.OverallSystemPerformance;
	For Each StringTableKeyOperations IN Object.Performance Do
		
		If StringTableKeyOperations.KeyOperation = GeneralPerformance Then
			Continue;
		EndIf;
		
		KeyOperations.Add(StringTableKeyOperations.KeyOperation);
		
	EndDo;
	
	ExportOptions = New Structure("StartDate, EndDate, Step, KeyOperationsArray");
	ExportOptions.StartDate	= Object.StartDate;
	ExportOptions.EndDate	= Object.EndDate;
	ExportOptions.Step			= String(Object.Step);
	ExportOptions.AnArrayOfKeyOperations		= KeyOperations;
	
	Return ExportOptions;
	
EndFunction

// Export measurements data on the specified interval.
//
&AtServerNoContext
Procedure ToExport(AddressInStorage, ExportOptions)
	
	TemporaryDirectory = TempFilesDir() + String(New UUID);
	FileName = TemporaryDirectory + "/exp.zip";
	FileNameDescription = TemporaryDirectory + "/Description.xml";
	NameOfSettingsFile = TemporaryDirectory + "/Settings.xml";
	CreateDirectory(TemporaryDirectory);
	
	WriteZip	= New ZipFileWriter(FileName);
	Begin		= ExportOptions.StartDate;
	End		= ExportOptions.EndDate;
	AnArrayOfKeyOperations	= ExportOptions.AnArrayOfKeyOperations;
	
	IntervalBegin = Begin;
	IntervalEnd = End;
	
	WidthIntervalPackage = 3600 - 1;
	PackagesCount = (End - Begin) / WidthIntervalPackage;
	PackagesCount = Int(PackagesCount) + ?(PackagesCount - Int(PackagesCount) > 0, 1, 0);
	
	While IntervalBegin < End Do
		IntervalEnd = IntervalBegin + WidthIntervalPackage;
		
		If IntervalEnd > End Then
			IntervalEnd = End;
		EndIf;
		
		TempFileName = TemporaryDirectory + "/" + FileNameByTime(IntervalBegin) + ".1capd";
		If ExportInterval(TempFileName, IntervalBegin, IntervalEnd, AnArrayOfKeyOperations) Then
			WriteZip.Add(TempFileName);
		EndIf;
		
		IntervalBegin = IntervalEnd + 1;
		
	EndDo;
	
	FillDetails(FileNameDescription, Begin, End, AnArrayOfKeyOperations);
	WriteZip.Add(FileNameDescription);
	
	FillSettings(NameOfSettingsFile, Begin, End, ExportOptions.Step, AnArrayOfKeyOperations);
	WriteZip.Add(NameOfSettingsFile);
	
	WriteZip.Write();
	
	BinaryData = New BinaryData(FileName);
	PutToTempStorage(BinaryData, AddressInStorage);
	
	DeleteFilesAtServer(TemporaryDirectory);
	
EndProcedure

// Export infobase measurements data on the specified interval.
//
// Parameters:
//  TempFileName - String, attachment file name for data writing.
//  Begin - DateTime, search interval start.
//  End - DateTime, search interval end.
//  AnArrayOfKeyOperations - Array, key operations array which data must be exported.
//
&AtServerNoContext
Function ExportInterval(TempFileName, Begin, End, AnArrayOfKeyOperations)
	
	SetOfMeasurements = SetOfTimeMeasurements(Begin, End, AnArrayOfKeyOperations);
	
	If Not ValueIsFilled(SetOfMeasurements) Then
		Return False;
	EndIf;
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFileName);
	
	XMLWriter.WriteXMLDeclaration();
	WriteXML(XMLWriter, SetOfMeasurements);
	Return True;
EndFunction

// Receive register records set.
//
// Parameters:
//  Begin - DateTime, search interval start.
//  End - DateTime, search interval end.
//  AnArrayOfKeyOperations - Array, exported key operations.
//
// Returns:
//  InformationRegister.TimeMeasurements.RecordSet
//
&AtServerNoContext
Function SetOfTimeMeasurements(Begin, End, AnArrayOfKeyOperations)
	
	RegisterMetadata = Metadata.InformationRegisters.TimeMeasurements;
	
	QueryText = 
	"SELECT";
	For Each Dimension IN RegisterMetadata.Dimensions Do
		QueryText = QueryText + "
			|	Measurements." + Dimension.Name + " AS " + Dimension.Name + ",";
	EndDo;
	For Each Resource IN RegisterMetadata.Resources Do
		QueryText = QueryText + "
			|	Measurements." + Resource.Name + " AS " + Resource.Name + ",";
	EndDo;
	For Each Attribute IN RegisterMetadata.Attributes Do
		QueryText = QueryText + "
			|	Measurements." + Attribute.Name + " AS " + Attribute.Name + ",";
	EndDo;
	
	// Clear the last comma
	QueryText = Left(QueryText, StrLen(QueryText) - 1);
	
	QueryText = QueryText + "
		|IN
		|	" + RegisterMetadata.FullName() + " AS
		|Measurements
		|WHERE Measurements.MeasurementStartDate BETWEEN
		|	&StartDate And &EndDate And Measurements.KeyOperation IN(&KeyOperationsArray)";
	
	Query = New Query;
	Query.SetParameter("StartDate", Begin);
	Query.SetParameter("EndDate", End);
	Query.SetParameter("AnArrayOfKeyOperations", AnArrayOfKeyOperations);
	Query.Text = QueryText;
	Result = Query.Execute();
	
	RecordSet = InformationRegisters[RegisterMetadata.Name].CreateRecordSet();
	If Result.IsEmpty() Then
		Return RecordSet;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		Record = RecordSet.Add();
		For Each Dimension IN RegisterMetadata.Dimensions Do
			Record[Dimension.Name] = Selection[Dimension.Name];
		EndDo;
		For Each Resource IN RegisterMetadata.Resources Do
			Record[Resource.Name] = Selection[Resource.Name];
		EndDo;
		For Each Attribute IN RegisterMetadata.Attributes Do
			Record[Attribute.Name] = Selection[Attribute.Name];
		EndDo;
		
	EndDo;
	
	Return RecordSet;
	
EndFunction

// Fill in export description file.
//
// Parameters:
//  FileNameDescription - String, attachment file name for description placing.
//  Begin - Date and time, export period start.
//  End - Date and time, export period end.
//
&AtServerNoContext
Procedure FillDetails(FileNameDescription, Begin, End, AnArrayOfKeyOperations)
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileNameDescription);
	
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("CommonSettings");
	
	XMLWriter.WriteAttribute("Version", "1.0.0.3");
	XMLWriter.WriteAttribute("BeginDate", String(Begin));
	XMLWriter.WriteAttribute("EndDate", String(End));
	XMLWriter.WriteAttribute("ExportDate", String(CurrentDate()));
	
	For OperationIndex = 0 To AnArrayOfKeyOperations.Count() - 1 Do
		XMLWriter.WriteStartElement("KeyOperation");
		XMLWriter.WriteAttribute("name", String(AnArrayOfKeyOperations[OperationIndex]));
		XMLWriter.WriteEndElement();
	EndDo;
	
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
EndProcedure

// Fills in settings file
//
&AtServerNoContext
Procedure FillSettings(NameOfSettingsFile, Begin, End, Step, AnArrayOfKeyOperations)
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(NameOfSettingsFile);
	
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("CommonSettings");
	
	XMLWriter.WriteAttribute("BeginDate", String(Begin));
	XMLWriter.WriteAttribute("EndDate", String(End));
	XMLWriter.WriteAttribute("Step", Step);
	
	XMLWriter.WriteStartElement("TableSettings");
	XMLWriter.WriteAttribute("RowCount", Format(AnArrayOfKeyOperations.Count(), "NG=0"));
	
	For Ct = 0 To AnArrayOfKeyOperations.Count() - 1 Do
		WriteXML(XMLWriter, AnArrayOfKeyOperations[Ct].GetObject());
	EndDo;
	
	XMLWriter.WriteEndElement();
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
EndProcedure

///////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

// Shifts tabular section strings and changes key operation priorities.
//
// Parameters:
//  ShearDirection - Number,
//  	-1, shift
//  	upwards 1, shift
//  downwards CurrentIndex - Number, shifted string index.
//
&AtClient
Procedure ShiftLines(ShearDirection, CurrentIndex)
	
	Temp = Object.Performance;
	
	Priority1 = Temp[CurrentIndex].Priority;
	Priority2 = Temp[CurrentIndex + ShearDirection].Priority;
	
	ChangePriorities(
		Temp[CurrentIndex].KeyOperation,
		Priority1,
		Temp[CurrentIndex + ShearDirection].KeyOperation, 
		Priority2);
		
	Temp[CurrentIndex].Priority = Priority2;
	Temp[CurrentIndex + ShearDirection].Priority = Priority1;
	
	Temp.Move(CurrentIndex, ShearDirection);
	
EndProcedure

// Sets an exclusive managed lock to the reference.
//
&AtServerNoContext
Procedure BlockRef(Ref)
	
	DataLock = New DataLock;
	LockItem = DataLock.Add(Ref.Metadata().FullName());
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Ref", Ref);
	DataLock.Lock();
	
EndProcedure

// Starts a transaction and sets an exclusive managed lock by the reference value.
//
// Parameters:
//  Ref - AnyRef, reference which should be locked.
//
// Returns:
//  Object - object received from the reference.
//
&AtServerNoContext
Function ToModifyObject(Ref)
	
	BeginTransaction();
	
	BlockRef(Ref);
	
	Object = Ref.GetObject();
	
	Return Object;
	
EndFunction

// Writes the transaction and the object.
//
// Parameters:
//  Object - AnyObject, object changes of which should be fixed.
//  Write - Boolean, requirement to write an object before writing the transaction.
//
&AtServerNoContext
Procedure CommitChangeOnObject(Object, Write = True)
	
	If Write Then
		Object.Write();
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// Exchanges key operation priorities exchange.
//
// Parameters:
//  KeyOperation1 - CatalogRef.KeyOperations
//  Priority1 - Number, KeyOperation2 will be assigned.
//  AKeyActivity2 - CatalogRef.KeyOperations
//  Priority2 - Number, KeyOperation1 will be assigned.
//
&AtServer
Procedure ChangePriorities(KeyOperation1, Priority1, AKeyActivity2, Priority2)
	
	BeginTransaction();
	
	AKeyOperation = ToModifyObject(KeyOperation1);
	AKeyOperation.Priority = Priority2;
	AKeyOperation.AdditionalProperties.Insert(PerformanceEstimationClientServer.DontCheckPriority());
	CommitChangeOnObject(AKeyOperation);
	
	AKeyOperation = ToModifyObject(AKeyActivity2);
	AKeyOperation.Priority = Priority1;
	CommitChangeOnObject(AKeyOperation);
	
	CommitTransaction();
	
EndProcedure

// Procedure opens the KeyOperations catalog
// selection form and sets filter for the list not to contain operations that are already selected.
//
&AtClient
Procedure OpenChoiceForm()
	
	CWT = Object.Performance;
	
	Filter = New Array;
	For CurIndex = 0 To CWT.Count() - 1 Do
		Filter.Add(CWT[CurIndex].KeyOperation);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("ChoiceMode", True);
	
	Notification = New NotifyDescription(
		"AddKeyOperationEnd",
		ThisObject
	);
	OpenForm(
		"Catalog.KeyOperations.ChoiceForm", 
		FormParameters, 
		ThisObject,
		,,,
		Notification, FormWindowOpeningMode.LockWholeInterface
	);
	
EndProcedure

&AtClient
Procedure AddKeyOperationEnd(KeyOperationParameters, Parameters) Export
	
	If KeyOperationParameters = Undefined Then
		Return;
	EndIf;
	AddKeyOperationServer(KeyOperationParameters);
	
EndProcedure

&AtServer
Function AddKeyOperationServer(KeyOperationParameters)
	
	NewRow = Object.Performance.Add();
	NewRow.KeyOperation = KeyOperationParameters.KeyOperation;
	NewRow.TargetTime = KeyOperationParameters.TargetTime;
	NewRow.Priority = KeyOperationParameters.Priority;
	
	Object.Performance.Sort("Priority");
	
EndFunction

// The function selects attachment file name by the specified time.
//
//
// Parameters:
//  Time - DateTime
//
// Returns:
//  String - File name
//
&AtServerNoContext
Function FileNameByTime(Time)
	
	Return Format(Time, "DF=""yyyy-MM-dd HH-mm-cc""");
	
EndFunction

// Procedure deletes catalog on server.
//
&AtServerNoContext
Procedure DeleteFilesAtServer(Directory)
	DeleteFiles(Directory);
EndProcedure

// Calculates the exact start and end date in the selected interval.
//
// Parameters:
//  StartDate [OUT] - Date, selected period start date.
//  EndDate [OUT] - Date, selected period end date.
//  PeriodIndex [IN] - Number, selected period index.
//
// Returns:
//  Boolean - 
//  	True, dates
//  	are calculated False, dates are not calculated
//
&AtServer
Function CalculateDateTimeSegment(StartDate, EndDate, IndexPeriod)
	
	ThisDataProcessor = FormAttributeToValue("Object");
	
	StepNumber = 0;
	NumberOfSteps = 0;
	If Not ThisDataProcessor.FrequencyChart(StepNumber, NumberOfSteps) Then
		Return False;
	EndIf;
	
	If NumberOfSteps <= IndexPeriod Then
		Raise NStr("en = 'Number of steps can not be less than index.'");
	EndIf;
	
	StartDate = Object.StartDate + (StepNumber * IndexPeriod);
	
	If StepNumber <> 0 Then
		EndDate = StartDate + StepNumber - 1;
	Else
		EndDate = EndOfDay(Object.EndDate);
	EndIf;
	
	Return True;
	
EndFunction

// Creates the value table which is required to calculate APDEX.
//
// Returns:
//  ValueTable - values table with structure required to calculate APDEX.
//
&AtServerNoContext
Function TableOfKeyOperationsToCalculateAPDEX()
	
	TableOfKeyOperations = New ValueTable;
	TableOfKeyOperations.Columns.Add(
		"KeyOperation", 
		New TypeDescription("CatalogRef.KeyOperations"));
	TableOfKeyOperations.Columns.Add(
		"Priority", 
		New TypeDescription("Number", New NumberQualifiers(15, 0, AllowedSign.Nonnegative)));
	TableOfKeyOperations.Columns.Add(
		"TargetTime",
		New TypeDescription("Number", New NumberQualifiers(15, 2, AllowedSign.Nonnegative)));
	
	Return TableOfKeyOperations;
	
EndFunction

///////////////////////////////////////////////////////////////////////
// HELPER PROCEDURES AND FUNCTIONS (DESIGN, SETTINGS)

// Function returns value color Unacceptable.
//
// Returns:
//  Color - value color
//
&AtServerNoContext
Function ColorUnacceptable()
	
	Return New Color(187, 187, 187);
	
EndFunction

// Function returns value color Bad.
//
// Returns:
//  Color - value color
//
&AtServerNoContext
Function ColorBad()
	
	Return New Color(255, 212, 171);
	
EndFunction

// Function returns value color Satisfactory.
//
// Returns:
//  Color - value color
//
&AtServerNoContext
Function SatisfactoryColor()
	
	Return New Color(255, 255, 153);
	
EndFunction

// Function returns value color Good.
//
// Returns:
//  Color - value color
//
&AtServerNoContext
Function ColorGood()
	
	Return New Color(204, 255, 204);
	
EndFunction

// Function returns value color Excellent.
//
// Returns:
//  Color - value color
//
&AtServerNoContext
Function ColorExcellent()
	
	Return New Color(204, 255, 255);
	
EndFunction

// Function returns match in which.
// Key - String, performance review.
// Value - Structure, review parameters.
//
// Returns:
//  Map
//
&AtServerNoContext
Function ColorsToApdexLevelMatch()
	
	Map = New Map;
	
	Values = New Structure("From, Before, Color");
	Values.from = 0.001; // Means that the operation was not executed at all.
	Values.Before = 0.5;
	Values.Color = ColorUnacceptable();
	Map.Insert("Unacceptable", Values);
	
	Values = New Structure("From, Before, Color");
	Values.from = 0.5;
	Values.Before = 0.7;
	Values.Color = ColorBad();
	Map.Insert("Bad", Values);
	
	Values = New Structure("From, Before, Color");
	Values.from = 0.7;
	Values.Before = 0.85;
	Values.Color = SatisfactoryColor();
	Map.Insert("Satisfactorily", Values);
	
	Values = New Structure("From, Before, Color");
	Values.from = 0.85;
	Values.Before = 0.94;
	Values.Color = ColorGood();
	Map.Insert("Good", Values);
	
	Values = New Structure("From, Before, Color");
	Values.from = 0.94;
	Values.Before = 1.002; // T.k. in the conditional design, "Less" condition is applied to "Before" value not "LessOrEqual".
	Values.Color = ColorExcellent();
	Map.Insert("Excellent", Values);
	
	Return Map;
	
EndFunction

// Function checks whether form settings are correct.
//
// Returns:
//  True - settings
//  are correct False - Settings are incorrect
//
&AtServer
Function SetupExecuted()
	
	Executed = True;
	For Each TSRow IN Object.Performance Do
		
		If TSRow.TargetTime = 0 
			AND TSRow.KeyOperation <> Object.OverallSystemPerformance
		Then
		
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Target time must be obligatory filled in.'"),
				,
				"Performance[" + Object.Performance.IndexOf(TSRow) + "].TargetTime",
				"Object");
			
			Executed = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return Executed;
	
EndFunction

// Procedure fills in during the first data processor form opening.
// "Performance" TS from the "KeyOperations" catalog.
//
&AtServerNoContext
Function ExportKeyOperations(OverallSystemPerformance)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	KeyOperations.Ref AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	Not KeyOperations.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	&OverallSystemPerformance,
	|	0,
	|	0
	|WHERE
	|	VALUETYPE(&OverallSystemPerformance) <> Type(Catalog.KeyOperations)
	|
	|ORDER BY
	|	Priority
	|AUTOORDER";
	Query.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return New ValueTable;
	EndIf;
	
	Return Result.Unload();
	
EndFunction

// Changes the key operation target time.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations, operation in which it is required to change target time.
//  TargetTime - Number, new target time.
//
&AtServer
Procedure ChangeTargetTime(KeyOperation, TargetTime)
	
	KeyObjectOperation = ToModifyObject(KeyOperation);
	KeyObjectOperation.TargetTime = TargetTime;
	CommitChangeOnObject(KeyObjectOperation);
	
EndProcedure

// Deletes strings that do not fit the filter from the values table.
//
// Parameters:
//  TableOfKeyOperations - ValuesTable, table that should be filtered.
//  FilterValues - Array, strings table with the filter values.
//
&AtServerNoContext
Procedure SetSelectionTableOfKeyOperations(TableOfKeyOperations, FilterValues)
	
	If FilterValues.Direction > 0 Then
		If Upper(FilterValues.State) = "Good" Then
			Limit = 0.93;
		ElsIf Upper(FilterValues.State) = "Satisfactorily" Then
			Limit = 0.84;
		ElsIf Upper(FilterValues.State) = "Bad" Then
			Limit = 0.69;
		EndIf;
	ElsIf FilterValues.Direction < 0 Then
		If Upper(FilterValues.State) = "Good" Then
			Limit = 0.85;
		ElsIf Upper(FilterValues.State) = "Satisfactorily" Then
			Limit = 0.7;
		ElsIf Upper(FilterValues.State) = "Bad" Then
			Limit = 0.5;
		EndIf;
	EndIf;
	
	Ct = 0;
	Delete = False;
	While Ct < TableOfKeyOperations.Count() Do
		
		For Each KeyOperationsTableColumn IN TableOfKeyOperations.Columns Do
			If (Left(KeyOperationsTableColumn.Name, 18) <> "Performance") Or (TableOfKeyOperations[Ct][KeyOperationsTableColumn.Name] = 0) Then
				Continue;
			EndIf;
			
			If FilterValues.Direction > 0 Then
				If TableOfKeyOperations[Ct][KeyOperationsTableColumn.Name] > Limit Then
					Delete = False;
					Break;
				Else
					Delete = True;
				EndIf;
			ElsIf FilterValues.Direction < 0 Then
				If TableOfKeyOperations[Ct][KeyOperationsTableColumn.Name] < Limit Then
					Delete = False;
					Break;
				Else
					Delete = True;
				EndIf;
			EndIf;
		EndDo;
		
		If Delete Then
			TableOfKeyOperations.Delete(Ct);
		Else
			Ct = Ct + 1;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectFileAskedExport(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	ExportOptions = ToPrepareExportOptions();
	AddressInStorage = PutToTempStorage("", ThisObject.UUID);
	Status(NStr("en = 'Data export...'"));
	ToExport(AddressInStorage, ExportOptions);
	
	GetFile(AddressInStorage, "perf.zip");
	
EndProcedure

&AtServer
Procedure DeleteKeyOperationOnServer()
	
	RowID = Items.Performance.CurrentRow;
	If RowID = Undefined Then
		Return;
	EndIf;
	
	PerformanceDynamicsData = Object.Performance;
	ActiveString = PerformanceDynamicsData.FindByID(RowID);
	If ActiveString <> Undefined Then
		PerformanceDynamicsData.Delete(PerformanceDynamicsData.IndexOf(ActiveString));
	EndIf;
	
EndProcedure

#EndRegion
