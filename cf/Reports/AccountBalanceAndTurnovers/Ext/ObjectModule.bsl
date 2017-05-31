Var SavedSetting Export;
Var Details Export;
Var GenerateOnOpen Export;
Var SettingsOfComposerOnOpenData Export;

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	ReportsModulesAtServer.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
EndProcedure

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	OutputIntoReportForm = NOT SettingsComposer.Settings.AdditionalProperties.Property("SpreadsheetOutput");
	ReportsModulesAtServer.CommonComposeResult(ThisObject,ResultDocument, DetailsData, StandardProcessing, OutputIntoReportForm);
	
EndProcedure

Function GenerateReport(Result = Undefined, DetailsData = Undefined, OutputIntoReportForm = True) Export

	Return TemplateReports.GenerateTemplateReport(ThisObject, Result, DetailsData, OutputIntoReportForm);
	
EndFunction

// In procedure we can complete composer before output to report
// Changes will be not saved
Procedure CompleteComposerBeforeOutput() Export
	OrderItemsFind = False;
	OrderItems = SettingsComposer.Settings.Order.Items;
	For Each OrderItem In OrderItems Do
		If OrderItem.Field = New DataCompositionField("Account.AdditionalView") Then
			 OrderItem.Use = True;
			 OrderItemsFind = True;
		EndIf;
	EndDo;
	If Not OrderItemsFind Then
		NewOrderItems = SettingsComposer.Settings.Order.Items.Add(Type("DataCompositionOrderItem"));
		NewOrderItems.Field = New DataCompositionField("Account.AdditionalView");
	EndIf;
	
	ParameterValue = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterValue = Undefined Then
		Return;
	EndIf;
	
	If ParameterValue.Value = '00010101' Then
		ParameterValue.Value = EndOfDay(CurrentDate());
		ParameterValue.Use = True;
	EndIf;
	
EndProcedure

// Procedure fills report parameters by catalog item saved settings
Procedure ApplySetting() Export
	
	If SavedSetting.Isempty() Then
		Return;
	EndIf;
	 
	SettingsStructure = SavedSetting.SettingsStorage.Get();
	TemplateReports.ApplyReportParametersStructure(ThisObject, SettingsStructure);
	
EndProcedure

Procedure FinalizeComposerAfterOutput() Export
EndProcedure

Procedure UpdateDataCompositionTemplateBeforeOutput(CompositionTemplate) Export

EndProcedure

Procedure ReportInitialization() Export
	
	TemplateReports.TemplateReportInitialization(ThisObject);
	TemplateReports.SetParameter(SettingsComposer,"Company",CommonAtServer.GetUserSettingsValue("Company",SessionParameters.CurrentUser));
	
EndProcedure

Function GenerateDocumentsTypesField() Export
	
	FieldText = "CASE
	            |";
	
	For Each MetadataDocument In Metadata.Documents Do
		If MetadataDocument.RegisterRecords.Contains(Metadata.AccountingRegisters.Bookkeeping) Then
			FieldText = FieldText + "		WHEN BookkeepingBalanceAndTurnovers.Recorder REFS Document." + MetadataDocument.Name + "
			                        |			THEN """ + MetadataDocument.Synonym + """
			                        |";
		EndIf;
	EndDo;
	
	FieldText = FieldText + "	END";
	
	Return FieldText;
	
EndFunction

Function GenerateDocumentBaseTypesField() Export
	
	FieldText = "CASE
	            |";
	
	For Each DocumentType In Metadata.Documents.BookkeepingOperation.Attributes.DocumentBase.Type.Types() Do	
		DocumentTypeRef = New(DocumentType);
		DocumentTypeRefMetadata = DocumentTypeRef.Metadata();
		FieldText = FieldText + "		WHEN BookkeepingBalanceAndTurnovers.Recorder.DocumentBase REFS Document." + DocumentTypeRefMetadata.Name + "
			                        |			THEN """ + DocumentTypeRefMetadata.Synonym + """
			                        |";
	EndDo;
	
	FieldText = FieldText + "	END";
	
	Return FieldText;
	
EndFunction

#If Client Then
	
// For Settings report (details etc)
Procedure Setup(Filter, MainReportSettingsComposer = Undefined) Export
	
	TemplateReports.SetupTemplateReport(ThisObject, Filter, MainReportSettingsComposer);
	
EndProcedure

Procedure SaveSettings() Export
	
	SettingsStructure = TemplateReports.GetTemplateReportParametersStructure(ThisObject);
	SettingsSaving.SaveObjectSetting(SavedSetting, SettingsStructure);
	
EndProcedure

Procedure OpenReportFromDocument(NewSettingsOfComposer) Export 
	
	SettingsOfComposerOnOpenData = NewSettingsOfComposer;
	GenerateOnOpen = True;
	
EndProcedure	


Details = New ValueList;

// Structure consists 
// ReportName - name of report in configuration
// Fields - Path to data, to fields, which should be drilldowned
//Item = New Structure;
//Item.Insert("ReportName", "TemplateOfTemplateReport");
//Item.Insert("Fields", "PurchaseGoodsExpected.Warehouse");
//Details.Add(Item, "Template of template report");

//Details.Add("ReportNameInConfiguration", "Report presentation for user");

PeriodSettings = New PeriodSettings;
GenerateOnOpen = False;
SettingsOfComposerOnOpenData = SettingsComposer.GetSettings();

#EndIf

DataCompositionSchema.DataSets.DataSet1.Query = StrReplace(DataCompositionSchema.DataSets.DataSet1.Query, """<Text of document base types>""", GenerateDocumentBaseTypesField());
DataCompositionSchema.DataSets.DataSet1.Query = StrReplace(DataCompositionSchema.DataSets.DataSet1.Query, """<Text of register recorders types>""", GenerateDocumentsTypesField());