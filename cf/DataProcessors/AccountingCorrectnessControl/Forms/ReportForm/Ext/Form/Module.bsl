
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProcessTranscriptions = Parameters.ProcessTranscriptions;
	
	If Parameters.ReportKind = "MutualSettlements" Then
		ThisForm.Title = "Accounting assistant: settlements";
		OutputReportSettlements();
	ElsIf Parameters.ReportKind = "WriteOffsInconsistenciesToSpecifications" Then
		ThisForm.Title = "Accounting assistant: mismatches of actual writeoffs to specifications";
		OutputMismatchesWriteoffsToSpecifications();
	ElsIf Parameters.ReportKind = "SuggestedProductionSpecifications" Then
		ThisForm.Title = "Accounting assistant: offered specifications to set to tab. Products part";
		OutputOfferedSpecification();
	ElsIf Parameters.ReportKind = "PurchasePricesAnalysis" Then
		ThisForm.Title = "Accounting assistant: purchase prices analysis";
		OutputPurchasePricesAnalysis();
	ElsIf Parameters.ReportKind = "ExchangeDifferences" Then
		ThisForm.Title = "Accounting assistant: exchange rates differences";
		OutputCurrencyRatesDifferences();
	ElsIf Parameters.ReportKind = "CashFlowItems" Then
		ThisForm.Title = "Accounting assistant: document list over a period";
		OutputCashFlowItems();
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

// Procedure - handler of the DecryptionProcessor event of the DocumentResult tabular document.
//
&AtClient
Procedure ResultProcessingTranscriptionsDocument(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If ProcessTranscriptions Then
		
		ValueDetails = ReceiveDecryptionValue(Details);
		
		If ValueIsFilled(ValueDetails) Then
			ShowValue(Undefined, ValueDetails);
		EndIf;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF GENERATING AND OUTPUTTING REPORTS

// Generates and outputs a report on settlements.
//
&AtServer
Procedure OutputReportSettlements()

	ReportSettlementsObject = Reports.MutualSettlements.Create();
	CompositionSchema = ReportSettlementsObject.DataCompositionSchema;
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	CompositionSettings.DataParameters.SetParameterValue("BeginOfPeriod", Parameters.BeginOfPeriod);
	CompositionSettings.DataParameters.SetParameterValue("EndOfPeriod", EndOfDay(Parameters.EndOfPeriod));
	
	CompositionSettings.OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.Output);
	CompositionSettings.OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.Output);
	CompositionSettings.OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.Output);
	
	FilterItem = CompositionSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Counterparty");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Parameters.CounterpartyRef;
	FilterItem.Use = True;
	
	FilterItem = CompositionSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Company");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Parameters.Company;
	FilterItem.Use = True;
	
	CompositionSettings.Structure.Clear();
	
	GroupingCounterpatry = CompositionSettings.Structure.Add(Type("DataCompositionGroup"));
	GroupingCounterpatry.Use = True;
	FieldCounterparty = GroupingCounterpatry.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	FieldCounterparty.Use = True;
	FieldCounterparty.Field = New DataCompositionField("Counterparty");
	SelectedFieldsForCounterparty = GroupingCounterpatry.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	
	CurrencyGrouping = CompositionSettings.Structure[0].Structure.Add(Type("DataCompositionGroup"));
	CurrencyGrouping.Use = True;
	FieldCurrency = CurrencyGrouping.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	FieldCurrency.Use = True;
	FieldCurrency.Field = New DataCompositionField("Currency");
	SelectedFieldsForCurrency = CurrencyGrouping.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	GroupingContract = CompositionSettings.Structure[0].Structure[0].Structure.Add(Type("DataCompositionGroup"));
	GroupingContract.Use = True;
	FieldCatalog = GroupingContract.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	FieldCatalog.Use = True;
	FieldCatalog.Field = New DataCompositionField("Contract");
	SelectedFieldsForContract = GroupingContract.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	GroupingOrder = CompositionSettings.Structure[0].Structure[0].Structure[0].Structure.Add(Type("DataCompositionGroup"));
	GroupingOrder.Use = True;
	FieldOrder = GroupingOrder.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	FieldOrder.Use = True;
	FieldOrder.Field = New DataCompositionField("Order");
	SelectedFieldsForOrder = GroupingOrder.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	GroupingSettlementsType = CompositionSettings.Structure[0].Structure[0].Structure[0].Structure[0].Structure.Add(Type("DataCompositionGroup"));
	GroupingSettlementsType.Use = True;
	SettlementsTypeField = GroupingSettlementsType.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	SettlementsTypeField.Use = True;
	SettlementsTypeField.Field = New DataCompositionField("SettlementsType");
	SelectedFieldsForSettlementsType = GroupingSettlementsType.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));	
	
	GroupingDocument = CompositionSettings.Structure[0].Structure[0].Structure[0].Structure[0].Structure[0].Structure.Add(Type("DataCompositionGroup"));
	GroupingDocument.Use = True;
	FieldDocument = GroupingDocument.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	FieldDocument.Use = True;
	FieldDocument.Field = New DataCompositionField("Document");
	SelectedFieldsForDocument = GroupingDocument.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	GroupingRegistrar = CompositionSettings.Structure[0].Structure[0].Structure[0].Structure[0].Structure[0].Structure[0].Structure.Add(Type("DataCompositionGroup"));
	GroupingRegistrar.Use = True;
	RegisterField = GroupingRegistrar.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	RegisterField.Use = True;
	RegisterField.Field = New DataCompositionField("Recorder");
	SelectedFieldsForRegistar = GroupingRegistrar.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	
	DetailsData = New DataCompositionDetailsData;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);

EndProcedure

// Generates and outputs a report on mismatches of actual writeoffs to specifications
//
&AtServer
Procedure OutputMismatchesWriteoffsToSpecifications()
	
	DifferencesTable = FormDataToValue(Parameters.DifferencesTable, Type("ValueTable"));
	DifferencesTable.Columns.Add("DocumentRef");
	
	For Each TableRow IN DifferencesTable Do
		TableRow.DocumentRef = Parameters.DocumentRef;	
	EndDo; 

	CompositionSchema = FormAttributeToValue("Object").GetTemplate("WriteOffsInconsistenciesToSpecifications");
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("ExternalDataTable", DifferencesTable);
	
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	DetailsData = New DataCompositionDetailsData;
	
	CompositionSettings.OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.Output);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);

EndProcedure

// Outputs a listing of offered specifications by the InventoryAssembly specified document
//
&AtServer
Procedure OutputOfferedSpecification()

	CompositionSchema = FormAttributeToValue("Object").GetTemplate("SuggestedProductionSpecifications");
	
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	DetailsData = New DataCompositionDetailsData;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionTemplate.ParameterValues["DocumentRef"].Value = Parameters.DocumentRef;
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ,DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);

EndProcedure

// Generates and outputs a report on history of purchase prices to define products and services.
// 
&AtServer
Procedure OutputPurchasePricesAnalysis()
	
	DataTable = GetFromTempStorage(Parameters.AddressInStorage);
	
	CompositionSchema = FormAttributeToValue("Object").GetTemplate("PurchasePricesAnalysis");
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("ExternalDataTable", DataTable);
	
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	CompositionSettings.OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.Output);
	
	DetailsData = New DataCompositionDetailsData;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);

EndProcedure

// Generates and outputs a record containing documents in
// which errors on exchange rates differences were found.
//
&AtServer
Procedure OutputCurrencyRatesDifferences()
	
	DataTable = GetFromTempStorage(Parameters.AddressInStorage);
	
	CompositionSchema = FormAttributeToValue("Object").GetTemplate("ExchangeDifferences");
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("ExternalDataTable", DataTable);
	
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	CompositionSettings.OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.Output);
	
	DetailsData = New DataCompositionDetailsData;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);

EndProcedure

&AtServer
Procedure OutputCashFlowItems()

	DataTable = GetFromTempStorage(Parameters.AddressInStorage);
	
	CompositionSchema = FormAttributeToValue("Object").GetTemplate("CashFlowItems");
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("ExternalDataTable", DataTable);
	
	CompositionSettings = CompositionSchema.DefaultSettings;
	
	CompositionSettings.OutputParameters.SetParameterValue("FilterOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
	CompositionSettings.OutputParameters.SetParameterValue("TitleOutput", DataCompositionTextOutputType.Output);
	
	DetailsData = New DataCompositionDetailsData;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(CompositionSchema, CompositionSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);	
	OutputProcessor.Output(CompositionProcessor);
	
	TranscriptionsAddress = PutToTempStorage(DetailsData, UUID);	

EndProcedure



////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS


// Function returns the decryption value by a passed identifier.
//
&AtServer
Function ReceiveDecryptionValue(Details)
	
	ValueDetails = Undefined;
	
	If ValueIsFilled(TranscriptionsAddress) Then
		
		DetailsData = GetFromTempStorage(TranscriptionsAddress);
		
		DecryptionFields = DetailsData.Items[Details].GetFields();
		ValueDetails = ?(DecryptionFields.Count() = 0, Undefined, DecryptionFields[0].Value);
		
	EndIf;
	
    Return ValueDetails;
	
EndFunction
