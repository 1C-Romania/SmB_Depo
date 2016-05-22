
#Region ServiceProceduresAndFunctions

//:::CommonUse

&AtServer
Procedure GetTabularDocumentTemplate(SpreadsheetDocument)
	Var Manager;
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	SpreadsheetDocument = Manager.GetTemplate(Parameters.DataLoadSettings.DataImportTemplate_mxl);
	
EndProcedure

&AtClient
Procedure FillImportSampleFileData(FileData, Extension)
	
	If Extension = "xlsx" Then
		
		Address = Parameters.DataLoadSettings.DataImportTemplate_xlsx;
		
	ElsIf Extension = "csv" Then
		
		Address = Parameters.DataLoadSettings.DataImportTemplate_csv;
		
	EndIf;
	
	FileDescriptionWithoutExtension = NStr("en = 'DataImportTemplate'");
	
	FileData.Insert("ModificationDateUniversal",CurrentDate());
	FileData.Insert("Encrypted", 					False);
	FileData.Insert("FileName",					FileDescriptionWithoutExtension + "." + Extension);
	FileData.Insert("Description",				FileDescriptionWithoutExtension);
	FileData.Insert("RelativePath",			"LD\"); //ImportData
	FileData.Insert("DigitallySigned",					False);
	FileData.Insert("Size",						Undefined);
	FileData.Insert("Extension",					Extension);
	FileData.Insert("IsEditing",					Undefined);
	FileData.Insert("FileBinaryDataRef", Address);
	FileData.Insert("FileCurrentUserIsEditing", False);
	FileData.Insert("FileIsEditing",			False);
	
EndProcedure

&AtClient
Procedure OpenSample(Extension)
	
	If Extension = "mxl" Then
		
		SpreadsheetDocument = Undefined;
		GetTabularDocumentTemplate(SpreadsheetDocument);
		If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
			
			ObjectAreas = New ValueList;
			PrintedFormIdentifier = Parameters.DataLoadSettings.FillingObjectFullName;
			
			PrintFormsCollection = PrintManagementClient.NewPrintedFormsCollection(PrintedFormIdentifier);
			PrintForm = PrintManagementClient.PrintFormDescription(PrintFormsCollection, PrintedFormIdentifier);
			PrintForm.TemplateSynonym = NStr("en = 'Template of the prepared data in the mxl format'");
			PrintForm.SpreadsheetDocument = SpreadsheetDocument;
			PrintForm.FileNamePrintedForm = NStr("en = 'Template of the prepared data in the mxl format'");
			
			PrintManagementClient.PrintingDocuments(PrintFormsCollection, ObjectAreas);
			
		EndIf;
		
	Else
		
		FileData = New Structure;
		FillImportSampleFileData(FileData, Extension);
		
		AttachedFilesClient.OpenFile(FileData, False);
		
	EndIf;
	
EndProcedure

&AtClient
Function ReceiveTitleArea()
	
	TitleArea = Items.SpreadsheetDocument.CurrentArea;
	If TitleArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then // missed, highlighted column
		
		TitleArea = SpreadsheetDocument.Area("R1" + TitleArea.Name);
		
	EndIf;
	
	Return TitleArea;
	
EndFunction

&AtClient
Procedure SpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Columns 
		OR Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
		
		If TypeOf(Details) = Type("ValueList") Then
			
			NotifyDescription = New NotifyDescription("ColumnTitleDetailsDataProcessor", ThisObject);
			
			TitleArea = ReceiveTitleArea();
			
			ImportParameters = New Structure;
			ImportParameters.Insert("FillingObjectFullName", Parameters.DataLoadSettings.FillingObjectFullName);
			ImportParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			ImportParameters.Insert("FieldPresentation", TitleArea.Text);
			ImportParameters.Insert("FieldName", TitleArea.DetailsParameter);
			
			OpenForm("DataProcessor.DataImportFromExternalSources.Form.FieldChoice", ImportParameters, ThisObject, , , , NotifyDescription);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillMatchTableFilterChoiceList(IsTabularSectionImport)
	
	If Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en ='FilterNoErrors'"),	NStr("en ='Data ready for import'"));
		Items.FilterComparisonTable.ChoiceList.Insert(2, NStr("en ='FilterErrors'"), 	NStr("en ='Data impossible to be imported'"));
		
	Else
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en ='Mapped'"), NStr("en ='Data matched successfully'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en ='WillBeCreated'"), NStr("en ='Data without any match in the application'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en ='Inconsistent'"), NStr("en ='Data that contains the error (not filled in completely)'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDecorationTitleTextUnmatchedRows()
	
	If CreateIfNotMatched Then
		
		HeaderText = ?(Parameters.DataLoadSettings.IsCatalogImport, 
			NStr("en ='new items will be created:'"), 
			NStr("en ='new records will be created:'"));
		
	Else
		
		HeaderText = NStr("en ='rows will be skipped:'");
		
	EndIf;
	
	ItemName = ?(Parameters.DataLoadSettings.IsCatalogImport, "DecorationUnmatchedRowsHeaderObject", "DecorationUnmatchedRowsHeaderIR");
	
	Items[ItemName].Title = HeaderText;
	
EndProcedure

&AtClient
Procedure SetMatchedObjectsDecorationTitleText()
	
	TitleText = ?(UpdateExisting,
		NStr("en = 'among them are matched and will be updated'"),
		NStr("en = 'among them matched'"));
		
	ItemName = ?(Parameters.DataLoadSettings.IsCatalogImport, "DecorationMatchedHeaderObject", "DecorationMatchedHeaderIR");
	
	Items[ItemName].Title = TitleText;
	
EndProcedure

&AtServer
Procedure ChangeConditionalDesignText()
	
	DataImportFromExternalSourcesOverridable.ChangeConditionalDesignText(ThisObject.ConditionalAppearance, Parameters.DataLoadSettings);
	
EndProcedure

&AtServer
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress)
	
	CheckResult = New Structure("JobComplete, Value", False, Undefined);
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		CheckResult.JobCompleted	= True;
		SpreadsheetDocument					= GetFromTempStorage(BackgroundJobStorageAddress);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

&AtClient
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress);
	If CheckResult.JobCompleted Then
		
		ChangeGoToNumber(+1);
		
	Else	
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure

//:::PageFileSelection

&AtServer
Procedure DefinePageItemsVisible()
	Var ItemVisible;
	
	ShowSamplesTitle = False;
	Parameters.DataLoadSettings.Property("DataImportTemplate_csv", ItemVisible);
	CommonUseClientServer.SetFormItemProperty(Items, "FormatSample_csv", "Visible", Not IsBlankString(ItemVisible));
	ShowSamplesTitle = Not IsBlankString(ItemVisible);
	
	Parameters.DataLoadSettings.Property("DataImportTemplate_mxl",ItemVisible);
	CommonUseClientServer.SetFormItemProperty(Items, "FormatSample_mxl", "Visible", Not IsBlankString(ItemVisible));
	ShowSamplesTitle = ShowSamplesTitle OR Not IsBlankString(ItemVisible);
	
	Parameters.DataLoadSettings.Property("DataImportTemplate_xlsx",ItemVisible);
	CommonUseClientServer.SetFormItemProperty(Items, "FormatSample_xlsx", "Visible", Not IsBlankString(ItemVisible));
	ShowSamplesTitle = ShowSamplesTitle OR Not IsBlankString(ItemVisible);
	
	CommonUseClientServer.SetFormItemProperty(Items, "HeaderExamples", "Visible", ShowSamplesTitle);
	
EndProcedure

//:::PageDataImport

&AtServer
Procedure ImportFileWithDataToTabularDocumentOnServer(GoToNext)
	
	Extension = CommonUseClientServer.ExtensionWithoutDot(CommonUseClientServer.GetFileNameExtension(NameOfSelectedFile));
	
	TempFileName	= GetTempFileName(Extension);
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	If BinaryData = Undefined Then
		
		Return;
		
	Else
		
		BinaryData.Write(TempFileName);
		
	EndIf;
	
	SpreadsheetDocument.Clear();
	DataMatchingTable.Clear();
	
	ServerCallParameters = New Structure;
	ServerCallParameters.Insert("TempFileName",	TempFileName);
	ServerCallParameters.Insert("Extension", 			Extension);
	ServerCallParameters.Insert("SpreadsheetDocument",	SpreadsheetDocument);
	ServerCallParameters.Insert("FillingObjectFullName", Parameters.DataLoadSettings.FillingObjectFullName);
	
	If CommonUse.FileInfobase() Then
		
		DataImportFromExternalSources.ImportData(ServerCallParameters, TemporaryStorageAddress);
		SpreadsheetDocument = GetFromTempStorage(TemporaryStorageAddress);
		
	Else
		
		MethodName = "DataImportFromExternalSources.ImportData";
		Description = NStr("en = 'The ImportDataFromExternalSource subsystem: Execution of the server method import data from file'");
		
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, MethodName, ServerCallParameters, Description);
		If BackgroundJobResult.JobCompleted Then
			
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			SpreadsheetDocument = GetFromTempStorage(BackgroundJobStorageAddress);
			
		Else 
			
			GoToNext = False;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(GoToNext)
	
	DataProcessors.DataImportFromExternalSources.AddMatchTableColumns(ThisObject, DataMatchingTable, Parameters.DataLoadSettings);
	ImportFileWithDataToTabularDocumentOnServer(GoToNext);
	
EndProcedure

//:::PagesDataCheck

&AtServer
Procedure CheckReceivedData(SkipPage, DenyTransitionNext)
	
	DataProcessors.DataImportFromExternalSources.PreliminarilyDataProcessor(SpreadsheetDocument, DataMatchingTable, Parameters.DataLoadSettings, SpreadsheetDocumentMessages, SkipPage, DenyTransitionNext);
	
EndProcedure

//:::PageMatch

&AtServer
Procedure CheckDataCorrectnessInTableRow(RowFormID)
	Var Manager;
	
	FormTableRow = DataMatchingTable.FindByID(RowFormID);
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	Manager.CheckDataCorrectnessInTableRow(FormTableRow, Parameters.DataLoadSettings.FillingObjectFullName);
	
EndProcedure

&AtClient
Procedure SetRowsQuantityDecorationText()
	
	TableRowCount		= DataMatchingTable.Count();
	RowsQuantityWithoutErrors	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	If Not Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		UnmatchedData = DataMatchingTable.FindRows(New Structure("_RowMatched", False)).Count();
		InconsistentData = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
		
	EndIf;
	
	NewHeader 				= "";
	
	If FilterComparisonTable = "WithoutFilter" Then 
		
		NewHeader = NStr("en ='Total number of rows in table .......... %1'");
		ParameterValue = TableRowCount;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then 
		
		NewHeader = NStr("en ='Rows with data that could be imported to the application .......... %1'");
		ParameterValue = RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "FilterErrors" Then 
		
		NewHeader = NStr("en ='Rows that contain errors and prevent data import .......... %1'");
		ParameterValue = TableRowCount - RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "Mapped" Then 
		
		If UpdateExisting Then
			
			NewHeader = NStr("en ='Data that corresponds to the application items and will be updated .......... %1'");
			
		Else
			
			NewHeader = NStr("en ='Data that corresponds to the application items .......... %1'");
			
		EndIf;
		
		ParameterValue = TableRowCount - UnmatchedData;
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then 
		
		NewHeader = NStr("en ='Data failed to be matched .......... %1'");
		ParameterValue = UnmatchedData;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then 
		
		NewHeader = NStr("en ='Rows that contain an error or are filled in incompletely .......... %1'");
		ParameterValue = InconsistentData;
		
	EndIf;
	
	NewHeader = StringFunctionsClientServer.PlaceParametersIntoString(NewHeader, ParameterValue);
	Items.DecorationLineCount.Title = NewHeader;
	
EndProcedure

&AtClient
Procedure SetRowsFilterByFilterValue()
	
	If FilterComparisonTable = "WithoutFilter" Then
		
		Items.DataMatchingTable.RowFilter = Undefined;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, True);
		
	ElsIf FilterComparisonTable = "FilterErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, False);
		
	ElsIf FilterComparisonTable = "Mapped" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_RowMatched", True);
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then
		
		If Parameters.DataLoadSettings.IsCatalogImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		EndIf;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_ImportToApplicationPossible", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportedDataComparison()
	Var Manager;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DataLoadSettings", Parameters.DataLoadSettings);
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	Manager.MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters);
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var Manager;
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	Manager.OnDefineDataImportSamples(Parameters.DataLoadSettings, UUID);
	DataImportFromExternalSourcesOverridable.PredefineDataImportSamples(Parameters.DataLoadSettings, UUID);
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	UpdateExisting 		= False;
	CreateIfNotMatched = True;
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", 		UpdateExisting);
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched",	CreateIfNotMatched);
	
	CommonUseClientServer.SetFormItemProperty(Items, "AnotherWayToImportData", "Visible", Parameters.DataLoadSettings.UseTogether);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	FillMatchTableFilterChoiceList(Parameters.DataLoadSettings.IsTabularSectionImport);
	
	SetDecorationTitleTextUnmatchedRows();
	SetMatchedObjectsDecorationTitleText();
	
	// Set the current table of transitions
	TableOfGoToByScript();
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure FilterComparisonTableOnChange(Item)
	
	SetRowsFilterByFilterValue();
	SetRowsQuantityDecorationText();
	
	ThisForm.CurrentItem = Items.DataMatchingTable;
	
EndProcedure

&AtClient
Procedure CreateIfNotMatchedOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	
	SetDecorationTitleTextUnmatchedRows();
	
	ChangeConditionalDesignText();
	
EndProcedure

&AtClient
Procedure DataMatchingTableOnChange(Item)
	
	RowFormID = Items.DataMatchingTable.CurrentData.GetID();
	CheckDataCorrectnessInTableRow(RowFormID);
	SetRowsQuantityDecorationText();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	Step = -1;
	If Items.MainPanel.CurrentPage = Items.PagePreliminarilyTS
		OR Items.MainPanel.CurrentPage = Items.PagePreliminaryCatalog
		OR Items.MainPanel.CurrentPage = Items.PagePreliminarilyInformationRegister Then
		
		Step = -2;
		
	EndIf;
	
	ChangeGoToNumber(Step);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	
	ClosingResult = New Structure;
	ClosingResult.Insert("ActionsDetails",				"ProcessPreparedData");
	ClosingResult.Insert("DataMatchingTable",	DataMatchingTable);
	ClosingResult.Insert("DataLoadSettings",		Parameters.DataLoadSettings);
	
	NotifyChoice(ClosingResult);
	Notify("ProcessPreparedData", ClosingResult);
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ImportDataWithOtherMethodClick(Item)
	
	ClosingResult = New Structure;
	ClosingResult.Insert("ActionsDetails", "ChangeDataImportFromExternalSourcesMethod");
	
	Close(ClosingResult);
	
EndProcedure

&AtClient
Procedure ChooseExternalFile(Command)
	
	NotifyDescription = New NotifyDescription("SelectExternalFileDataProcessorEnd", ThisObject);
	BeginPutFile(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure FormatSample_csv(Command)
	
	OpenSample("csv");
	
EndProcedure

&AtClient
Procedure FormatSample_mxl(Command)
	
	OpenSample("mxl");
	
EndProcedure

&AtClient
Procedure FormatSample_xlsx(Command)
	
	OpenSample("xlsx");
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WithoutFilter(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WithoutFilter");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WillBeCreated(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WillBeCreated");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_InconsistentData(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Inconsistent");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterNoErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterNoErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_Mapped(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Mapped");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnSetGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure ClearCommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnClearGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure UpdateExistingOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", UpdateExisting);
	
	SetMatchedObjectsDecorationTitleText();
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
Procedure SelectExternalFileDataProcessorEnd(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		
		TemporaryStorageAddress= Address;
		NameOfSelectedFile 		= FileName;
		Extension 				= CommonUseClientServer.ExtensionWithoutDot(CommonUseClientServer.GetFileNameExtension(NameOfSelectedFile));
		
		If Extension = "xlsx"  Then
			
			ChangeGoToNumber(+1);
			
		ElsIf Extension = "mxl" OR Extension = "csv" Then
			
			ChangeGoToNumber(+1);
			
		Else
			
			WarningText = NStr("en ='Data import from files of a given type is not supported.'");
			ShowMessageBox(, WarningText); 
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ColumnTitleDetailsDataProcessor(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		TitleArea = ReceiveTitleArea();
		
		TitleArea.Text 					= Result.Presentation;
		TitleArea.DetailsParameter	= Result.Value;
		
		If Result.Property("CancelSelectionInColumn") Then
			
			TitleArea 						= SpreadsheetDocument.Area("R1C" + Result.CancelSelectionInColumn);
			TitleArea.Text 					= "Not to import";
			TitleArea.DetailsParameter	= "";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions_SuppliedPart

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying has not been defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying has not been defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying has not been defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds
//  to the current MainPageName transition step (mandatory) - String. Name of the MainPanel panel page that corresponds
//  to the current number of the NavigationPageName transition (mandatory) - String. Name of the NavigationPanel panel page that corresponds
//  to the current HandlerNameOnOpen transition number (optional) - String. Name of the function-processor of the
//  HandlerNameOnGoingNext assistant current page open event (optional) - String. Name of the function-processor of the HandlerNameOnGoingBack
//  transition to the next assistant page event (optional) - String. Name of the function-processor of the LongOperation
//  transition to assistant previous page event (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtClient
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item IN FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ConnectedTransitionEventHandlers

//:::PageFileSelection

&AtClient
Function Attachable_PageFileSelection_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	Var CheckStructure;
	
	DefinePageItemsVisible();
	
EndFunction

//:::PageDataImport

&AtClient
Function Attachable_PageDataImport_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = True;
	ExecuteDataImportAtServer(GoToNext);
	If Not GoToNext Then
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndFunction

//:::PagesDataCheck

&AtClient
Function Attachable_PagesDataCheck_OnOpen(Cancel, SkipPage, Val IsGoNext)
	Var Errors;
	
	If Not IsGoNext Then
		
		SkipPage = True;
		Return Undefined;
		
	EndIf;
	
	DenyTransitionNext = False;
	CheckReceivedData(SkipPage, DenyTransitionNext);
	
	If SkipPage Then
		
		Return Undefined;
		
	ElsIf DenyTransitionNext Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", False);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PagesDataCheck_OnGoBack(Cancel)
	
	CommonUseClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", True);
	
EndFunction

//:::PageMatch

&AtClient
Function Attachable_PageMatching_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If IsGoNext = True Then
		
		ExportedDataComparison();
		SkipPage = True;
		
	Else
		
		SetRowsFilterByFilterValue();
		SetRowsQuantityDecorationText();
		
		ThisForm.CurrentItem = Items.DataMatchingTable;
		
	EndIf;
	
EndFunction

//:::ImportSettingPage

&AtClient
Function Attachable_PagePreliminarilyTS_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	AddPossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	AddImpossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
	
	Items.DecorationWillBeImportedCount.Title = String(AddPossible);
	Items.DecorationWillBeSkippedCount.Title = String(AddImpossible);
	
EndFunction

&AtClient
Function Attachable_PagePreliminaryCatalog_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData 		= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched	= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCount.Title = ReceivedData;
	Items.DecorationMatchedCountObject.Title = DataMatched;
	Items.DecorationUnmatchedRowsCountObject.Title = ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountObjects.Title = ReceivedData - ConsistentData;
	
EndFunction

&AtClient
Function Attachable_PagePreliminarilyRR_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData 		= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched	= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCountRS.Title = ReceivedData;
	Items.DecorationMatchedCountIR.Title = DataMatched;
	Items.DecorationUnmatchedRowsCountIR.Title = ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountIR.Title = ReceivedData - ConsistentData;
	
EndFunction

#EndRegion

#Region TableOfGoToByScript

// Procedure defines scripted transitions table No1.
// To fill transitions table, use TransitionsTableNewRow()procedure
//
&AtClient
Procedure TableOfGoToByScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "PageFileSelection",				"NavigationPageStart", , "PageFileSelection_OnOpen");
	GoToTableNewRow(2, "PageDataImport",			"NavigationPageWait",,,,, True, "PageDataImport_LongOperationProcessing");
	GoToTableNewRow(3, "PagesReceivedData",			"NavigationPageContinuation",,, );
	GoToTableNewRow(4, "PagesDataCheck",			"NavigationPageContinuation", , "PagesDataCheck_OnOpen", , "PagesDataCheck_OnGoBack");
	GoToTableNewRow(5, "PageMatching",				"NavigationPageContinuation", , "PageMatching_OnOpen");
	
	If Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyTS",		"NavigationPageEnd", , "PagePreliminarilyTS_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsCatalogImport Then
		
		GoToTableNewRow(6, "PagePreliminaryCatalog",	"NavigationPageEnd", , "PagePreliminaryCatalog_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyInformationRegister", "NavigationPageEnd", , "PagePreliminarilyPC_OnOpen");
		
	EndIf;
	
EndProcedure

#EndRegion
