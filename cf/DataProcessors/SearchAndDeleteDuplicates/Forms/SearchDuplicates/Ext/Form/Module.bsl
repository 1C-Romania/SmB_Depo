#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetColorAndConditionalDesign();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InitializeMainParameters();
	
	InitializeSelectionAndRulesLinker();
	// Schema should always be regenerated, linker settings -  in the DuplicatesSearchArea profile. 
	
	// Permanent interface
	StatePresentation = Items.SearchWasNotRun.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("en='Duplicates search is not in progress. 
		|Set filter and comparison criteria and click Find duplicates.';ru='Поиск дублей не выполнялся. 
		|Задайте условия отбора и сравнения и нажмите ""Найти дубли"".'");
	StatePresentation.Picture = Items.Warning32.Picture;
	
	StatePresentation = Items.SearchExecution.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("en='Searching for duplicates...';ru='Поиск дублей...'");
	StatePresentation.Picture = Items.LongOperation48.Picture;
	
	StatePresentation = Items.DeleteExecution.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("en='Deleting duplicates ...';ru='Удаление дублей...'");
	StatePresentation.Picture = Items.LongOperation48.Picture;
	
	StatePresentation = Items.DuplicatesAreNotFound.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.Text = NStr("en='Duplicates by specified parameters are not found.
		|Change filter and comparison criteria, click Find duplicates';ru='Не обнаружено дублей по указанным параметрам.
		|Измените условия отбора и сравнения, нажмите ""Найти дубли""'");
	StatePresentation.Picture = Items.Warning32.Picture;
	
	// Stepped assistant
	StepByStepAssistantSettings = InitializeMaster(Items.AssistantSteps, Items.Next, Items.Back, Items.Cancel);
	
	// Add steps depending on the form logic.
	InitializeAssistantScript();
	
	// Settings auto save
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Control settings correctness.
	UpdateDuplicatesAreasSettings(DuplicateSearchArea);
	
	// Specify an initial page.
	SetAssistantInitialPage(Items.StepSearchWasNotRun);
	RunAssistant();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If StepByStepAssistantSettings.JobCompleted = False
		AND StepByStepAssistantSettings.BackgroundJobID <> Undefined
		AND StepByStepAssistantSettings.HasJobCancellationConfirmation = False Then
		Cancel = True;
		BackgroundJobImportOnClient(False, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	If StepByStepAssistantSettings.JobCompleted = False
		AND StepByStepAssistantSettings.BackgroundJobID <> Undefined Then
		BackgroundJobCancel();
	EndIf;
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	SourceFormName = Mid(ChoiceSource.FormName, StrLen(BasicFormName) + 1);
	If SourceFormName = "FilterRule" Then
		UpdateFilterLinker(ValueSelected);
		UpdateFilterDescription();
		
		GoToAssistantStep(Items.StepSearchWasNotRun, True);
		
	ElsIf SourceFormName = "DuplicateSearchArea" Then
		UpdateDuplicatesAreasSettings(ValueSelected);
		
		GoToAssistantStep(Items.StepSearchWasNotRun, True);
		
	ElsIf SourceFormName = "SearchRules" Then
		UpdateSearchRules(ValueSelected);
		UpdateSearchRulesDescription();
		
		GoToAssistantStep(Items.StepSearchWasNotRun, True);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	// Make sure the duplicates area is correct according to the list.
	SettingKey = "DuplicateSearchArea";
	If DuplicateSearchAreas.FindByValue( Settings[SettingKey] ) = Undefined Then
		Settings.Delete(SettingKey);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PresentationSearchAreasSelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("DuplicateSearchArea", DuplicateSearchArea);
	
	OpenForm(BasicFormName + "DuplicateSearchArea", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure PresentationDuplicateSearchAreasClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure AllUsagePlacesRawClick(Item)
	
	ReportParameters = UsagePlacesReportAnalysis(RawDuplicates);
	OpenForm("Report.RefsUsagePlaces.Form", ReportParameters);
	
EndProcedure

&AtClient
Procedure AllUsagePlacesClick(Item)
	
	ReportParameters = UsagePlacesReportAnalysis(FoundDuplicates);
	OpenForm("Report.RefsUsagePlaces.Form", ReportParameters);
	
EndProcedure

&AtClient
Procedure FilterRulesClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("SchemaURLComposition",            SchemaURLComposition);
	FormParameters.Insert("SelectionLinkerSettingsAddress", SelectionLinkerSettingsAddress());
	FormParameters.Insert("IdentifierBasicForm",      UUID);
	FormParameters.Insert("SelectionAreaPresentation",
		Items.PresentationDuplicateSearchAreas.ChoiceList[0].Presentation);
	
	OpenForm(BasicFormName + "FilterRule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SearchRulesClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("DuplicateSearchArea",        DuplicateSearchArea);
	FormParameters.Insert("AppliedRulesDescription",   AppliedRulesDescription);
	FormParameters.Insert("SettingsAddress",              SearchRulesSettingsAddress() );
	FormParameters.Insert("SelectionAreaPresentation", 
		Items.PresentationDuplicateSearchAreas.ChoiceList[0].Presentation);
		
	OpenForm(BasicFormName + "SearchRules", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region FoundDuplicatesTableEventsHandlers

&AtClient
Procedure FoundDuplicatesOnActivateRow(Item)
	
	AttachIdleHandler("DuplicatesRowsActivationPendingHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure DuplicatesRowsActivationPendingHandler()
	
	RowData = Items.FoundDuplicates.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	UpdateCandidateUsagePlaces( RowData.GetID() );
EndProcedure

&AtServer
Procedure UpdateCandidateUsagePlaces(Val DataRow)
	RowData = FoundDuplicates.FindByID(DataRow);
	
	If RowData.GetParent() = Undefined Then
		// Group details
		CandidateUsagePlaces.Clear();
		
		OriginalName = Undefined;
		For Each Candidate In RowData.GetItems() Do
			If Candidate.Default Then
				OriginalName = Candidate.Description;
				Break;
			EndIf;
		EndDo;
		
		Items.CurrentDuplicateGroupDescription.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='For the %1 item duplicates (%2) are found';ru='Для элемента ""%1"" найдены дубли (%2)'"),
			OriginalName, RowData.Quantity);
		
		Items.UsagePlacesPages.CurrentPage = Items.GroupDetails;
		Return;
	EndIf;
	
	// Usage places listing.
	UsageTable = GetFromTempStorage(UsePlaceAddress);
	Filter = New Structure("Ref", RowData.Ref);
	
	CandidateUsagePlaces.Load(
		UsageTable.Copy( UsageTable.FindRows(Filter) )
	);
	
	If RowData.Quantity = 0 Then
		Items.CurrentDuplicateGroupDescription.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 item is not used';ru='Элемент ""%1"" не используется'"), 
			RowData.Description);
		
		Items.UsagePlacesPages.CurrentPage = Items.GroupDetails;
	Else
		Items.CandidateUsagePlaces.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 usage places (%2)';ru='Места использования ""%1"" (%2)'"), 
			RowData.Description, RowData.Quantity);
		
		Items.UsagePlacesPages.CurrentPage = Items.UsagePlaces;
	EndIf;
	
EndProcedure

&AtClient
Procedure FoundDuplicatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenDuplicateForm(Item.CurrentData);
	
EndProcedure

&AtClient
Procedure FoundDuplicatesMarkOnChange(Item)
	RowData = Items.FoundDuplicates.CurrentData;
	
	RowData.Check = RowData.Check % 2;
	
	ChangeCandidatesMarksierarchically(RowData);
EndProcedure

#EndRegion

#Region UnprocessedDuplicatesTableEventsHandlers

&AtClient
Procedure RawDuplicatesOnActivateRow(Item)
	
	AttachIdleHandler("UnprocessedDuplicatesActivationRowPendingHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UnprocessedDuplicatesActivationRowPendingHandler()
	
	RowData = Items.RawDuplicates.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	UpdateUnprocessedDuplicatesUsagePlaces( RowData.GetID() );
EndProcedure

&AtServer
Procedure UpdateUnprocessedDuplicatesUsagePlaces(Val DataRow)
	RowData = RawDuplicates.FindByID(DataRow);
	
	If RowData.GetParent() = Undefined Then
		// Group details
		UsagePlacesRaw.Clear();
		
		OriginalName = Undefined;
		For Each Candidate In RowData.GetItems() Do
			If Candidate.Default Then
				OriginalName = Candidate.Description;
				Break;
			EndIf;
		EndDo;
		
		Items.CurrentDuplicateGroupDescription1.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='For the %1 item duplicates (%2) are found';ru='Для элемента ""%1"" найдены дубли (%2)'"),
			OriginalName, RowData.Quantity);
		
		Items.UsagePlacesPagesRaw.CurrentPage = Items.GroupDetailsRaw;
		Return;
	EndIf;
	
	// Errors places listing
	ErrorsTable = GetFromTempStorage(ResultAddressReplacement);
	Filter = New Structure("Ref", RowData.Ref);
	
	Data = ErrorsTable.Copy( ErrorsTable.FindRows(Filter) );
	Data.Columns.Add("Icon");
	Data.FillValues(True, "Icon");
	UsagePlacesRaw.Load(Data);
	
	If RowData.Quantity = 0 Then
		Items.CurrentDuplicateGroupDescription1.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 item was successfully processed';ru='Элемент ""%1"" успешно обработан'"), 
			RowData.Description);
		
		Items.UsagePlacesPagesRaw.CurrentPage = Items.GroupDetailsRaw;
	Else
		Items.CandidateUsagePlaces.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unable to substitute duplicates in some places (%1)';ru='Не удалось заменить дубли в некоторых местах (%1)'"), 
			RowData.Quantity);
		
		Items.UsagePlacesPagesRaw.CurrentPage = Items.UsagePlaceDescriptionRaw;
	EndIf;
	
EndProcedure

&AtClient
Procedure RawDuplicatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenDuplicateForm(Items.RawDuplicates.CurrentData);
	
EndProcedure

#EndRegion

#Region UnprocessedUsagePlacesTableEventsHandlers

&AtClient
Procedure UsagePlacesRawOnActivateRow(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		ErrorDescriptionRaw = "";
	Else
		ErrorDescriptionRaw = CurrentData.ErrorText;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsagePlacesRawSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = UsagePlacesRaw.FindByID(SelectedRow);
	ShowValue(, CurrentData.ErrorObject);
	
EndProcedure

#EndRegion

#Region CandidateUsagePlacesTableEventsHandlers

&AtClient
Procedure CandidateUsagePlacesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = CandidateUsagePlaces.FindByID(SelectedRow);
	ShowValue(, CurrentData.Data);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ClearFilterRules(Command)
	
	ClearFilterForce();
	
EndProcedure

&AtClient
Procedure SelectMainItem(Command)
	
	RowData = Items.FoundDuplicates.CurrentData;
	If RowData = Undefined	// No data
		Or RowData.Default		// Current is already main
	Then
		Return;
	EndIf;
		
	Parent = RowData.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ChangeMainItemHierarchically(RowData, Parent);
EndProcedure

&AtClient
Procedure OpenCandidateInDuplicates(Command)
	
	OpenDuplicateForm(Items.FoundDuplicates.CurrentData);
	
EndProcedure

&AtClient
Procedure ExpandDuplicateGroups(Command)
	
	ExpandDuplicatesGroupHierarchically();
	
EndProcedure

&AtClient
Procedure GroupbyDuplicateGroups(Command)
	
	HierarchicallyCollapseDuplicatesGroup();
	
EndProcedure

&AtClient
Procedure RetrySearch(Command)
	
	GoToAssistantStep(Items.StepSearchExecution, True);
	
EndProcedure

&AtClient
Procedure AssistantStepBack(Command)
	AssistantStep("Back");
EndProcedure

&AtClient
Procedure NextAssistantStep(Command)
	AssistantStep("Next");
EndProcedure

&AtClient
Procedure AssistantStepCancel(Command)
	AssistantStep("Cancel");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateDuplicatesAreasSettings(Val ValueSelected)
	
	Item = DuplicateSearchAreas.FindByValue(ValueSelected);
	If Item = Undefined Then
		PresentationDuplicateSearchAreas = "";
		DuplicateSearchArea              = "";
	Else
		PresentationDuplicateSearchAreas = Item.Presentation;
		DuplicateSearchArea              = ValueSelected;
	EndIf;
	
	InitializeSelectionAndRulesLinker();
EndProcedure

&AtClient
Procedure OpenDuplicateForm(Val CurrentData)
	If CurrentData = Undefined Or Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	ShowValue(,CurrentData.Ref);
EndProcedure

&AtServer
Procedure SetColorAndConditionalDesign()
	ColorsExplanationText       = StyleColorOrAuto("ExplanationText",       69,  81,  133);
	ColorExplanationTextError = StyleColorOrAuto("ExplanationTextError", 255, 0,   0);
	ColorInaccessibleData     = StyleColorOrAuto("ColorInaccessibleData", 192, 192, 192);
	
	ConditionalDesignItems = ConditionalAppearance.Items;
	ConditionalDesignItems.Clear();
	
	// Group does not have usage places.
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Ref");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	AppearanceFilter.RightValue = True;
	
	DesignElement.Appearance.SetParameterValue("Text", "");
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCount");
	
	// 1. Row with the current main group item:
	
	// Picture
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Default");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	DesignElement.Appearance.SetParameterValue("Visible", True);
	DesignElement.Appearance.SetParameterValue("Show", True);
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesBasic");
	
	// There is no mark
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Default");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	DesignElement.Appearance.SetParameterValue("Visible", False);
	DesignElement.Appearance.SetParameterValue("Show", False);
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesMark");
	
	// 2. Row with a regular item.
	
	// Picture
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Default");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	DesignElement.Appearance.SetParameterValue("Visible", False);
	DesignElement.Appearance.SetParameterValue("Show", False);
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesBasic");
	
	// Presence of a mark
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Default");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	DesignElement.Appearance.SetParameterValue("Visible", True);
	DesignElement.Appearance.SetParameterValue("Show", True);
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesMark");
	
	// 3. Usage location
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Ref");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Filled;
	AppearanceFilter.RightValue = True;
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Quantity");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = 0;
	
	DesignElement.Appearance.SetParameterValue("Text", NStr("en='Not Used';ru='Не используется'"));
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicatesCount");
	
	// 4. Inactive row
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("FoundDuplicates.Check");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = 0;
	
	DesignElement.Appearance.SetParameterValue("TextColor", ColorInaccessibleData);
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("FoundDuplicates");
	
EndProcedure

&AtServer
Function StyleColorOrAuto(Val Name, Val Red = Undefined, Green = Undefined, Blue = Undefined)
	StyleItem = Metadata.StyleItems.Find(Name);
	If StyleItem <> Undefined AND StyleItem.Type = Metadata.ObjectProperties.StyleElementType.Color Then
		Return StyleColors[Name];
	EndIf;
	
	Return ?(Red = Undefined, New Color, New Color(Red, Green, Blue));
EndFunction

&AtServer
Function DuplicatesSubstitutionsPairs()
	SubstitutionsPairs = New Map;
	
	DuplicatesTree = FormAttributeToValue("FoundDuplicates");
	SearchFilter = New Structure("Default", True);
	
	For Each Parent In DuplicatesTree.Rows Do
		MainInGroup = Parent.Rows.FindRows(SearchFilter)[0].Ref;
		
		For Each Descendant In Parent.Rows Do
			If Descendant.Check = 1 Then 
				SubstitutionsPairs.Insert(Descendant.Ref, MainInGroup);
			EndIf;
		EndDo;
	EndDo;
	
	Return SubstitutionsPairs;
EndFunction

&AtClient
Function UsagePlacesReportAnalysis(Val Source)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("RefsSet", New Array);
	
	For Each Parent In Source.GetItems() Do
		For Each Descendant In Parent.GetItems() Do
			ReportParameters.RefsSet.Add(Descendant.Ref);
		EndDo;
	EndDo;
	
	Return ReportParameters;
EndFunction

&AtClient
Procedure ExpandDuplicatesGroupHierarchically(Val DataRow = Undefined)
	If DataRow <> Undefined Then
		Items.FoundDuplicates.Expand(DataRow, True);
	EndIf;
	
	// There are all of the first level
	AllRows = Items.FoundDuplicates;
	For Each RowData In FoundDuplicates.GetItems() Do 
		AllRows.Expand(RowData.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure HierarchicallyCollapseDuplicatesGroup(Val DataRow = Undefined)
	If DataRow <> Undefined Then
		Items.FoundDuplicates.Collapse(DataRow);
		Return;
	EndIf;
	
	// There are all of the first level
	AllRows = Items.FoundDuplicates;
	For Each RowData In FoundDuplicates.GetItems() Do 
		AllRows.Collapse(RowData.GetID());
	EndDo;
EndProcedure

&AtClient
Procedure ChangeCandidatesMarksierarchically(Val RowData)
	SetMarksDown(RowData);
	SetMarksUp(RowData);
EndProcedure

&AtClient
Procedure SetMarksDown(Val RowData)
	Value = RowData.Check;
	For Each Descendant In RowData.GetItems() Do
		Descendant.Check = Value;
		SetMarksDown(Descendant);
	EndDo;
EndProcedure

&AtClient
Procedure SetMarksUp(Val RowData)
	RowParent = RowData.GetParent();
	
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		
		For Each Descendant In RowParent.GetItems() Do
			AllTrue = AllTrue AND (Descendant.Check = 1);
			NotAllFalse = NotAllFalse Or (Descendant.Check > 0);
		EndDo;
		
		If AllTrue Then
			RowParent.Check = 1;
			
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
			
		Else
			RowParent.Check = 0;
			
		EndIf;
		
		SetMarksUp(RowParent);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeMainItemHierarchically(Val RowData, Val Parent)
	For Each Descendant In Parent.GetItems() Do
		Descendant.Default = False;
	EndDo;
	RowData.Default = True;
	
	// Always use the selected one.
	RowData.Check = 1;
	ChangeCandidatesMarksierarchically(RowData);
	
	// And change a group name
	Parent.Description = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 (%2)';ru='%1 (%2)'"), 
		RowData.Description, Parent.Quantity);
EndProcedure

&AtServer
Function FillDuplicatesSearchResults(Val Data)
	// Data - result of the DuplicatesGroups module functions.
	
	// Build tree for editing by the result tables.
	TreeItems = FoundDuplicates.GetItems();
	TreeItems.Clear();
	
	UsagePlaces = Data.UsagePlaces;
	DuplicatesTable      = Data.DuplicatesTable;
	
	RowsFilter = New Structure("Parent");
	PlacesFilter  = New Structure("Ref");
	
	TotalDuplicatesFound = 0;
	
	AllGroups = DuplicatesTable.FindRows(RowsFilter);
	For Each Group In AllGroups Do
		RowsFilter.Parent = Group.Ref;
		GroupItems = DuplicatesTable.FindRows(RowsFilter);
		
		TreeGroup = TreeItems.Add();
		TreeGroup.Quantity = GroupItems.Count();
		TreeGroup.Check = 1;
		
		MaxRow = Undefined;
		MaxPlaces   = -1;
		For Each Item In GroupItems Do
			TreeRow = TreeGroup.GetItems().Add();
			FillPropertyValues(TreeRow, Item, "Ref, Code, Name");
			TreeRow.Check = 1;
			
			PlacesFilter.Ref = Item.Ref;
			TreeRow.Quantity = UsagePlaces.FindRows(PlacesFilter).Count();
			
			If MaxPlaces < TreeRow.Quantity Then
				If MaxRow <> Undefined Then
					MaxRow.Default = False;
				EndIf;
				MaxRow = TreeRow;
				MaxPlaces   = TreeRow.Quantity;
				MaxRow.Default = True;
			EndIf;
			
			TotalDuplicatesFound = TotalDuplicatesFound + 1;
		EndDo;
		
		// Set a candidate by a max reference.
		TreeGroup.Description = MaxRow.Description + " (" + TreeGroup.Quantity + ")";
	EndDo;
	
	// Save usage places for the future filter.
	CandidateUsagePlaces.Clear();
	Items.CurrentDuplicateGroupDescription.Title = NStr("en='No duplicates are found';ru='Дублей не найдено'");
	
	If IsTempStorageURL(UsePlaceAddress) Then
		DeleteFromTempStorage(UsePlaceAddress);
	EndIf;
	UsePlaceAddress = PutToTempStorage(UsagePlaces, UUID);

	If Not IsBlankString(Data.ErrorDescription) Then
		// Background is broken
		FoundDuplicatesStatusDescription = New FormattedString(Items.Attention16.Picture, " ", 
			New FormattedString(Data.ErrorDescription, , ColorExplanationTextError));
		Return -1;
		
	EndIf;
		
	// There are no search errors
	If TotalDuplicatesFound = 0 Then
		FoundDuplicatesStatusDescription = New FormattedString(Items.Information16.Picture, " ",
			NStr("en='Duplicates by the specified conditions are not found';ru='Не обнаружено дублей по указанным условиям'"));
	Else
		FoundDuplicatesStatusDescription = New FormattedString(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Duplicates of items are found: %2 (among items: %1). All selected items will be marked for deletion and substituted for the originals in all usage places (marked with an arrow).';ru='Найдены дубли элементов: %2 (среди элементов: %1). Все отмеченные элементы будут помечены на удаление 
		|и заменены во всех местах использования на оригиналы (отмечены стрелкой).'"),
			TotalDuplicatesFound, TotalDuplicatesFound - TreeItems.Count()),
			, ColorsExplanationText);
	EndIf;
	
	Return TotalDuplicatesFound;
EndFunction

&AtServer
Function FillDuplicatesDeletetionResults(Val ErrorsTable)
	// ErrorsTable - result of the ReplaceRefs module functions.
	
	If IsTempStorageURL(ResultAddressReplacement) Then
		DeleteFromTempStorage(ResultAddressReplacement);
	EndIf;
	
	CompleteWithoutErrors = ErrorsTable.Count() = 0;
	LastCandidate  = Undefined;
	
	If CompleteWithoutErrors Then
		TotallyProcessed = 0; 
		TotallyMain   = 0;
		For Each DuplicatesGroup In FoundDuplicates.GetItems() Do
			If DuplicatesGroup.Check Then
				For Each Candidate In DuplicatesGroup.GetItems() Do
					If Candidate.Default Then
						LastCandidate = Candidate.Ref;
						TotallyProcessed   = TotallyProcessed + 1;
						TotallyMain     = TotallyMain + 1;
					ElsIf Candidate.Check Then 
						TotallyProcessed = TotallyProcessed + 1;
					EndIf;
				EndDo;
			EndIf;
		EndDo;
		
		If TotallyMain = 1 Then
			// Many duplicates to one item.
			If LastCandidate = Undefined Then
				FoundDuplicatesStatusDescription = New FormattedString(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='All found duplicates (%1) are successfully merged';ru='Все найденные дубли (%1) успешно объединены'"), TotallyProcessed));
			Else
				LastCandidateRow = CommonUse.SubjectString(LastCandidate);
				FoundDuplicatesStatusDescription = New FormattedString(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='All found duplicates (%1) are
		|successfully merged to %2.';ru='Все найденные дубли (%1)
		|успешно объединены в ""%2""'"),
					TotallyProcessed, LastCandidateRow));
			EndIf;
		Else
			// Many duplicates to many groups.
			FoundDuplicatesStatusDescription = New FormattedString(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='All found duplicates (%1) are successfully merged.
		|Kept items (%2).';ru='Все найденные дубли (%1) успешно объединены.
		|Оставлено элементов (%2).'"),
				TotallyProcessed, TotallyMain));
		EndIf;
	EndIf;
	
	RawDuplicates.GetItems().Clear();
	UsagePlacesRaw.Clear();
	CandidateUsagePlaces.Clear();
	
	If CompleteWithoutErrors Then
		FoundDuplicates.GetItems().Clear();
		Return True;
	EndIf;
	
	// Save for future access during the references analysis.
	ResultAddressReplacement = PutToTempStorage(ErrorsTable, UUID);
	
	// Generate duplicates tree by errors.
	ValueToFormAttribute(FormAttributeToValue("FoundDuplicates"), "RawDuplicates");
	
	// Analyze the remaining
	Filter = New Structure("Ref");
	Parents = RawDuplicates.GetItems();
	ParentPosition = Parents.Count() - 1;
	While ParentPosition >= 0 Do
		Parent = Parents[ParentPosition];
		
		Descendants = Parent.GetItems();
		DescendantPostion = Descendants.Count() - 1;
		MainDescendant = Descendants[0];	// There is one as min
		
		While DescendantPostion >= 0 Do
			Descendant = Descendants[DescendantPostion];
			
			If Descendant.Default Then
				MainDescendant = Descendant;
				Filter.Ref = Descendant.Ref;
				Descendant.Quantity = ErrorsTable.FindRows(Filter).Count();
				
			ElsIf ErrorsTable.Find(Descendant.Ref, "Ref") = Undefined Then
				// It was successfully deleted, no mistakes.
				Descendants.Delete(Descendant);
				
			Else
				Filter.Ref = Descendant.Ref;
				Descendant.Quantity = ErrorsTable.FindRows(Filter).Count();
				
			EndIf;
			
			DescendantPostion = DescendantPostion - 1;
		EndDo;
		
		DescendantsQuantity = Descendants.Count();
		If DescendantsQuantity = 1 AND Descendants[0].Default Then
			Parents.Delete(Parent);
		Else
			Parent.Quantity = DescendantsQuantity - 1;
			Parent.Description = MainDescendant.Description + " (" + DescendantsQuantity + ")";
		EndIf;
		
		ParentPosition = ParentPosition - 1;
	EndDo;
	
	Return False;
EndFunction

&AtServer
Function SelectionLinkerSettingsAddress()
	
	Return PutToTempStorage(ComposerPreFilter.Settings, UUID)
	
EndFunction

&AtServer
Function SearchRulesSettingsAddress()
	
	Settings = New Structure;
	Settings.Insert("ConsiderAppliedRules", ConsiderAppliedRules);
	Settings.Insert("AllComparisonVariants", AllComparisonVariants);
	Settings.Insert("SearchRules", FormAttributeToValue("SearchRules"));
	
	Return PutToTempStorage(Settings);
EndFunction

&AtServer
Procedure UpdateFilterLinker(Address)
	
	ComposerPreFilter.LoadSettings( GetFromTempStorage(Address) );
	DeleteFromTempStorage(Address);
	
EndProcedure

&AtServer
Procedure UpdateSearchRules(Address)
	Settings = GetFromTempStorage(Address);
	Address = Undefined;
	
	ConsiderAppliedRules = Settings.ConsiderAppliedRules;
	ValueToFormAttribute(Settings.SearchRules, "SearchRules");
EndProcedure

&AtClient
Procedure UpdateSearchRulesDescription()
	RulesText = "";
	Conjunction        = " " + NStr("en='AND';ru='А ТАКЖЕ'") + " ";
	
	For Each Rule In SearchRules Do
		
		If Rule.Rule = "Equal" Then
			Comparison = NStr("en='%1 matches';ru='%1 совпадает'");
		ElsIf Rule.Rule = "Like" Then
			Comparison = NStr("en='%1 matches by the similar words';ru='%1 совпадает по похожим словам'");
		Else
			Comparison = "";
		EndIf;
		
		RulesText = RulesText + ?(IsBlankString(Comparison), "", Conjunction) + StrReplace(Comparison, "%1", Rule.AttributePresentation);
	EndDo;
	
	AppliedText = "";
	If ConsiderAppliedRules Then
		For Position = 1 To StrLineCount(AppliedRulesDescription) Do
			RuleRow = TrimAll(StrGetLine(AppliedRulesDescription, Position));
			If Not IsBlankString(RuleRow) Then
				AppliedText = AppliedText + Conjunction + RuleRow;
			EndIf;
		EndDo;
	EndIf;
		
	RulesText = RulesText + AppliedText;
	If IsBlankString(RulesText) Then
		Items.SearchRules.Title = NStr("en='Rules are not specified';ru='Правила не заданы'");
	Else
		Items.SearchRules.Title = TrimAll(Mid(RulesText, StrLen(Conjunction)));
	EndIf;
	
	Items.SearchRules.Enabled = Not IsBlankString(DuplicateSearchArea);
EndProcedure

&AtClient
Procedure UpdateFilterDescription()
	
	FilterDescription = String(ComposerPreFilter.Settings.Filter);
	If IsBlankString(FilterDescription) Then
		FilterDescription = NStr("en='All items';ru='Все элементы'");
		Items.ClearFilterRules.Enabled = False;
	Else
		Items.ClearFilterRules.Enabled = True;
	EndIf;
	
	Items.FilterRule.Title = FilterDescription;
	
	Items.FilterRule.Enabled = Not IsBlankString(DuplicateSearchArea);
EndProcedure

&AtClient
Procedure UpdateSearchAreaDescription()

	List = Items.PresentationDuplicateSearchAreas.ChoiceList;
	List.Clear();
	PresentationItem = List.Add();
	
	Current = DuplicateSearchAreas.FindByValue(DuplicateSearchArea);
	If Current <> Undefined Then
		FillPropertyValues(PresentationItem, Current);
	EndIf;
	
	ThisObject.RefreshDataRepresentation();
EndProcedure

&AtClient
Procedure ClearFilterForce()
	
	ComposerPreFilter.Settings.Filter.Items.Clear();
	UpdateFilterDescription();
	
EndProcedure

&AtServer
Procedure InitializeSelectionAndRulesLinker()
	// 1. Clear all
	ComposerPreFilter = New DataCompositionSettingsComposer;
	If IsTempStorageURL(SchemaURLComposition) Then
		DeleteFromTempStorage(SchemaURLComposition);
		SchemaURLComposition = "";
	EndIf;
	
	AppliedRulesDescription = Undefined;
	SearchRules.Clear();
	
	If IsBlankString(DuplicateSearchArea) Then
		Return;
	EndIf;
	
	MetaArea = Metadata.FindByFullName(DuplicateSearchArea);
	
	// 2. Build linker for search - selection.
	AvailableSelectionAttributes = AvailableMetaNamesSelectionAttributes(MetaArea.StandardAttributes);
	AvailableSelectionAttributes = ?(IsBlankString(AvailableSelectionAttributes), ",", AvailableSelectionAttributes)
		+ AvailableMetaNamesSelectionAttributes(MetaArea.Attributes);
		
	CompositionSchema = New DataCompositionSchema;
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = "SELECT " + Mid(AvailableSelectionAttributes, 2) + " FROM " + DuplicateSearchArea;
	DataSet.AutoFillAvailableFields = True;
	
	// Save a schema in the main form profile for a linker not to lose relevance.
	SchemaURLComposition = PutToTempStorage(CompositionSchema, UUID);
	
	ComposerPreFilter.Initialize(New DataCompositionAvailableSettingsSource(CompositionSchema));
	
	// 3. Collect rules offered by default for the metadata kind.
	IgnoredAttributes = New Structure("DeletionMark, Ref, Predefined, PredefinedDataName, IsFolder");
	RulesTable = FormAttributeToValue("SearchRules");
	
	AllComparisonVariants.Clear();
	AllComparisonVariants.Add("Equal",   NStr("en='Matches';ru='Совпадает'"));
	AllComparisonVariants.Add("Like", NStr("en='Matches by similar words';ru='Совпадает по похожим словам'"));

	AddMetaAttributesRules(RulesTable, IgnoredAttributes, AllComparisonVariants, MetaArea.StandardAttributes);
	AddMetaAttributesRules(RulesTable, IgnoredAttributes, AllComparisonVariants, MetaArea.Attributes);
	
	SetDefaultRulesValues(DuplicateSearchArea, ComposerPreFilter, RulesTable);
	
	// 4. Process applied data.
	If DuplicateSearchAreas.FindByValue(DuplicateSearchArea).Check Then
		// There is an applied functionality
		
		// Empty row of parameters.
		DataProcessorObject = FormAttributeToValue("Object");
		DefaultParameters = DataProcessorObject.AppliedDefaultParameters(
			SearchRules.Unload(,"Attribute, Rule"),
			ComposerPreFilter
		);
		
		// Call an applied code
		AreaManager = DataProcessorObject.DuplicateSearchAreaManager(DuplicateSearchArea);
		AreaManager.DuplicatesSearchParameters(DefaultParameters);
		
		// Generate a row of the applied rules.
		AppliedRulesDescription = "";
		For Each Definition In DefaultParameters.ComparisonRestriction Do
			AppliedRulesDescription = AppliedRulesDescription + Chars.LF + Definition.Presentation;
		EndDo;
		AppliedRulesDescription = TrimAll(AppliedRulesDescription);
	EndIf;
	
	RulesTable.Sort("AttributePresentation");
	ValueToFormAttribute(RulesTable, "SearchRules");
EndProcedure

&AtServerNoContext
Function AvailableMetaNamesSelectionAttributes(Val MetaCollection)
	Result = "";
	StorageType = Type("ValueStorage");
	
	For Each MetaAttribute In MetaCollection Do
		IsStorage = MetaAttribute.Type.ContainsType(StorageType);
		If Not IsStorage Then
			Result = Result + "," + MetaAttribute.Name;
		EndIf
	EndDo;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure AddMetaAttributesRules(RulesTable, Val Ignore, Val AllComparisonVariants, Val MetaCollection)
	
	For Each MetaAttribute In MetaCollection Do
		If Not Ignore.Property(MetaAttribute.Name) Then
			ComparisonVariants = ComparisonVariantsForType(MetaAttribute.Type, AllComparisonVariants);
			If ComparisonVariants <> Undefined Then
				// You can compare
				RulesRow = RulesTable.Add();
				RulesRow.Attribute          = MetaAttribute.Name;
				RulesRow.ComparisonVariants = ComparisonVariants;
				
				AttributePresentation = MetaAttribute.Synonym;
				RulesRow.AttributePresentation = ?(IsBlankString(AttributePresentation), MetaAttribute.Name, AttributePresentation);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SetDefaultRulesValues(Val SearchArea, Val FilterLinker, Val ComparisonRules) 
	
	// Filter rule
	FilterItems = FilterLinker.Settings.Filter.Items;
	FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
	FilterItem.Use  = True;
	FilterItem.LeftValue  = New DataCompositionField("DeletionMark");
	FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = False;;
	
	// Comparison rule only if there is a name.
	Rule = ComparisonRules.Find("Description", "Attribute");
	If Rule <> Undefined Then
		If Rule.ComparisonVariants.FindByValue("Like") <> Undefined Then
			Rule.Rule = "Like";
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ComparisonVariantsForType(Val AvailableTypes, Val AllComparisonVariants) 
	
	IsStorage = AvailableTypes.ContainsType(Type("ValueStorage"));
	If IsStorage Then 
		// You can not compare
		Return Undefined;
	EndIf;
	
	IsRow = AvailableTypes.ContainsType(Type("String"));
	IsFixedRow = IsRow AND AvailableTypes.StringQualifiers <> Undefined 
		AND AvailableTypes.StringQualifiers.Length <> 0;
		
	If IsRow AND Not IsFixedRow Then
		// You can not compare
		Return Undefined;
	EndIf;
	
	Result = New ValueList;
	FillPropertyValues(Result.Add(), AllComparisonVariants[0]);		// Matches
	
	If IsRow Then
		FillPropertyValues(Result.Add(), AllComparisonVariants[1]);	// Similar
	EndIf;
		
	Return Result;
EndFunction

&AtServer
Procedure InitializeMainParameters()
	
	// Unconditionally select the check box of rules accounting.
	ConsiderAppliedRules = True;
	
	DataProcessorObject = FormAttributeToValue("Object");
	MetaObjectsProcessor = DataProcessorObject.Metadata();
	
	IsExternalDataProcessor = Not Metadata.DataProcessors.Contains(MetaObjectsProcessor);
	DataProcessorName        = ?(IsExternalDataProcessor, DataProcessorObject.UsedFileName, MetaObjectsProcessor.Name);
	BasicFormName     = MetaObjectsProcessor.FullName() + ".Form.";
	
	DataProcessorObject.DuplicateSearchAreas(DuplicateSearchAreas, True);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Step by step assistant

&AtServer
Procedure InitializeAssistantScript()
	
	// 0. Search was not run
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Title = NStr("en='Find duplicates >';ru='Найти дубли >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Find duplicates by the specified criteria';ru='Найти дубли по указанным критериям'");
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Cancel to search and substitute duplicates.';ru='Отказаться от поиска и замены дублей'");
	
	AddAssistantStep(Items.StepSearchWasNotRun,
		AssistantStepAction("OnActivating",         "StepSearchNotExecutedOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepSearchNotExecutedBeforeNextAction",
		AssistantStepAction("BeforeCancelAction", "SearchStepNotExecutedBeforeCancelAction",))),
		ButtonsAssistant);
	
	// 1. Long search
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.Title = NStr("en='Break';ru='Прервать'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Stop duplicates search';ru='Прервать поиск дублей'");
	
	AddAssistantStep(Items.StepSearchExecution,
		AssistantStepAction("OnActivating",         "StepSearchExecutionOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepSearchExecutionBeforeCancelAction",
		AssistantStepAction("OnProcessWaiting", "StepSearchExecutionOnProcessWaiting",))), 
		ButtonsAssistant);
	
	// 2. Search results processor, select main items.
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Title = NStr("en='Delete duplicates >';ru='Удалить дубли >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Delete duplicates';ru='Удаление дублей'");
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Cancel to search and substitute duplicates.';ru='Отказаться от поиска и замены дублей'");
	
	AddAssistantStep(Items.StepSelectMainItem,
		AssistantStepAction("OnActivating",         "StepSelectMainItemOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepSelectMainItemBeforeCancelAction",
		AssistantStepAction("BeforeNextAction",  "StepSelectMainItemBeforeNextAction",))),
		ButtonsAssistant);
	
	// 3. Long deletion of duplicates.
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.Title = NStr("en='Break';ru='Прервать'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Break duplicates deletion';ru='Прервать удаление дублей'");
	
	AddAssistantStep(Items.StepDeleteExecution,
		AssistantStepAction("OnActivating",         "StepDeleteExecutionOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepDeletionExecutionBeforeCalncelAction",
		AssistantStepAction("OnProcessWaiting", "StepDeletionExecutionOnProcessWaiting",))), 
		ButtonsAssistant);
	
	// 4. Successful deletion
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Title = NStr("en='<New search';ru='< Новый поиск'");
	ButtonsAssistant.Back.ToolTip = NStr("en='Start a new search with other parameters';ru='Начать новый поиск с другими параметрами'");
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.DefaultButton = True;
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	
	AddAssistantStep(Items.StepSuccessfulDelete,
		AssistantStepAction("OnActivating",         "StepSuccessfulDeletetionOnActivating",
		AssistantStepAction("BeforeBackAction",  "StepSuccessfulDeletionBeforeBackAction",
		AssistantStepAction("BeforeCancelAction", "StepSuccessfulDeletionBeforeCancelAction",))),
		ButtonsAssistant);
	
	// 5. Incomplete deletion
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Title = NStr("en='Repeat deletion >';ru='Повторить удаление >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Delete duplicates';ru='Удаление дублей'");
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	
	AddAssistantStep(Items.StepFailedReplacements,
		AssistantStepAction("OnActivating",         "StepFailedReplacementsOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepFailedReplacementsBeforeNextAction",
		AssistantStepAction("BeforeCancelAction", "StepFailedReplacementsBeforeCancelAction",))),
		ButtonsAssistant);
	
	// 6. No duplicates are found
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Title = NStr("en='Find duplicates >';ru='Найти дубли >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Find duplicates by the specified criteria';ru='Найти дубли по указанным критериям'");
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	
	AddAssistantStep(Items.DuplicateStepIsNotFound,
		AssistantStepAction("OnActivating",         "StepDuplicatesAreNotFoundOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepDuplicatesNotFoundBeforeNextAction",
		AssistantStepAction("BeforeCancelAction", "StepDuplicatesNotFoundBeforeCancelAction",))),
		ButtonsAssistant);
	
EndProcedure

// 0. Search was not run

&AtClient
Procedure StepSearchNotExecutedOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = True;
	
	UpdateFilterDescription();
	UpdateSearchAreaDescription();
	UpdateSearchRulesDescription();
	
EndProcedure

&AtClient
Procedure StepSearchNotExecutedBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Possibility of search
	If Not IsBlankString(DuplicateSearchArea) Then
		AssistantStepEnd(StepParameters);
		Return;
	EndIf;
	
	WarningText = NStr("en='You need to select duplicates search area';ru='Необходимо выбрать область поиска дублей'");
	ShowMessageBox(, WarningText);
EndProcedure

&AtClient
Procedure SearchStepNotExecutedBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

// 1. Long search

&AtClient
Procedure StepSearchExecutionOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = False;
	
	If Not IsTempStorageURL(SchemaURLComposition) Then
		Return; // Not initialized.
	EndIf;
	
	BackGroundJobStart("BackgroundDuplicatesSearch");
	
EndProcedure

&AtClient
Procedure StepSearchExecutionOnProcessWaiting(Stop, Val AdditionalParameters) Export
	If BackgroundJobImportOnClient(False, False) Then
		Stop = True;
	EndIf;
EndProcedure

&AtClient
Procedure StepSearchExecutionBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	CheckBackgroundJobAndCloseFormWithoutConfirmation();
EndProcedure

// 2. Search results processor, select main items.

&AtClient
Procedure StepSelectMainItemOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = True;
	
	// Allow to repeat search
	Items.RetrySearch.Visible = True;
	
	ExpandDuplicatesGroupHierarchically();
	
EndProcedure

&AtClient
Procedure StepSelectMainItemBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Deny repeating search
	Items.RetrySearch.Visible = False;
	
	AssistantStepEnd(StepParameters);
EndProcedure

&AtClient
Procedure StepSelectMainItemBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

// 3. Long deletion

&AtClient
Procedure StepDeleteExecutionOnActivating(Val StepParameters, Val AdditionalParameters) Export
	Items.Title.Enabled = False;
	BackGroundJobStart("DuplicatesBackgroundDeletetion");
EndProcedure

&AtClient
Procedure StepDeletionExecutionOnProcessWaiting(Stop, Val AdditionalParameters) Export
	If BackgroundJobImportOnClient(False, False) Then
		Stop = True;
	EndIf;
EndProcedure

&AtClient
Procedure StepDeletionExecutionBeforeCalncelAction(Val StepParameters, Val AdditionalParameters) Export
	CheckBackgroundJobAndCloseFormWithoutConfirmation();
EndProcedure

// 4. Successful deletion

&AtClient
Procedure StepSuccessfulDeletetionOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = False;
	
EndProcedure

&AtClient
Procedure StepSuccessfulDeletionBeforeBackAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Transfer to the beginning for work with new parameters.
	GoToAssistantStep(Items.StepSearchWasNotRun, True);
	
EndProcedure

&AtClient
Procedure StepSuccessfulDeletionBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

// 5. Incomplete deletion

&AtClient
Procedure StepFailedReplacementsOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = False;
	
EndProcedure

&AtClient
Procedure StepFailedReplacementsBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Repeat deletion
	GoToAssistantStep(Items.StepDeleteExecution, True);
	
EndProcedure

&AtClient
Procedure StepFailedReplacementsBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

// 6. No duplicates are found

&AtClient
Procedure StepDuplicatesAreNotFoundOnActivating(Val StepParameters, Val AdditionalParameters) Export
	
	Items.Title.Enabled = True;
	
EndProcedure

&AtClient
Procedure StepDuplicatesNotFoundBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Pass to a repeated search
	GoToAssistantStep(Items.StepSearchExecution, True);
	
EndProcedure

&AtClient
Procedure StepDuplicatesNotFoundBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Assistant box

// To insert assistant functionality, you need to:
//
//     1) Draw a group on the form containing assistant pages.
//     2) Define tree commands on form for the Next, Back, Cancel actions. Define handlers to them as:
//
//         &AtClient
//         Procedure
//         MasterStepBack(Command) MasterStep("Back");
//         EndProcedure
//
//         &AtClient
//         Procedure
//         MasterStepNext(Command) MasterStep("Next");
//         EndProcedure
//
//         &AtClient
//         Procedure
//         MasterStepCancel(Command) MasterStep("Cancel");
//         EndProcedure
//
//     3) Add a group of step by step assistant methods.
//
//     4) IN code on server:
//          - Initialize assistant structures using the InitializeAssistant
//            call after passing there all correspondent form items.
//
//          - Create a script of work with the AddAssistantStep serial calls. It is
//     recommended to use the helper functions AssistantStepAction, AssistantStepButton. ForExample:
//
//              AddAssistantStep(Items.StepSelectTargetItem, 
//                      AssistantStepAction("OnActivating",         "StepSelectTargetItemOnActivating",
//                      AssistantStepAction("BeforeNextAction",  "StepSelectTargetItemBeforeNextAction",
//                      AssistantStepAction("BeforeCancelAction", "StepSelectTargetItemBeforeCancelAction",
//                  ))), 
//                      ButtonsAssistant()
//              );
//
//     5) IN code on client (usually during opening):
//          - Specify a assistant initial page using the SetAssistantInitialPage call.
//          - Launch an initial page using the LaunchAssistantWork call.
//

&AtServer
Function InitializeMaster(Val PagesGroup, Val ButtonNext, Val ButtonBack, Val ButtonCancel)
	// Initializes assistant structures.
	//
	// Parameters:
	//     PagesGroup - FormGroup - An item of a form, a group of the page type containing assistant pages-steps.
	//     ButtonNext   - FormButton, CommandBarButton - Form item used for the Next button.
	//     ButtonBack   - FormButton, CommandBarButton - Form item used for the Back button.
	//     ButtonCancel  - FormButton, CommandBarButton - Form item used for the Cancel button.
	Result = New Structure;
	
	Result.Insert("Steps", New Array);
	Result.Insert("CurrentStepNumber", 0);
	Result.Insert("StartPage", Undefined);
	
	// Identifiers of the interface parts.
	Result.Insert("PagesGroup", PagesGroup.Name);
	Result.Insert("ButtonNext",   ButtonNext.Name);
	Result.Insert("ButtonBack",   ButtonBack.Name);
	Result.Insert("ButtonCancel",  ButtonCancel.Name);
	
	// The handler call timeout
	Result.Insert("LongOperationWaitingTimeout", 
		?( GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 5, 3) );
		
	// To process long actions.
	Result.Insert("BackgroundJobID");
	Result.Insert("BackgroundJobResultAddress");
	Result.Insert("ErrorInfo");
	Result.Insert("JobCompleted", False);
	Result.Insert("ProcedureName");
	Result.Insert("HasJobCancellationConfirmation", False);
	
	// To store custom parameters.
	Result.Insert("CustomParameters", New Map);
	
	Return Result;
EndFunction

// Adds the assistant step. Transitions between pages will happen according to the order of adding.
//
// Parameters:
//
//     Page - FormGroup - Group-page containing items of a current page step.
// 
//     Actions - Structure - Description of actions that are possible to be executed on the current step. Structure fields:
//
//          *  OnActivate      - String - Optional name of the procedure that
//                                          will be executed before activating a page with two parameters.:
//                                           <Page> - FormGroup - group-page that is being activated.
//                                           <AdditionalParameters> - Undefined
//
//          * BeforeNextAction  - String - Optional name of a procedure that will
//                                            be executed after clicking the Next button before going to the next page. The procedure will
//                                            be called with two parameters:
//                                              <StepParameters> - service attribute. If a chain
//                                                                of modeless calls is successfully
//                                                                ended, the last procedure-handler should execute a call.
//                                                                AssistantStepEnd(StepParameter)
//                                                                confirming an action.
//                                             <AdditionalParameters> - Undefined
//
//          * BeforeBackAction  - String - Same as BeforeNextAction it describes the
//                                            behavior of the Next button click.
//
//          * BeforeCancelAction - String - Same as BeforeNextAction it describes the
//                                            behavior of the Cancel button click.
//
//          * OnProcessWaiting - String - Optional name of the procedure that
//                                            will be periodically called with two parameters.:
//                                              <Stop> - If you set the True value when
//                                                             you leave the procedure, then periodic calls will be terminated.
//                                              <AdditionalParameters> - Undefined
//
//      Buttons - Structure - descriptions of buttons on the current step. Structure fields:
//
//          * Next  - Structure - The Next button description. fields: Title, ToolTip, Enabled,
//                                 Visible, DefaultButton.
//                                 An empty tooltip is replaced with a title. Default values will be used:
//                                 Title = "Next >", Enabled = True, Visible = True, DefaultButton = True;
//
//          * Back  - Structure - Same as the Next button, default values:
//                                 Title = "< Back", Enabled = True, Visible = True, DefaultButton = False;
//
//          * Cancel - Structure - Same as the Next button, default values:
//                                 Title = "Cancel", Enabled = True, Visible = True, DefaultButton = False;
//
// To compose parameters, it is recommended to
// use the helper methods AddAssistantStep, AssistantStepAction, AssistantStepButton.
//
&AtServer
Procedure AddAssistantStep(Val Page, Val Actions, Val Buttons)
	
	// Defaults
	StepDescription = New Structure("OnActivating, BeforeNextAction, BeforeBackAction, BeforeCancelAction, OnProcessWaiting");
	
	StepDescription.Insert("Page", Page.Name);
	
	// Set actions
	FillPropertyValues(StepDescription, Actions);
	
	// Buttons description registration.
	For Each KeyAndValue In Buttons Do
		ButtonName = KeyAndValue.Key;
		ButtonDescription = KeyAndValue.Value;
		// Fill up secondary properties.
		If Not ButtonDescription.Visible Then
			ButtonDescription.Enabled = False;
			ButtonDescription.DefaultButton = False;
		Else
			If Not ValueIsFilled(ButtonDescription.ToolTip) Then
				ButtonDescription.ToolTip = ButtonDescription.Title;
			EndIf;
		EndIf;
		// Registration with the Button prefix.
		StepDescription.Insert("Button" + ButtonName, ButtonDescription);
	EndDo;

	StepByStepAssistantSettings.Steps.Add(StepDescription);
EndProcedure

// Helper formation of a structure describing the action.
//
// Parameters:
//     ID    - String - Action identifier, see description of the AddMasterStep method.
//     HandlerName   - String - Name of the procedure, see description of the AddMasterStep method.
//     ServiceData  - Structure - Accumulates values.
//
// Returns - Structure - Service data with added fields.
&AtServer
Function AssistantStepAction(Val ID, Val HandlerName, ServiceData = Undefined)
	If ServiceData = Undefined Then
		ServiceData = New Structure;
	EndIf;
	ServiceData.Insert(ID, HandlerName);;
	Return ServiceData;
EndFunction

// Helper formation of a structure describing the assistant buttons.
//
// Returns:
//   Structure - Assistant buttons.
//       * Back  - Structure - Description of the Back button formed using the AssistantButton() method.
//       * Next  - Structure - Description of the Next button formed using the AssistantButton() method.
//       * Cancel - Structure - Description of the Cancel button generated by the AssistantButton method().
//
&AtServer
Function ButtonsAssistant()
	Result = New Structure("Next, Back, Cancel", AssistantButton(), AssistantButton(), AssistantButton());
	Result.Next.DefaultButton = True;
	Result.Next.Title = NStr("en='Next >';ru='Далее  >'");
	Result.Back.Title = NStr("en='< Back';ru='< Back'");
	Result.Cancel.Title = NStr("en='Cancel';ru='Отменить'");
	Return Result;
EndFunction

// Description of the assistant button settings.
//
// Returns:
//   Structure - Button of form settings.
//       * Title         - String - Button title.
//       * Tooltip         - String - ToolTip for button.
//       * Visible         - Boolean - If True, then the button is visible. Default value: True.
//       * Availability       - Boolean - If true, then you can click the button. Default value: True.
//       *DefaultButton - Boolean - If True, then the button will be the main button of a form. Value by default:
//                                      False.
//
// See also:
//   FormButton in the syntax-helper.
//
&AtServer
Function AssistantButton()
	Result = New Structure;
	Result.Insert("Title", "");
	Result.Insert("ToolTip", "");
	
	Result.Insert("Enabled", True);
	Result.Insert("Visible", True);
	Result.Insert("DefaultButton", False);
	
	Return Result;
EndFunction

// Sets an initial page for the first assistant launch.
//
// Parameters:
//     StartPage - Number, String, FormGroup - Number of a step, group-page, or its identifier.
//
&AtClient
Procedure SetAssistantInitialPage(Val Page)
	
	StepByStepAssistantSettings.StartPage = AssistantStepNumberByIdentifier(Page);
	
EndProcedure

// Launches the assistant from the step
// previously set using SetInitialMasterPage.
&AtClient
Procedure RunAssistant()
	
	If StepByStepAssistantSettings.StartPage = Undefined Then
		Raise NStr("en='Before launching the assistant, an initial page should be set.';ru='Перед запуском мастера должна быть установлена начальная страница.'");
		
	ElsIf StepByStepAssistantSettings.StartPage = -1 Then
		// Warming up. Check if all steps have action handlers.
		PossibleActions = New Structure("OnActivating, BeforeNextAction, BeforeBackAction, BeforeCancelAction, OnProcessWaiting");
		For Each StepDescription In StepByStepAssistantSettings.Steps Do
			For Each KeyValue In PossibleActions Do
				NameActions = KeyValue.Key;
				HandlerName = StepDescription[NameActions];
				If Not IsBlankString(HandlerName) Then
					Try
						Test = New NotifyDescription(HandlerName, ThisObject);
					Except
						Text = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='Error of %1 event handler creation for %2 page, %3 procedure is not defined';ru='Ошибка создания обработчика события %1 для страницы %2, не определена процедура %3'"),
							NameActions, 
							StepDescription.Page, 
							HandlerName
						);
						Raise Text;
					EndTry;
				EndIf;
			EndDo;
		EndDo;
		
		// Actual launch
		GoToAssistantStep(StepByStepAssistantSettings.CurrentStepNumber, True);
	Else
		// Everything is disabled by default
		Items[StepByStepAssistantSettings.ButtonNext].Visible  = False;
		Items[StepByStepAssistantSettings.ButtonBack].Visible  = False;
		Items[StepByStepAssistantSettings.ButtonCancel].Visible = False;
		
		// Deferred launch
		StepByStepAssistantSettings.CurrentStepNumber = StepByStepAssistantSettings.StartPage;
		StepByStepAssistantSettings.StartPage    = -1;
		AttachIdleHandler("RunAssistant", 0.1, True);
	EndIf;
EndProcedure

// Switches the assistant to the next or previous page.
//
// Parameters:
//     CommandCode - String - Action identifier, possible values are Next, Back or Cancel.
//
&AtClient
Procedure AssistantStep(Val CommandCode)
	
	If CommandCode = "Next" Then
		Direction = 1;
	ElsIf CommandCode = "Back" Then
		Direction = -1;
	ElsIf CommandCode = "Cancel" Then
		Direction = 0;
	Else
		Raise NStr("en='Incorrect command of the assistant step';ru='Некорректная команда шага помощника'");
	EndIf;
		
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	
	// Stop handler if any.
	If StepDescription.OnProcessWaiting <> Undefined Then
		DetachIdleHandler("AssistantPageIdleProcessing");
	EndIf;
	
	// Process the current page leaving.
	If Direction = 1 Then
		Action = StepDescription.BeforeNextAction;
		
	ElsIf Direction = -1 Then
		Action = StepDescription.BeforeBackAction;
		
	Else
		Action = StepDescription.BeforeCancelAction;
		
	EndIf;
	
	If IsBlankString(Action) Then
		AssistantStepEnd(Direction);
	Else
		Notification = New NotifyDescription(Action, ThisObject);
		ExecuteNotifyProcessing(Notification, Direction);
	EndIf;
EndProcedure

// Performs an unconditional positioning of assistant to a page.
//
// Parameters:
//     IdentifierStep   - Number, String, FormGroup - Number, group-page of a form or its name for transfer.
//     TriggerEvents - Boolean - The check box showing that the events connected with a step activation should be called.
//
&AtClient
Procedure GoToAssistantStep(Val IdentifierStep, Val TriggerEvents = False)
	NextStep = AssistantStepNumberByIdentifier(IdentifierStep);
	If NextStep = Undefined Then
		Error = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 assistant step is not found';ru='Не найден шаг помощника %1'"),
			IdentifierStep
		);
		Raise Error;
	EndIf;
		
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	
	// Stop handler if any.
	If StepDescription.OnProcessWaiting <> Undefined Then
		DetachIdleHandler("AssistantPageIdleProcessing");
	EndIf;
	
	// And launch a new page
	StepEndAssistantUnconditionally(NextStep, TriggerEvents);
EndProcedure

// Confirms the action of assistant step and invokes a page switch.
//
// Parameters:
//     StepParameters - Service attribute received in the handler before the action began.
//
&AtClient
Procedure AssistantStepEnd(Val StepParameters)
	NextStep = StepByStepAssistantSettings.CurrentStepNumber + StepParameters;
	LastStep = StepByStepAssistantSettings.Steps.UBound();
	
	If StepParameters = 0 Then
		// Confirm cancellation - do nothing.
		Return;
		
	ElsIf StepParameters = 1 AND NextStep > LastStep Then
		// You are trying to take a step outside forward.
		Raise NStr("en='You are trying to go out of the assistant last step.';ru='Попытка выхода за последний шаг мастера'");
		
	ElsIf StepParameters = -1 AND NextStep < 0 Then
		// You are trying to take a step outside back.
		Raise NStr("en='You are trying to go back from the assistant first step.';ru='Попытка выхода назад из первого шага мастера'");
		
	EndIf;
	
	StepEndAssistantUnconditionally(NextStep);
EndProcedure

&AtClient
Procedure StepEndAssistantUnconditionally(Val NextStep, Val TriggerEvents = True)
	StepDescription = StepByStepAssistantSettings.Steps[NextStep];
	LastStep = StepByStepAssistantSettings.Steps.UBound();
	
	// Swith to a new page.
	Items[StepByStepAssistantSettings.PagesGroup].CurrentPage = Items[StepDescription.Page];
	// Crawl the platform feature.
	MasterPagesGroup = Items[StepByStepAssistantSettings.PagesGroup];
	NewCurrentPage = Items[StepDescription.Page];
	GroupKindPage = FormGroupType.Page;
	TypeFormGroup    = Type("FormGroup");
	For Each Page In MasterPagesGroup.ChildItems Do
		If TypeOf(Page) = TypeFormGroup AND Page.Type = GroupKindPage Then
			Page.Visible = (Page = NewCurrentPage);
		EndIf;
	EndDo;
	
	// Update buttons
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonNext,  StepDescription.ButtonNext);
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonBack,  StepDescription.ButtonBack);
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonCancel, StepDescription.ButtonCancel);
	
	// Successfully transferred
	StepByStepAssistantSettings.CurrentStepNumber = NextStep;
	
	If TriggerEvents AND Not IsBlankString(StepDescription.OnActivating) Then
		// Process OnActivating of a new page, it will launch the waiting.
		AttachIdleHandler("AssistantPageActivationProcessor", 0.1, True);
		
	ElsIf Not IsBlankString(StepDescription.OnProcessWaiting) Then
		// Launch waiting handler if needed.
		AttachIdleHandler("AssistantPageIdleProcessing", 0.1, True);
		
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAssistantButtonProperties(Val ButtonName, Val Definition)
	
	AssistantButton = Items[ButtonName];
	FillPropertyValues(AssistantButton, Definition);
	AssistantButton.ExtendedTooltip.Title = Definition.ToolTip;
	
EndProcedure

&AtClient
Procedure AssistantPageActivationProcessor()
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	If Not IsBlankString(StepDescription.OnActivating) Then
		Notification = New NotifyDescription(StepDescription.OnActivating, ThisObject);
		ExecuteNotifyProcessing(Notification, Items[StepDescription.Page]);
	EndIf;
	
	// And launch waiting if needed.
	If Not IsBlankString(StepDescription.OnProcessWaiting) Then
		// First launch fast
		AttachIdleHandler("AssistantPageIdleProcessing", 0.1, True);
	EndIf;
EndProcedure

// It can be the number of a step, or a group-page, or its identifier.
&AtClient
Function AssistantStepNumberByIdentifier(Val IdentifierStep)
	ParameterType = TypeOf(IdentifierStep);
	If ParameterType = Type("Number") Then
		Return IdentifierStep;
	EndIf;
	
	SearchName = ?(ParameterType = Type("FormGroup"), IdentifierStep.Name, IdentifierStep);
	For StepNumber=0 To StepByStepAssistantSettings.Steps.UBound() Do
		If StepByStepAssistantSettings.Steps[StepNumber].Page = SearchName Then
			Return StepNumber;
		EndIf;
	EndDo;
	
	Raise StrReplace(NStr("en='Not found step ""%1"".';ru='Не найдено шаг ""%1"".'"), "%1", SearchName);
EndFunction

// Returns the cancel check box
&AtClient
Function AssistantPageIdleProcessing()
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	Action = StepDescription.OnProcessWaiting;
	If IsBlankString(Action) Then
		Return False;
	EndIf;
	
	Notification = New NotifyDescription(Action, ThisObject);
	
	Stop = False;
	ExecuteNotifyProcessing(Notification, Stop);
	ToContinueTo = Not Stop;
	
	If ToContinueTo Then
		AttachIdleHandler("AssistantPageIdleProcessing", StepByStepAssistantSettings.LongOperationWaitingTimeout, True);
	EndIf;
	
	Return ToContinueTo;
EndFunction

&AtClient
Procedure AfterTaskCancellationAndClosingFormConfirmation(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Abort Then
		CheckBackgroundJobAndCloseFormWithoutConfirmation();
	Else
		AssistantPageIdleProcessing();
	EndIf;
EndProcedure

&AtClient
Procedure CheckBackgroundJobAndCloseFormWithoutConfirmation()
	If Not BackgroundJobImportOnClient(True, False) Then
		StepByStepAssistantSettings.HasJobCancellationConfirmation = True;
		Close();
	EndIf;
EndProcedure

&AtClient
Function BackgroundJobImportOnClient(InterruptIfNotCompleted, ShowDialogBeforeClosing)
	
	DetachIdleHandler("AssistantPageIdleProcessing");
	
	InformationAboutJob = BackgroundJobImportResult(InterruptIfNotCompleted);
	If Not InformationAboutJob.Completed Then
		If ShowDialogBeforeClosing Then
			Handler = New NotifyDescription("AfterTaskCancellationAndClosingFormConfirmation", ThisObject);
			
			If StepByStepAssistantSettings.ProcedureName = "BackgroundDuplicatesSearch" Then
				QuestionText = NStr("en='Stop the duplicates search and close the form?';ru='Прервать поиск дублей и закрыть форму?'");
			ElsIf StepByStepAssistantSettings.ProcedureName = "DuplicatesBackgroundDeletetion" Then
				QuestionText = NStr("en='Stop the duplicates deletion and close the form?';ru='Прервать удаление дублей и закрыть форму?'");
			EndIf;
			
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Abort, NStr("en='Break';ru='Прервать'"));
			Buttons.Add(DialogReturnCode.No, NStr("en='Do not interrupt';ru='Не прерывать'"));
			
			ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
		EndIf;
		Return False;
	EndIf;
	
	If StepByStepAssistantSettings.ProcedureName = "BackgroundDuplicatesSearch" Then
		// See the execution result.
		ErrorDescription = Undefined;
		If InformationAboutJob.ErrorInfo <> Undefined Then
			ErrorDescription = InformationAboutJob.ErrorInfo;
		ElsIf InformationAboutJob.Result = -1 Then
			ErrorDescription = FoundDuplicatesStatusDescription;
		EndIf;
		
		If ErrorDescription = Undefined Then
			If InformationAboutJob.Result <> Undefined AND InformationAboutJob.Result > 0 Then
				// Some duplicates are found
				AssistantStep("Next");
			Else
				// Duplicates by the current settings are not found.
				GoToAssistantStep(Items.DuplicateStepIsNotFound, True);
			EndIf;
		Else
			ShowMessageBox(, ErrorDescription );
			GoToAssistantStep(Items.StepSearchWasNotRun, True);
		EndIf;
	ElsIf StepByStepAssistantSettings.ProcedureName = "DuplicatesBackgroundDeletetion" Then
		If InformationAboutJob.ErrorInfo = Undefined Then
			// Successfully executed, data is generated and replaced to attributes.
			If InformationAboutJob.Result = True Then
				// All duplicates groups are successfully replaced.
				AssistantStep("Next");
			Else
				// Failed to substitute all usage places.
				GoToAssistantStep(Items.StepFailedReplacements, True);
			EndIf;
		Else
			// Background job is complete with an error.
			ShowMessageBox(, InformationAboutJob.ErrorInfo);
			GoToAssistantStep(Items.StepSearchWasNotRun, True);
		EndIf;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function BackGroundJobStart(Val ProcedureName)
	// Cancel the previous job.
	BackgroundJobCancel();
	
	// Define start parameters.
	MethodParameters = New Structure;
	MethodParameters.Insert("FullObjectName", "Processing.SearchAndDeleteDuplicates");
	MethodParameters.Insert("ProcedureName", ProcedureName);
	
	If ProcedureName = "BackgroundDuplicatesSearch" Then
		
		MethodName = NStr("en='Search and delete duplicates: Search duplicates';ru='Поиск и удаление дублей: Поиск дублей'");
		
		MethodParameters.Insert("DuplicateSearchArea",     DuplicateSearchArea);
		MethodParameters.Insert("MaxDuplicatesQuantity", 1500);
		
		SearchRulesArray = New Array;
		For Each Rule In SearchRules Do
			SearchRulesArray.Add(New Structure("Attribute, Rule", Rule.Attribute, Rule.Rule));
		EndDo;
		MethodParameters.Insert("SearchRules", SearchRulesArray);
		
		MethodParameters.Insert("ConsiderAppliedRules", ConsiderAppliedRules);
		
		// Pass a schema as a template schema, a separate background session will be used.
		MethodParameters.Insert("CompositionSchema", GetFromTempStorage(SchemaURLComposition));
		MethodParameters.Insert("PreSelectionLinkerSettings", ComposerPreFilter.Settings);
		
	ElsIf ProcedureName = "DuplicatesBackgroundDeletetion" Then
		
		MethodName = NStr("en='Search and delete duplicates: Delete duplicates';ru='Поиск и удаление дублей: Удаление дублей'");
		
		MethodParameters.Insert("RemovalMethod", "Check");
		MethodParameters.Insert("SubstitutionsPairs", DuplicatesSubstitutionsPairs());
		
	Else
		
		Return False;
		
	EndIf;
	
	// Start.
	ErrorInfo = Undefined;
	Try
		Task = LongActions.ExecuteInBackground(
			UUID,
			"LongActions.ExecuteReportOrDataProcessorCommand",
			MethodParameters,
			MethodName);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		StepByStepAssistantSettings.JobCompleted               = True;
		StepByStepAssistantSettings.ErrorInfo             = DetailErrorDescription(ErrorInfo);
		StepByStepAssistantSettings.BackgroundJobID   = Undefined;
		StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
		StepByStepAssistantSettings.ProcedureName                   = Undefined;
		Return False;
	EndIf;
	
	StepByStepAssistantSettings.BackgroundJobResultAddress = Task.StorageAddress;
	StepByStepAssistantSettings.BackgroundJobID   = Task.JobID;
	StepByStepAssistantSettings.JobCompleted               = Task.JobCompleted;
	StepByStepAssistantSettings.ProcedureName                   = ProcedureName;
	
	If StepByStepAssistantSettings.JobCompleted Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function BackgroundJobImportResult(Val InterruptIfNotCompleted = False)
	If StepByStepAssistantSettings.JobCompleted Then
		StepByStepAssistantSettings.BackgroundJobID = Undefined;
	Else
		Task = BackgroundJobs.FindByUUID(StepByStepAssistantSettings.BackgroundJobID);
		If Task <> Undefined Then
			If Task.ErrorInfo <> Undefined Then
				StepByStepAssistantSettings.ErrorInfo = DetailErrorDescription(Task.ErrorInfo);
			EndIf;
			StepByStepAssistantSettings.JobCompleted = Task.State <> BackgroundJobState.Active;
		EndIf;
	EndIf;
	
	Value = Undefined;
	If StepByStepAssistantSettings.JobCompleted Then
		If StepByStepAssistantSettings.ErrorInfo = Undefined Then
			Value = GetFromTempStorage(StepByStepAssistantSettings.BackgroundJobResultAddress);
			If StepByStepAssistantSettings.ProcedureName = "BackgroundDuplicatesSearch" Then
				Value = FillDuplicatesSearchResults(Value);
			ElsIf StepByStepAssistantSettings.ProcedureName = "DuplicatesBackgroundDeletetion" Then
				Value = FillDuplicatesDeletetionResults(Value);
			EndIf;
		EndIf;
		StepByStepAssistantSettings.BackgroundJobID = Undefined;
		StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
	EndIf;
	
	If InterruptIfNotCompleted AND Not StepByStepAssistantSettings.JobCompleted Then
		BackgroundJobCancel();
	EndIf;
	
	InformationAboutJob = New Structure;
	InformationAboutJob.Insert("Completed",          StepByStepAssistantSettings.JobCompleted);
	InformationAboutJob.Insert("ErrorInfo", StepByStepAssistantSettings.ErrorInfo);
	InformationAboutJob.Insert("Result",          Value);
	
	Return InformationAboutJob;
EndFunction

&AtServer
Procedure BackgroundJobCancel()
	If StepByStepAssistantSettings.BackgroundJobID <> Undefined Then
		LongActions.CancelJobExecution(StepByStepAssistantSettings.BackgroundJobID);
	EndIf;
	StepByStepAssistantSettings.JobCompleted               = False;
	StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
	StepByStepAssistantSettings.ErrorInfo             = Undefined;
	StepByStepAssistantSettings.BackgroundJobID   = Undefined;
EndProcedure

#EndRegion